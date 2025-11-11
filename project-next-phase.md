## Next Phase Execution Plan (Post-Root-App)

**Current state:** Terraform/Ansible finished, bastion prepared, Argo CD Root Application synced. No platform apps, Vault, ESO, or Crossplane are running yet.

The plan below is a fully ordered runbook that takes us from this point to a production-grade GitOps environment where Crossplane manages Zitadel, GitLab, Vault, DNS, and database dependencies. Follow each phase sequentially; do not skip ahead because later work assumes earlier prerequisites are healthy.

---

### Phase 0 – Stabilize the GitOps control plane
1. **Lock references**
   - Snapshot Terraform outputs (especially VPC, subnet IDs, IAM ARNs) to confirm all `${VAR}` placeholders used by GitOps resolve correctly.
   - Document bastion access + `kubectl` commands for verification.
2. **Validate Root App**
   - In Argo CD UI/CLI, confirm the root Application is `Healthy/Synced`. Fix any path or plugin issues (envsubst CMP) before onboarding new apps.
3. **Establish verification checklist**
   - Define the minimum smoke tests for each upcoming wave (e.g., `kubectl get ns`, `kubectl top nodes`, etc.) so you know when a phase completes.

_Exit criteria:_ Argo CD reconciles reliably; no manual drift remains on the cluster.

---

### Phase 1 – Extend Terraform IRSA for Crossplane
Crossplane must assume AWS roles via IRSA before any provider work begins.

1. **Design Crossplane roles**
   - `crossplane_core_role`: Route53 record management, Elastic Load Balancing (read), EC2 `Describe*`, tagging, limited `iam:PassRole` for Crossplane-managed identities, CloudWatch Logs read access.
   - `crossplane_data_role`: RDS/Aurora + DocumentDB lifecycle, Secrets Manager read/write, KMS describe/use (scoped to the project), S3 bucket/object management for `${project_name}-crossplane-*`.
   - Optional sub-roles (if desired): dedicated DNS-only role or DB-only role for fine-grained ProviderConfigs.
2. **Terraform implementation**
   - Update `terraform/modules/irsa` to create these IAM roles, trust the EKS OIDC provider (`crossplane-system` service accounts), and output their ARNs.
   - Extend `terraform/stacks/main/outputs.tf` and `scripts/load-config.sh` so the ARNs become `${TF_VAR_crossplane_*}` values for GitOps.
3. **Apply & document**
   - Run `scripts/apply-iac.sh` to create roles.
   - Record the ARNs in this plan for later ProviderConfig references; confirm no AWS secrets exist anywhere else.

- **`crossplane_core_role`**: Permissions for Route53, ELB, EC2 describe, tagging, CloudWatch Logs reads. Used by provider-aws for DNS/ingress tasks.
- **`crossplane_data_role`**: Permissions for RDS/DocDB lifecycle, Secrets Manager read/write (for DB creds if Crossplane needs to rotate), KMS encryption context tied to project, and S3 (for Terraform provider state or app buckets). Enforce resource-level constraints where possible (ARN prefixes).
No static AWS keys are stored anywhere—every Crossplane ProviderConfig relies on IRSA.

_Exit criteria:_ Crossplane IAM roles exist and are exported via Terraform.

---

### Phase 2 – Foundational platform services (pre-Crossplane)
These apps bootstrap namespaces, storage, ingress, security, and secrets so Crossplane has everything it needs later.

1. **Namespaces & baseline policies (`gitops/apps/platform-baseline`)**
   - Create namespaces: `platform-system`, `ingress-system`, `storage-system`, `vault`, `gitlab`, `zitadel`, `crossplane-system`, `platform-secrets`.
   - Apply quotas, LimitRanges, default NetworkPolicies, PriorityClasses.
   - _Validation_: `kubectl get ns` shows the full list; Argo app `Healthy`.

2. **Storage layer (`gitops/apps/storage`)**
   - Deploy AWS EBS CSI Driver; annotate ServiceAccount with `${EBS_CSI_ROLE_ARN}`.
   - Create gp3 StorageClass (default) + PVC smoke test.
   - _Validation_: `kubectl describe sc gp3` shows `is-default-class=true`; PVC binds.

3. **Ingress & networking (`gitops/apps/ingress`)**
   - Install AWS Load Balancer Controller with `${CLUSTER_NAME}`, `${AWS_REGION}`, `${VPC_ID}`, `${ALB_ROLE_ARN}`.
   - Ensure VPC subnets carry required tags (`kubernetes.io/role/*`).
   - _Validation_: Controller Deployment healthy; `kubectl get ingressclass alb`.

