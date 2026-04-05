# 🚀 DevOps Autopilot for Production EKS

DevOps Autopilot is a production-grade reference implementation that turns a clean AWS account into a fully managed EKS platform in one push. Terraform builds the network, security boundaries, cluster, and IRSA roles; Ansible equips the bastion and deploys Argo CD with GitOps plugins; Argo CD’s app-of-apps layout keeps every platform workload—from cert-manager to Vault, Harbor, GitLab, Zitadel, and Crossplane—continuously reconciled. One configuration file powers every environment so recruiters, operators, and auditors immediately see a cohesive, self-healing story.

**Why it stands out**
- Production-ready defaults: private networking, KMS-encrypted secrets, IRSA for every controller, hardened bastion with zero manual steps.
- GitOps-first: Argo CD root application fans out into storage, ingress, security, secrets, observability, and identity stacks.
- Ready for platform engineering: Crossplane, Vault, Zitadel, and GitLab land side-by-side, with future compositions packaged and shipped automatically.
- Single-flight automation: the same scripts run locally or in CI to init, plan, apply, and bootstrap GitOps without snowflake steps.

---

## Platform Layers

- **Source-of-truth config** – `custom-config-infrastructure.yaml` plus `scripts/load-config.sh` export every value as `TF_VAR_*` / Ansible env vars. Update the file once to change CIDRs, cluster versions, IRSA toggles, or Argo CD behavior everywhere.
- **Terraform stack** – `terraform/stacks/main` orchestrates reusable modules (`terraform/modules/*`) to provision VPC + NAT, IAM/KMS, EKS, managed node group + bastion, and IRSA roles for AWS Load Balancer Controller, EBS CSI, Cluster Autoscaler, and Crossplane core/data controllers. Local `artifacts/` files provide kubeconfig, inventories, and Arns for the next stages.
- **Ansible bootstrap** – `ansible/playbooks/bootstrap-iac.yml` (roles: `bastion_setup`, `argocd`, `gitops_root_app`) installs kubectl/helm, copies kubeconfig/SSH material, deploys Argo CD from Terraform-rendered artifacts, and applies the Terraform-rendered root Application.
- **GitOps tree** – `gitops/argo-apps` hosts the AppProject and every Argo CD `Application`. The root overlay syncs cert-manager, ingress, storage, Vault, Harbor, GitLab, Crossplane, Zitadel, Velero, monitoring, Kyverno, and supporting controllers in controlled sync-wave order. Workloads under `gitops/apps/<name>` can be Helm, Kustomize, or Crossplane claims.

---

## Single Config Contract (No Drift)

- One file defines project metadata, backend storage, networking, IAM/IRSA toggles, cluster shape, node group preferences, bastion policy, and Ansible knobs (kubectl version, plugin settings, Argo CD namespace, etc.).
- `scripts/load-config.sh` validates dependencies (`yq`, `jq`), exports Terraform variables, and sets Ansible env vars so every shell (local or GitHub Action) behaves identically.
- Terraform, Ansible, and GitOps consume the same values through rendered artifacts and plugin env injection—no duplicated configuration blocks or hard-coded secrets.

---

## Automation Flow

1. **Backend init** – `scripts/init-iac.sh` parses the config and runs `terraform init -reconfigure` with the right S3 bucket, key, region, and DynamoDB table.
2. **Plan & apply** – `scripts/plan-iac.sh` and `scripts/apply-iac.sh` format/validate the stack, then create the full AWS footprint and emit kubeconfig/inventory/vars artifacts.
3. **Bootstrap via Ansible** – `scripts/apply-ansible.sh` (orchestration-friendly) SSHes into the bastion, installs tooling, copies Terraform-rendered Argo CD artifacts, deploys Argo CD, and applies the GitOps root Application manifest.
4. **GitOps reconciliation** – Argo CD continuously syncs the app-of-apps tree, including Crossplane providers, IRSA-integrated controllers, Vault/ESO, Harbor caches, Zitadel auth, GitLab, monitoring, and Velero.

The same flow runs locally or inside a single GitHub Action job—no bespoke CI glue.

---

## Terraform Stack Highlights

