## Next-Phase Execution Plan

This document captures the ordered work that remains after the initial Terraform + Ansible bootstrap. All tasks happen through GitOps (Argo CD) unless explicitly stated.

---

### 0. Baseline (Already in place / verify once)
- Argo CD Root App applies via `ansible/playbooks/bootstrap-bastion.yml` immediately after `terraform apply -var-file="custom-config-infrastructure.yaml"`.
- `${VAR}` placeholders in manifests resolve via the envsubst CMP (`gitops/argocd/config/argocd-cm-envsubst.yaml`).
- Namespace convention stands: `storage-system`, `monitoring`, `ingress-system`, `platform-config`, etc. Keep ALB/NLB annotations close to the manifest using them.

**Verification checklist**
1. Confirm Terraform outputs (`terraform/stacks/main/outputs.tf`) include every value referenced in `plugin.env`.
2. Ensure `ansible/templates/argocd-root-app.yaml.j2` aligns with `gitops/argo-apps/root/argocd-root-app.yaml` (same waves, plugin inputs).
3. Run `scripts/apply-iac.sh` once to ensure bootstrap completes cleanly; afterward rely on Argo CD syncs only.

---

### Standard GitOps procedure per wave
1. Author Helm/Kustomize values under `gitops/argo-apps/apps/<wave>/<component>/`.
2. Include the App (or ApplicationSet) in `gitops/argo-apps/root/argocd-root-app.yaml` with the desired `sync-wave`.
3. Reference namespaces, IAM role ARNs, and IDs via `${VAR}` so Argo can template them.
4. Merge to main; Argo CD reconciles automatically. Use Argo CD UI/CLI only to confirm health.

---

## Ordered Task List

| Wave | Scope                                 | Owner Namespace  | Prereqs                | Success Criteria |
|------|---------------------------------------|------------------|------------------------|--------------------------------------------------------------|
| 1    | metrics-server                        | `kube-system`    | Baseline done          | HPA-ready metrics (`kubectl get --raw /apis/metrics.k8s.io`) |
| 2    | aws-ebs-csi-driver + gp3 StorageClass | `storage-system` | Node IAM/role ready    | Default StorageClass = gp3, PVC bind succeeds                |
| 3    | aws-load-balancer-controller          | `ingress-system` | VPC,IAM ,subnets tag   | ALB & NLB ingress classes published, SA annotated            |
| 4    | Prefix delegation patch (aws-node)    | `kube-system`    | CNI DS EKS managed     | `ENABLE_PREFIX_DELEGATION=true` visible in DS env            |
| 5    | cluster-autoscaler                    | `kube-system`    | Metrics/EBS driver     | CA logs show node-group discovery, IRSA annotation           |
| 6    | envset-baseline(RBAC/policies...)     | `platform-config`| Prior waves synced     | Namespaces + quotas + NP + optional Argo self-manage present |

---

### Wave details & immediate next actions

#### Wave 1 – metrics-server (`gitops/argo-apps/apps/00-metrics-server/`)
- Values to lock:  
  ```
  args:
    - --kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP
    - --kubelet-use-node-status-port
    - --metric-resolution=15s
  ```
- Action: finalize chart values, ensure ServiceAccount uses IRSA if required, commit.
- Validation: `kubectl top nodes` works through bastion kubeconfig.

#### Wave 2 – storage system (`gitops/argo-apps/apps/00-storage/`)
- Components: aws-ebs-csi-driver (controller in `kube-system`), default `gp3` StorageClass, optional PVC under `apps/storage/tests/`.
- Required template values: `${EBS_CSI_ROLE_ARN}` on ServiceAccount.
- Actions:
  1. Author HelmRelease/values and apply `sync-wave: "2"`.
  2. Add StorageClass manifest with `metadata.annotations.storageclass.kubernetes.io/is-default-class: "true"`.
  3. Create PVC test manifest referencing `gp3`.
- Validation: `kubectl describe sc gp3` shows default; smoke PVC binds to an EBS volume.

