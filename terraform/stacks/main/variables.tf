############################################
# General Project Settings
############################################
variable "project_name" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "tags" {
  type    = map(any)
  default = {}
}

############################################
# VPC Settings
############################################
variable "vpc_cidr" {
  type = string
}
variable "enable_ipv6" {
  type    = bool
  default = false
}
variable "public_subnet_cidrs" {
  type = list(string)
}
variable "private_subnet_cidrs" {
  type = list(string)
}
variable "add_k8s_tags" {
  type    = bool
  default = true
}
variable "cluster_name" {
  type    = string
  default = "eks-cluster"
}

############################################
# SSH Key Settings
############################################
variable "create_ssh_key" {
  description = "Create SSH keypair via TLS provider for bastion/nodes."
  type        = bool
  default     = false
}
variable "enable_ssh" {
  description = "Enable SSH to worker nodes (restricted to bastion SG)."
  type        = bool
  default     = true
}
variable "ssh_key_name" {
  description = "Existing EC2 keypair to use (ignored if create_ssh_key=true)."
  type        = string
  default     = null
}

############################################
# IAM Settings
############################################
variable "enable_irsa" {
  description = "Create the IAM OIDC provider for IRSA."
  type        = bool
  default     = true
}

variable "create_alb_controller_role" {
  description = "Create an IRSA role for the AWS Load Balancer Controller."
  type        = bool
  default     = true
}

variable "alb_controller_namespace" {
  description = "Namespace where the AWS Load Balancer Controller ServiceAccount lives."
  type        = string
  default     = "kube-system"
}

variable "alb_controller_service_account" {
  description = "ServiceAccount name for the AWS Load Balancer Controller."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "lbc_policy_url" {
  description = "Raw URL to the official AWS Load Balancer Controller IAM policy JSON (pin to a specific version)."
  type        = string
  default     = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
}

variable "create_ebs_csi_role" {
  type    = bool
  default = true
}

variable "ebs_csi_namespace" {
  type    = string
  default = "storage-system"
}

variable "ebs_csi_service_account" {
  type    = string
  default = "ebs-csi-controller-sa"
}

variable "create_cluster_autoscaler_role" {
  description = "Create an IRSA role for the Cluster Autoscaler."
  type        = bool
  default     = true
}

variable "cluster_autoscaler_namespace" {
  description = "Namespace where the Cluster Autoscaler ServiceAccount lives."
  type        = string
  default     = "kube-system"
}

variable "cluster_autoscaler_service_account" {
  description = "Name of the Cluster Autoscaler ServiceAccount."
  type        = string
  default     = "cluster-autoscaler"
}

variable "create_crossplane_core_role" {
  description = "Create an IRSA role for Crossplane core/provider controllers."
  type        = bool
  default     = true
}

variable "create_crossplane_data_role" {
  description = "Create an IRSA role for Crossplane data-plane controllers."
  type        = bool
  default     = true
}

variable "crossplane_namespace" {
  description = "Namespace where Crossplane controllers run."
  type        = string
  default     = "crossplane-system"
}

variable "crossplane_core_service_accounts" {
  description = "ServiceAccounts allowed to assume the Crossplane core role."
  type        = list(string)
  default     = ["provider-aws-core"]
}

variable "crossplane_data_service_accounts" {
  description = "ServiceAccounts allowed to assume the Crossplane data role."
  type        = list(string)
  default     = ["provider-aws-data"]
}

variable "crossplane_core_passrole_arns" {
  description = "IAM roles Crossplane core controllers can pass."
  type        = list(string)
  default     = []
}

variable "crossplane_kms_key_arns" {
  description = "KMS keys Crossplane data controllers can use. Defaults to the cluster key if empty."
  type        = list(string)
  default     = []
}

variable "create_cert_manager_role" {
  description = "Create an IRSA role scoped to Route53 for cert-manager DNS01 challenges."
  type        = bool
  default     = true
}

variable "cert_manager_namespace" {
  description = "Namespace where cert-manager runs."
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_service_account" {
  description = "cert-manager ServiceAccount name."
  type        = string
  default     = "cert-manager"
}

variable "create_external_dns_role" {
  description = "Create an IRSA role for external-dns."
  type        = bool
  default     = true
}

variable "external_dns_namespace" {
  description = "Namespace where external-dns runs."
  type        = string
  default     = "dns-system"
}

variable "external_dns_service_account" {
  description = "ServiceAccount for external-dns."
  type        = string
  default     = "external-dns"
}

############################################
# EKS Cluster Settings
############################################
variable "cluster_user" {
  type    = string
  default = "khaleds"
}

# Single version var drives both modules (avoid mismatches)
variable "eks_version" {
  type    = string
  default = "1.33"
}

variable "endpoint_private_access" {
  type    = bool
  default = true
}
variable "endpoint_public_access" {
  type    = bool
  default = true
}

# Leave [] so the eks module falls back to caller /32 automatically
variable "public_access_cidrs" {
  description = "If empty, EKS module detects caller /32; otherwise use these CIDRs."
  type        = list(string)
  default     = []
}

variable "service_ipv4_cidr" {
  type    = string
  default = "172.20.0.0/16"
}

variable "enabled_cluster_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "generate_kubeconfig" {
  type    = bool
  default = false
}

############################################
# Node Group Settings
############################################
variable "desired_size" {
  type    = number
  default = 3
}
variable "max_size" {
  type    = number
  default = 5
}
variable "min_size" {
  type    = number
  default = 2
}

variable "ami_type" {
  description = "EKS node AMI type (enum like AL2_x86_64, BOTTLEROCKET_x86_64)."
  type        = string
  default     = "AL2_x86_64"
}

variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "disk_size" {
  type    = number
  default = 30
}
variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "bastion_ami_id" {
  description = "Optional explicit AMI ID for bastion; empty uses module fallback."
  type        = string
  default     = ""
}

variable "bastion_admin_cidrs" {
  description = "Admin CIDRs allowed to SSH to bastion (if empty, module auto-detects caller /32)."
  type        = list(string)
  default     = []
}

variable "force_update_version" {
  type    = bool
  default = false
}
variable "extra_labels" {
  type    = map(string)
  default = {}
}

variable "kubectl_version" {
  description = "kubectl version Ansible installs on bastion (e.g., 1.30.5)."
  type        = string
  default     = ""
}

variable "helm_version" {
  description = "Helm version Ansible installs on bastion (e.g., v3.15.3)."
  type        = string
  default     = ""
}

variable "argocd_namespace" {
  description = "Argocd namespace to install into"
  type        = string
  default     = ""
}

variable "argocd_create_namespace" {
  description = "Argocd create namespace if not exists"
  type        = bool
  default     = true
}

variable "argocd_server_service_type" {
  description = "Argocd server service type (e.g., LoadBalancer, ClusterIP, NodePort)"
  type        = string
  default     = ""
}

variable "argocd_enable_envsubst_plugin" {
  description = "Argocd enable envsubst plugin"
  type        = bool
  default     = true
}

variable "argocd_enable_lovely_plugin" {
  description = "Argocd enable lovely plugin"
  type        = bool
  default     = true
}
variable "argocd_wait_timeout" {
  description = "ArgoCD wait timeout in seconds"
  type        = number
  default     = 100
}

variable "argocd_wait_interval" {
  description = "ArgoCD wait interval in seconds"
  type        = number
  default     = 10
}

variable "argocd_reconciliation_timeout" {
  description = "ArgoCD reconciliation time"
  type        = string
  default     = ""
}


variable "argocd_exec_timeout" {
  description = "ArgoCD execution time"
  type        = string
  default     = ""
}

############################################
# DNS and certificate automation
############################################
variable "dns_base_domain" {
  description = "Primary Route53 domain (e.g., example.com)."
  type        = string
  default     = ""
}

variable "dns_external_label" {
  description = "Label for the public/platform delegated zone."
  type        = string
  default     = "platform"
}

variable "dns_hosted_zone_id" {
  description = "Optional explicit hosted zone ID to use for DNS automation."
  type        = string
  default     = ""
}

variable "cert_manager_email" {
  description = "Email used for ACME registration."
  type        = string
  default     = ""
}

variable "cert_manager_server" {
  description = "ACME directory URL."
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}


variable "external_dns_txt_owner_id" {
  description = "Unique owner ID for external-dns TXT records."
  type        = string
  default     = ""
}

variable "external_dns_txt_prefix" {
  description = "TXT prefix external-dns should use."
  type        = string
  default     = "_external-dns"
}

variable "external_dns_policy" {
  description = "external-dns policy (sync/upsert-only)."
  type        = string
  default     = "upsert-only"
}

variable "external_dns_log_level" {
  description = "external-dns log level."
  type        = string
  default     = "info"
}

variable "external_dns_interval" {
  description = "Reconciliation interval."
  type        = string
  default     = "1m"
}

variable "external_dns_trigger_loop_on_event" {
  description = "Trigger reconciliation on Kubernetes events."
  type        = bool
  default     = true
}

############################################
# Gateway API / Ingress Settings
############################################
variable "gateway_api_namespace" {
  description = "Override the namespace for Gateway API resources (defaults to alb_controller_namespace when empty)."
  type        = string
  default     = ""
}

variable "gateway_api_gateway_class_name" {
  description = "Name of the GatewayClass managed by the AWS Load Balancer Controller."
  type        = string
  default     = "aws-alb-gateway-class"
}

variable "gateway_api_controller" {
  description = "Controller-level toggles for AWS Load Balancer Controller Gateway API features."
  type = object({
    default_target_type = optional(string, "ip")
    enable_alb_gateway  = optional(bool, true)
    enable_nlb_gateway  = optional(bool, false)
    enable_shield_addon = optional(bool, true)
    log_level           = optional(string, "info")
  })
  default = {}
}

variable "gateway_api_load_balancer" {
  description = "Base load balancer configuration for AWS Gateway API Gateways."
  type = object({
    ip_address_type             = optional(string, "ipv4")
    external_scheme             = optional(string, "internet-facing")
    internal_scheme             = optional(string, "internal")
    deletion_protection_enabled = optional(bool, true)
    idle_timeout_seconds        = optional(number, 60)
    external_shield_enabled     = optional(bool, true)
    internal_shield_enabled     = optional(bool, false)
    tags                        = optional(map(string), {})
  })
  default = {}
}

variable "gateway_api_external_gateway" {
  description = "Public (internet-facing) Gateway definition."
  type = object({
    enabled             = optional(bool, true)
    name                = optional(string, "public-gateway")
    http_port           = optional(number, 80)
    https_port          = optional(number, 443)
    hostname            = optional(string, "")
    allowed_routes_from = optional(string, "All")
    tls_certificate_arn = optional(string, "")
  })
  default = {}
}

variable "gateway_api_internal_gateway" {
  description = "Private (internal) Gateway definition."
  type = object({
    enabled             = optional(bool, true)
    name                = optional(string, "internal-gateway")
    http_port           = optional(number, 8080)
    https_port          = optional(number, 8443)
    hostname            = optional(string, "")
    allowed_routes_from = optional(string, "Same")
    tls_certificate_arn = optional(string, "")
  })
  default = {}
}