4. **CNI tuning (`gitops/apps/cni-tuning`)**
   - Patch `aws-node` DaemonSet to set `ENABLE_PREFIX_DELEGATION=true`, `WARM_PREFIX_TARGET=1`.
   - _Validation_: `kubectl describe ds aws-node -n kube-system` lists the new env vars.

5. **Cluster Autoscaler (`gitops/apps/autoscaler`)**
   - Deploy CA with auto-discovery, `--balance-similar-node-groups`, SA annotated with `${CA_ROLE_ARN}`.
   - _Validation_: `kubectl logs deployment/cluster-autoscaler -n kube-system` shows node group discovery.

6. **Security & policy controls**
   - Install Kyverno + policy bundles (`gitops/apps/kyverno`), metrics-server (`gitops/apps/metrics`), reflector/reloader if desired.
   - _Validation_: `kubectl top nodes` works; Kyverno enforces baseline policies.

7. **Vault deployment (`gitops/apps/vault`)**
   - Deploy Vault (Raft) and expose via internal Service/Ingress; wire TLS certs.
   - _Validation_: Vault pods healthy; `vault status` via bastion port-forward succeeds.

8. **External Secrets Operator (`gitops/apps/external-secrets`)**
   - Install ESO targeting Vault; configure placeholder auth (no AWS creds).
   - _Validation_: ESO pods running; logs show successful Vault connection after Vault is up.

_Exit criteria:_ All foundational apps (except monitoring/Velero) show `Healthy`; Vault and ESO are ready for later integration.

---

### Phase 3 – Install Crossplane & supporting packages
Only start this phase once Phases 1 and 2 are complete.

1. **Crossplane Helm release**
   - Add `gitops/apps/crossplane/core` Application. Pin version (e.g., `1.15.x`), set `args: ["--enable-composition-functions"]`.
2. **Provider packages**
   - Under `gitops/apps/crossplane/packages`, create `Provider` manifests with exact versions:
     - `crossplane/provider-aws`
     - `crossplane/provider-kubernetes`
     - `crossplane/provider-helm`
     - `crossplane-contrib/provider-terraform`
     - `crossplane-contrib/provider-gitlab`
     - `crossplane-contrib/provider-vault`
   - Also add `Function` manifests: `function-go-templating`, `function-patch-and-transform`, `function-auto-ready`.
3. **ProviderConfigs (IRSA-based)**
   - Create `aws-providerconfig` referencing the new `crossplane_core_role` ARN (via `spec.credentials.source: IRSA`).
   - Create specialized `ProviderConfig` objects for RDS/DocDB if they need different roles (e.g., `crossplane_data_role`).
   - For Kubernetes & Helm providers, use in-cluster service accounts with fine-grained RBAC.
   - Terraform provider config should reference a Kubernetes Secret containing `.terraformrc` (populated by ESO later) but **no AWS keys**—Terraform provider assumes IRSA as well.
4. **ESO integration for non-AWS secrets**
   - Configure ESO to produce secrets for Zitadel admin APIs, GitLab PATs, Vault tokens, etc., leaving AWS access solely to IRSA.
5. **Validation**
   - `kubectl get providers.pkg.crossplane.io` shows all packages `Healthy`.
   - ProviderConfigs report `READY`. Crossplane Pod logs show reconciliation of built-in resources.

_Exit criteria:_ Crossplane core + providers + functions installed; no pending packages in Argo CD.

---

### Phase 4 – Build and publish Crossplane Configuration Package
Create the reusable APIs (XRs) that higher-level apps will consume.

1. **Repository structure**
   - `gitops/apps/crossplane/config/`
     - `crds/` – `CompositeResourceDefinition` files (XRDS).
     - `compositions/` – each composition referencing providers/functions.
     - `crossplane.yaml` – configuration metadata for packaging.
2. **XRs to define**
   - **Identity**: `CompositeZitadelBootstrap`.
   - **GitOps**: `CompositeGitLabProjectSet`.
   - **Secrets & Auth**: `CompositeVaultBootstrap`.
   - **DNS**: `CompositeRoute53Record`.
   - **Databases**: `CompositeRDSCluster`, `CompositeDocDBCluster`.
3. **Function wiring**
   - Use `function-go-templating` to build names, FQDNs, and secret names.
   - `function-patch-and-transform` or `function-kcl` to default regions, enforce enums (engine versions), derive Route53 targets from Service statuses.
   - `function-auto-ready` to hold compositions until dependent resources (e.g., ALB) surface hostnames.
4. **Secret conventions**
   - All compositions write outputs to predictable names: `${claimName}-db`, `${claimName}-oidc`, `${claimName}-dns`.
