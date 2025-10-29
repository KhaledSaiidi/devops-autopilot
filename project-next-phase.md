--------------------------------------------------------------------------------------------------
Output→Consumer Map (Authoritative wiring from Terraform)
--------------------------------------------------------------------------------------------------
Goal: Make it crystal-clear where each Terraform output is consumed later (Ansible once, then GitOps only).

VPC Outputs
  • vpc_id .................. Used by: Argo CD (GitOps) → aws-load-balancer-controller Helm values (vpcId)
  • public_subnet_ids ....... Used by: AWS LBs (via tags already set by Terraform). No direct injection needed post-provision.
  • private_subnet_ids ...... Used by: AWS LBs (via tags already set by Terraform). No direct injection needed post-provision.

IAM Outputs
  • eks_cluster_role_arn .... (FYI) Control-plane role. Not injected later.
  • eks_node_role_arn ....... (FYI) Node EC2 role. Not injected later.
  • ebs_csi_role_arn ........ Used by: GitOps → EBS-CSI chart SA annotation: eks.amazonaws.com/role-arn
  • cluster_autoscaler_role_arn
                            .. Used by: GitOps → Cluster Autoscaler chart SA annotation: eks.amazonaws.com/role-arn

Nodegroup / Bastion Outputs
  • bastion_public_ip ....... Used by: Ansible bootstrap SSH target (one-time).
  • ssh_private_key_path .... Used by: Ansible bootstrap SSH auth (one-time).

EKS Outputs
  • eks_cluster_name ........ Used by: Ansible (kubectl context), GitOps (ALB ctrl & CA values).
  • eks_cluster_endpoint .... Used by: (FYI) Kubeconfig already generated; not injected.
  • kubeconfig_path ......... Used by: Ansible bootstrap to copy kubeconfig to bastion.
  • oidc_issuer_url ......... (FYI) IRSA already created in Terraform; not injected.

How GitOps gets the values:
  • Option A (preferred): “envset” app creates a ConfigMap/Secret with keys (VPC_ID, CLUSTER_NAME, AWS_REGION, ALB_ROLE_ARN, EBS_CSI_ROLE_ARN, CA_ROLE_ARN). 
    All Helm/Kustomize apps reference these via ${...} or .Values populated by Argo CD value files.
  • Option B: External Secrets Operator pulls the same keys from AWS Secrets Manager (pre-seeded by Terraform). (You can switch later without touching apps.)

--------------------------------------------------------------------------------------------------
Done Phase — Provisioning (Terraform only, one command)
--------------------------------------------------------------------------------------------------
Goal: Build VPC, subnets (with ELB tags), IGW/NAT, EKS control plane (v1.33) with KMS, managed nodegroup, OIDC provider, IRSA roles.

Task 1 -> done by Terraform
Command:
  terraform apply -var-file="custom-config-infrastructure.yaml"

Key invariants created by Terraform:
  • Subnet Tags for LB discovery:
      public:  kubernetes.io/role/elb=1
      private: kubernetes.io/role/internal-elb=1
      all:     kubernetes.io/cluster/${eks_cluster_name}=shared
  • IRSA roles present:
      - ALB controller  (ALB_ROLE_ARN)
      - EBS-CSI         (EBS_CSI_ROLE_ARN)
      - Cluster Autoscaler (CA_ROLE_ARN)
  • Nodegroup tagged for CA:
      - k8s.io/cluster-autoscaler/${eks_cluster_name}=owned
      - k8s.io/cluster-autoscaler/enabled=true
  • Kubeconfig file written locally: ${kubeconfig_path}
  • Bastion reachable: ${bastion_public_ip}, SSH key at ${ssh_private_key_path}

--------------------------------------------------------------------------------------------------
Next Phase — One-Time Bootstrap (Ansible only, then NEVER come back)
--------------------------------------------------------------------------------------------------
Goal: Use the bastion as the single control point to install Argo CD and register the envsubst CMP.  
After this, **GitOps (Argo CD) fully owns the platform lifecycle**.