#### Wave 3 – ingress system (`gitops/argo-apps/apps/00-ingress/` or keep under existing folder)
- App: aws-load-balancer-controller (`ingress-system` namespace).
- Values required:  
  ```
  clusterName: ${CLUSTER_NAME}
  region: ${AWS_REGION}
  vpcId: ${VPC_ID}
  serviceAccount.annotations."eks.amazonaws.com/role-arn": ${ALB_ROLE_ARN}
  ```
- Ensure standard annotations live with workloads (ALB + NLB bullets remain in manifests).
- Validation: controller Deployment healthy; `kubectl get ingressclass alb` shows proper parameters.

#### Wave 4 – CNI prefix delegation (`gitops/argo-apps/apps/00-cni-tuning/`)
- Implement Kustomize patch to the `aws-node` DaemonSet:  
  ```
  ENABLE_PREFIX_DELEGATION=true
  WARM_PREFIX_TARGET=1
  ```
- Action: create overlay patch referencing upstream manifest; confirm Argo applies in wave 4.
- Validation: `kubectl describe ds aws-node -n kube-system` shows env vars.

#### Wave 5 – cluster-autoscaler (`gitops/argo-apps/apps/00-autoscaler/`)
- Values:  
  ```
  autoDiscovery.clusterName: ${CLUSTER_NAME}
  awsRegion: ${AWS_REGION}
  extraArgs.balance-similar-node-groups: "true"
  extraArgs.expander: "least-waste"
  serviceAccount.annotations."eks.amazonaws.com/role-arn": ${CA_ROLE_ARN}
  ```
- Actions: ensure nodegroup tags support auto-discovery, add PodDisruptionBudget, set `priorityClassName` if needed.
- Validation: CA logs show `ClusterAutoscaler 1.29+` starting, `kubectl logs deployment/cluster-autoscaler -n kube-system`.

#### Wave 6 – envset-baseline (`gitops/argo-apps/apps/00-argocd/` or `envset-baseline/`)
- Purpose: centralize namespaces (storage, ingress, monitoring), RBAC, quotas, LimitRanges, default NetworkPolicies/IngressClasses, optional Argo self-management.
- Actions: create aggregated Kustomize or Helm chart; ensure namespaces exist before dependent apps by keeping this at the same or earlier wave for those namespaces (wave 6 is fine if all earlier namespaces are created per chart, otherwise split out namespace creation to wave 0).
- Validation: `kubectl get ns` shows platform namespaces, RBAC objects exist, optional Argo Application for self-management synced.

---

### Supporting automation recap

```
terraform apply -var-file="custom-config-infrastructure.yaml" \
  && ansible-playbook -i ansible/inventory/aws.ini ansible/playbooks/bootstrap-bastion.yml
```

Ansible responsibilities (run once per environment):
- Consume Terraform outputs (`bastion_public_ip`, `ssh_private_key_path`, `kubeconfig_path`).
- Install `helm` + `kubectl` on bastion, copy kubeconfig.
- Install Argo CD, register envsubst CMP, apply Root App. After that, **only Argo CD** mutates the cluster.

---

### Repository map (for quick navigation)

```
devops-autopilot/
├── custom-config-infrastructure.yaml      # single source of env vars for TF + echoed to Ansible
├── scripts/                               # init/plan/apply/destroy helpers (terraform chdir pattern)
├── terraform/stacks/main/                 # stateful IaC entrypoint (outputs feed Ansible)
├── ansible/                               # bootstrap-only automation (bastion, Argo CD install)
└── gitops/                                # Argo CD apps, values, and CMP config
    ├── argocd/config/argocd-cm-envsubst.yaml
    ├── argo-apps/root/argocd-root-app.yaml
    └── argo-apps/apps/<wave>-*/            # application manifests ordered by sync wave
```

Keep this file (`project-next-phase.md`) as the canonical runbook for upcoming work; update statuses as each wave ships.