5. **Packaging pipeline**
   - Optional: add `Makefile` target or GitHub Action using `up xpkg build` to publish to OCI registry (internal).
6. **Smoke tests**
   - In a sandbox namespace, create sample claims (e.g., `ZitadelBootstrap` with stub values) to ensure functions work and resources reconcile (you can disable actual Terraform/GitLab API calls via mock ProviderConfigs if needed).

_Exit criteria:_ Configuration package is applied via GitOps, XRDs + Compositions show `Healthy`, and sample claims reconcile.

---

### Phase 4b – Package compositions + automate version wiring
Keep the new Crossplane compositions in lockstep with GitOps by creating a dedicated packaging workspace and CI pipeline.

1. **Repository layout**
   - Add a root-level directory (e.g., `crossplane-packages/`) with `compositions/`, `functions/`, `configuration/`, and `pkg.yaml`.
   - Include a manifest (`images.yaml` or similar) describing container images referenced by Vault/Zitadel bootstrap jobs so CI can bump them.
2. **Build tooling**
   - Provide a `Makefile` or script to run `up xpkg build` (or `kubectl crossplane build configuration`) and publish to an OCI registry (AWS ECR Public, GHCR, etc.).
   - Store build metadata (version, digest, image tags) under `crossplane-packages/dist/` for later steps.
3. **GitHub Action runner**
   - New workflow runs on every push/PR touching `crossplane-packages/`:
     1. Execute the build script and push the OCI artifact.
     2. Parse the latest image tags/digests from the build output.
     3. Patch `custom-config-infrastructure.yaml` (or a derived values file) with the new package version + image references so Crossplane claims consume the latest bits.
     4. Commit the updates back to the PR (or open a release branch) with a clear changelog.
4. **Promotion**
   - Tag packages with `dev`, `stg`, `prod` channels and reference the appropriate tag from the GitOps manifests / Argo CD Applications.
   - Document how to roll back to a previous package and how automation prevents manual edits.

_Exit criteria:_ Packaging directory exists, the GitHub Action produces/publishes OCI configurations, and config values are updated automatically after each successful build.

---

### Phase 5 – Onboard applications via GitOps + Crossplane
Now wire actual platform services using the compositions.

1. **Vault finalization**
   - Apply `VaultBootstrap` claim to enable JWT auth, create policies, bind ESO + Crossplane service accounts. Ensure secrets for provider configs are populated automatically.
2. **Zitadel**
   - Deploy runtime Helm chart (`gitops/apps/zitadel`) for control plane.
   - Submit `ZitadelBootstrap` claim to create org/project/clients. Outputs land in `platform-secrets`.
   - Use `XRoute53Record` claims to create `zitadel.<domain>` once Service exposes hostname.
3. **GitLab**
   - Provision Aurora DB via `RDSCluster` claim first.
   - Deploy GitLab chart referencing the DB secret.
   - Apply `GitLabProjectSet` claim to create initial groups/projects and emit deploy tokens.
   - Publish DNS via `XRoute53Record`.
4. **Harbor, Vault UI, External apps**
   - For each, create DB claims (if needed), DNS claims, and ensure Helm values reference Crossplane-generated secrets.
5. **Monitoring, Backup integration**
   - Wire Crossplane-managed resources into Prometheus dashboards (e.g., RDS metrics) and Velero backups (CRDs + secrets). Update GitOps manifests accordingly.

_Exit criteria:_ Every app folder under `gitops/apps/` is either a Helm/Kustomize chart consuming Crossplane outputs or a set of Crossplane claims. Argo CD shows full stack green.

---

### Phase 6 – Operational hardening & final apps
1. **Observability (final application)**
   - Deploy/finish Prometheus & Grafana (`gitops/apps/monitoring`) now that all workloads exist.
   - Add rules/dashboards for Crossplane, provider pods, and managed resources; surface claim readiness metrics.
2. **Backups (final application)**
   - Complete Velero configuration (`gitops/apps/velero`), create backup storage locations, and schedule backups for namespaces containing Crossplane state (`crossplane-system`, `platform-secrets`, app namespaces).
3. **Security**
   - Kyverno rules to prevent manual edits to Crossplane-managed resources (label-based).
   - Audit IAM roles/policies generated in Phase 2; ensure least privilege.
4. **Runbooks**
   - Document how to request new claims (inputs/outputs), rotate secrets, and recover from failure scenarios.

_Exit criteria:_ Monitoring dashboards + backup schedules in place; documentation stored in repo (e.g., `docs/crossplane/`).

---