- **Networking & security** – Dual-stack VPC, Kubernetes-tagged subnets, NAT gateways, security groups, and enforced CIDR detection for API and bastion access.
- **Identity & encryption** – Dedicated IAM roles for control plane/nodes, customer-managed KMS key wired into secrets encryption, and fine-grained IRSA roles (ALB, EBS CSI, Cluster Autoscaler, Crossplane core/data with KMS + S3 + Secrets Manager privileges).
- **Compute & access** – Managed node group with extra labels for autoscaler, optional SSH enforcement only via bastion, automatic EC2 key generation, and a managed bastion host that inherits your admin CIDRs.
- **Artifacts-on-disk** – Terraform produces inventories, Ansible vars, kubeconfigs, Argo CD Helm values, root app manifests, and IRSA metadata so later scripts and human operators share the same facts.

---

## Bastion + Argo CD Bootstrap

1. **`bastion_setup` role** – Creates secure `.kube` / `.ssh`, installs kubectl/helm idempotently, copies kubeconfig and SSH keys, and verifies API connectivity with retries.
2. **`argocd` role** – Adds the Helm repo, copies the Terraform-rendered values file to the bastion, and installs/updates Argo CD with the lovely CMP sidecar.
3. **`gitops_root_app` role** – Copies the Terraform-rendered root Application manifest to the bastion and applies it directly.

---

## GitOps App-of-Apps Layout

```
gitops/argo-apps/
├── base/                 # AppProject + per-app Application manifests
└── overlays/default/root # Kustomize overlay enumerating every Application
```

- Sync waves ensure storage-stack → cert-manager → ingress → Vault/ESO → Harbor/GitLab → Crossplane → monitoring/velero.
- The lovely CMP sidecar allows each Application to read values such as `EBS_CSI_ROLE_ARN`, `PUBLIC_SUBNET_IDS`, `AWS_REGION`, or `ARGOCD_NAMESPACE` that Terraform rendered into the root app manifest.
- Workloads under `gitops/apps/<name>` combine Helm charts, plain manifests, or forthcoming Crossplane claims (e.g., `apps/crossplane`, `apps/zitadel`, `apps/gitlab`).

---

## Crossplane Composition Packaging (Upcoming)

A new root-level directory will host reusable Crossplane compositions (claims + compositions + functions). A dedicated GitHub Action runner will:

1. Generate and package the compositions into OCI artifacts (via `up xpkg build` or similar) whenever manifests change.
2. Detect the latest container image tags referenced in those compositions
3. Update `custom-config-infrastructure.yaml` automatically with the published artifact versions so Crossplane can deploy databases, DNS records, and platform services using fresh images without manual edits.
4. Publish the package and open a pull request summarizing the new versions consumed by GitOps.

This packaging pipeline slots in immediately after Phase 4 of `project-next-phase.md`, ensuring compositions stay versioned, reproducible, and ready for tenant onboarding.

---

## Project Next Phase & Roadmap

See `project-next-phase.md` for the full runbook.

---

## Repository Layout

```
ansible/                 # Playbooks + roles (bastion_setup, argocd, gitops_root_app)
gitops/                  # Argo CD Applications + workload directories
scripts/                 # init/plan/apply/destroy/apply-ansible, load-config helpers
terraform/               # modules + root stack with templates for artifacts
project-next-phase.md    # Ordered roadmap (phases 0–6 + packaging phase)
custom-config-infrastructure.yaml
.githooks/               # Pre-commit + commit-msg hooks (enable via `git config core.hooksPath .githooks`)
```

---

## Getting Started Locally

1. **Prerequisites** – Terraform ≥ 1.6, Ansible ≥ 2.16, `yq`, `jq`, `kustomize`, AWS credentials with permissions for VPC/EKS/IRSA/KMS.
2. **Configure** – Edit `custom-config-infrastructure.yaml` for your project name, region, CIDRs, IRSA toggles, node group sizing, and Argo CD preferences.
3. **Bootstrap** – Run:
   ```bash
   ./scripts/init-iac.sh
   ./scripts/plan-iac.sh
   ./scripts/apply-iac.sh
   ./scripts/apply-ansible.sh
   ```
4. **Inspect** – Check `terraform/stacks/main/artifacts/`, run `terraform output`, and preview `kustomize build gitops/argo-apps/overlays/default/root`.
5. **Iterate safely** – Update the config file, re-run apply scripts, and let Argo CD converge. Tear everything down with `scripts/destroy-iac.sh` when done.

export TF_VAR_external_secrets_bootstrap_secret_values='{"username":"admin","password":"super-secret-value"}'