---

### Task 1 → done by Ansible
**Purpose: Prepare the bastion host for cluster operations**
  • SSH into bastion using `bastion_public_ip` and `ssh_private_key_path`.  
  • Install `kubectl` and `helm` binaries.  
  • Copy `${kubeconfig_path}` to `/home/ec2-user/.kube/config`.  
  • Sanity check cluster reachability:
    ```bash
    kubectl get nodes
    ```

---

### Task 2 → done by Ansible
**Install Argo CD (baseline deployment)**
  Namespace: `argocd`  
  Command (executed from bastion):
  ```bash
  helm repo add argo https://argoproj.github.io/argo-helm && helm repo update
  helm upgrade --install argocd argo/argo-cd \
    --namespace argocd --create-namespace \
    --set server.service.type=LoadBalancer \
    --set server.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
    --set configs.params.server\.insecure="true"
  ```

---

### Task 3 → done by Ansible
**Register the Config Management Plugin (CMP) in Argo CD**
  Purpose: Add a plugin named `envsubstappofapp` to render manifests using `envsubst` and substitute `${...}` variables at sync time.  

  Artifact: ConfigMap patch stored at  
  `gitops/argocd/config/argocd-cm-envsubst.yaml`  

  Command (executed by Ansible from bastion):
  ```bash
  kubectl -n argocd apply -f gitops/argocd/config/argocd-cm-envsubst.yaml
  kubectl -n argocd rollout restart deploy argocd-repo-server
  ```

  *This ensures the repo-server reloads and the plugin is available before syncing the Root App.*

---

### Task 4 → done by Ansible
**Deploy the Root Application using envsubst CMP and Terraform outputs**

  Purpose: Create the Root App (App-of-Apps) that uses  
  `plugin.name: envsubstappofapp` and injects Terraform outputs as environment variables (`plugin.env`) for dynamic substitution.

  Inputs (Terraform → Ansible mapping):
  ```
  vpc_id                     → VPC_ID
  public_subnet_ids          → PUBLIC_SUBNET_IDS
  private_subnet_ids         → PRIVATE_SUBNET_IDS
  eks_cluster_name           → CLUSTER_NAME
  eks_cluster_endpoint       → CLUSTER_ENDPOINT
  oidc_issuer_url            → OIDC_ISSUER_URL
  ebs_csi_role_arn           → EBS_CSI_ROLE_ARN
  eks_cluster_role_arn       → EKS_CLUSTER_ROLE_ARN
  eks_node_role_arn          → EKS_NODE_ROLE_ARN
  cluster_autoscaler_role_arn→ CA_ROLE_ARN
  bastion_public_ip          → BASTION_PUBLIC_IP (optional)
  kubeconfig_path            → KUBECONFIG_PATH (used only by Ansible)
  ```

  Artifact: `gitops/argo-apps/root/argocd-root-app.yaml`
  ```
  spec.sources[].plugin.name: envsubstappofapp
  spec.sources[].plugin.env: [ { name: "VPC_ID", value: "<from TF output>" }, ... ]
  ```

  Command (executed by Ansible on bastion):
  ```bash
  kubectl -n argocd apply -f gitops/argo-apps/root/argocd-root-app.yaml
  ```

---

**NOTE — Automation trigger**
  • Terraform can automatically invoke this Ansible phase via `null_resource + local-exec` after apply.  
  • Or use a wrapper pipeline:
    ```bash
    terraform apply -var-file="custom-config-infrastructure.yaml" \
      && ansible-playbook -i ansible/inventory/aws.ini ansible/playbooks/bootstrap-bastion.yml
    ```

**AFTER THIS POINT:**  
No more Ansible. Everything is declarative and continuously reconciled by GitOps.

--------------------------------------------------------------------------------------------------
Phase — Platform Baseline via GitOps (Argo CD only, strict ordering)
--------------------------------------------------------------------------------------------------
Goal: All core add-ons are installed by Argo CD.  
Variables are resolved dynamically via `${...}` using the envsubst plugin.

---

### Task 0 (first) → done by GitOps (Argo CD sync)
**Purpose:**  
As Argo CD syncs the Root App, `${VAR}` placeholders in manifests are automatically replaced with values passed from the Root App’s `plugin.env`.

Notes:
  • Keep each component in its own namespace (e.g., `storage-system`, `monitoring`, `ingress-system`).  
  • ALB/NLB annotations remain inside respective manifests; `${...}` will be resolved automatically.

---

### Task 1 → done by GitOps (Wave 1)
**App:** metrics-server (Namespace: `kube-system`)  
**Why:** Provides resource metrics for HPA/VPA/CA readiness.  
**Chart Values (in Git):**
  ```
  args:
    - --kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP
    - --kubelet-use-node-status-port
    - --metric-resolution=15s
  ```

---

### Task 2 → done by GitOps (Wave 2)
**App:** aws-ebs-csi-driver (Controller: `kube-system`; grouped under `storage-system`)  
**ServiceAccount Annotation:**
  ```
  eks.amazonaws.com/role-arn: ${EBS_CSI_ROLE_ARN}
  ```
**Also in this wave:**
  - Default `StorageClass` (`gp3`)  
  - Optional smoke-test PVC under `apps/storage/tests/`.

---

### Task 3 → done by GitOps (Wave 3)
**App:** aws-load-balancer-controller (Namespace: `ingress-system`)  
**ServiceAccount Annotation:**
  ```
  eks.amazonaws.com/role-arn: ${ALB_ROLE_ARN}
  ```
**Values:**
  ```
  clusterName: ${CLUSTER_NAME}
  region: ${AWS_REGION}
  vpcId: ${VPC_ID}
  ```
**Standard ALB Annotations:**
  - `kubernetes.io/ingress.class: alb`
  - `alb.ingress.kubernetes.io/scheme: internet-facing | internal`
  - `alb.ingress.kubernetes.io/target-type: ip`

**Standard NLB Annotations:**
  - `service.beta.kubernetes.io/aws-load-balancer-type: "nlb"`
  - `service.beta.kubernetes.io/aws-load-balancer-scheme: "internal" | "internet-facing"`
  - `service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"`

---

### Task 4 → done by GitOps (Wave 4)
**App:** prefix-delegation (Namespace: `kube-system`)  
**Implementation:** Kustomize patch for `aws-node` DaemonSet:
  ```
  ENABLE_PREFIX_DELEGATION=true
  WARM_PREFIX_TARGET=1
  ```

---

### Task 5 → done by GitOps (Wave 5)
**App:** cluster-autoscaler (Namespace: `kube-system`)  
**ServiceAccount Annotation:**
  ```
  eks.amazonaws.com/role-arn: ${CA_ROLE_ARN}
  ```
**Values:**
  ```
  autoDiscovery.clusterName: ${CLUSTER_NAME}
  awsRegion: ${AWS_REGION}
  extraArgs.balance-similar-node-groups: "true"
  extraArgs.expander: "least-waste"
  ```

---

### Task 6 → done by GitOps (Wave 6)
**App:** envset-baseline (Namespace: `platform-config`)  
**Purpose:** Define global namespaces, policies, and RBAC baselines:
  - Domain namespaces (`storage-system`, `ingress-system`, `monitoring`, etc.)  
  - RBAC, Quotas, LimitRanges  
  - Default `NetworkPolicies` and `IngressClasses`  
  - Optionally include Argo CD self-management app.

--------------------------------------------------------------------------------------------------
How the Ansible Bootstrap Starts Automatically After Terraform
--------------------------------------------------------------------------------------------------
Pipeline or local wrapper:
```bash
terraform apply -var-file="custom-config-infrastructure.yaml" \
  && ansible-playbook -i ansible/inventory/aws.ini ansible/playbooks/bootstrap-bastion.yml
```

**Expectations from the Ansible play:**
  • Reads Terraform outputs (`bastion_public_ip`, `ssh_private_key_path`, `kubeconfig_path`).  
  • Installs `helm` and `kubectl` on bastion.  
  • Copies kubeconfig.  
  • Installs Argo CD.  
  • Registers `envsubst` CMP and applies the Root App manifest (the only two `kubectl apply` calls).  
  • Exits. From this point, **Argo CD** automatically handles all synchronization.


devops-autopilot/
├── README.md
├── LICENSE
├── custom-config-infrastructure.yaml              # your single source of env vars for TF (and echoed to Ansible)
├── scripts/                                       # thin wrappers; pipeline can call these
│   ├── init-iac.sh                                # terraform -chdir=terraform/stacks/main init
│   ├── plan-iac.sh                                # terraform -chdir=terraform/stacks/main plan -var-file=../../..
│   ├── apply-iac.sh                               # terraform apply … && ansible-playbook …
│   ├── destroy-iac.sh                             # terraform destroy …
│   └── load-config.sh                             # exports env from custom-config-infrastructure.yaml
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── nat-gw/
│   │   ├── kms/
│   │   ├── iam/
│   │   ├── eks/
│   │   │   └── templates/kubeconfig.tpl
│   │   └── nodegroup/
│   └── stacks/
│       └── main/
│           ├── backend.tf
│           ├── provider.tf
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf               # publish ALL outputs the next steps use (IDs, ARNs, kubeconfig path, etc.)
│           ├── kubeconfig/              # TF writes kubeconfig file here (used by Ansible)
│           ├── keys/                    # optional: generated SSH key for bastion / nodes
│           └── tfplan/                  # CI artifact
├── ansible/                             # one-time bootstrap, then never used again
│   ├── inventory/                       # generated/templated; points at bastion (from TF outputs)
│   │   └── group_vars/all.yaml          # (optional) consume a subset of TF outputs
│   ├── playbooks/
│   │   ├── bootstrap-bastion.yml        # installs kubectl/helm, installs Argo CD, registers CMP, applies Root App
│   │   └── _roles/                      # optional if you keep it flat
│   └── templates/
│       └── argocd-root-app.yaml.j2      # rendered with plugin.env from TF outputs (or you can keep the final YAML in gitops/)
├── gitops/                              # Argo CD owns everything here
│   ├── argocd/
│   │   └── config/
│   │       └── argocd-cm-envsubst.yaml  # adds envsubst CMP; Ansible kubectl-applies this ONCE
│   ├── argo-apps/
│   │   ├── root/
│   │   │   └── argocd-root-app.yaml               # App-of-Apps; uses plugin.name: envsubstappofapp + plugin.env
│   │   └── apps/                                  # children apps (app-of-apps model), ordered by sync-wave
│   │       ├── 00-argocd/                     # envset-baseline (platform-config, monitoring, storage-system, …)
│   │       ├── 00-letsEncrypt/                     # envset-baseline (platform-config, monitoring, storage-system, …)
│   │       ├── 00-certmanager/                     # envset-baseline (platform-config, monitoring, storage-system, …)
│   │       ├── 00-cni-tuning/                     # prefix delegation patch on aws-node
│   │       ├── 00-metrics-server/
│   │       ├── 00-storage/                        # aws-ebs-csi-driver, default SC, tests
│   │       ├── 00-cni-tuning/                     # prefix delegation patch on aws-node
│   │       ├── 00-autoscaler/                     # cluster-autoscaler
│   │       ├── zz-observability/                  # monitoring stack (optional here or separate phase)
│   └── charts/                                    # (optional) if you wrap any apps as local Helm charts
└── project-next-phase.md                           # your running plan/notes (can be folded into README)
