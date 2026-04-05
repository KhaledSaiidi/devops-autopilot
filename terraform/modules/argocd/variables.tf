variable "artifacts_dir" {
  description = "Absolute path to the stack artifacts directory."
  type        = string
}

variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "argocd_namespace" {
  description = "Target namespace for Argo CD."
  type        = string
  default     = ""
}

variable "argocd_server_service_type" {
  description = "Argo CD server service type."
  type        = string
  default     = ""
}

variable "argocd_reconciliation_timeout" {
  description = "Argo CD reconciliation timeout value."
  type        = string
  default     = ""
}

variable "argocd_exec_timeout" {
  description = "Argo CD exec timeout value."
  type        = string
  default     = ""
}

variable "cluster" {
  description = "Cluster metadata used for the root app plugin environment."
  type = object({
    name                 = string
    endpoint             = string
    oidc_issuer_url      = string
    kubeconfig_path      = string
    ssh_private_key_path = string
  })
}

variable "networking" {
  description = "Network metadata used by GitOps applications."
  type = object({
    vpc_id             = string
    public_subnet_ids  = list(string)
    private_subnet_ids = list(string)
  })
}

variable "iam_roles" {
  description = "IAM role ARNs consumed by GitOps applications."
  type = object({
    eks_cluster_role_arn = string
    eks_node_role_arn    = string
    eks_node_role_name   = string
  })
}

variable "irsa" {
  description = "IRSA outputs and related namespace/service account metadata."
  type = object({
    ebs_csi_role_arn                 = string
    ebs_csi_namespace                = string
    ebs_csi_service_account          = string
    alb_controller_role_arn          = string
    alb_controller_namespace         = string
    alb_controller_service_account   = string
    crossplane_namespace             = string
    crossplane_core_role_arn         = string
    crossplane_core_service_accounts = list(string)
    crossplane_data_role_arn         = string
    crossplane_data_service_accounts = list(string)
    cert_manager_role_arn            = string
    cert_manager_namespace           = string
    cert_manager_service_account     = string
    external_dns_role_arn            = string
    external_dns_namespace           = string
    external_dns_service_account     = string
    external_secrets_role_arn        = string
    external_secrets_namespace       = string
    external_secrets_service_account = string
  })
}

variable "bastion_public_ip" {
  description = "Public IP for the bastion host."
  type        = string
}

variable "nodegroup" {
  description = "Managed node group settings exposed to GitOps applications."
  type = object({
    desired_size   = number
    min_size       = number
    max_size       = number
    ami_type       = string
    instance_types = list(string)
    capacity_type  = string
    disk_size      = number
  })
}

variable "dns" {
  description = "DNS metadata exposed to GitOps applications."
  type = object({
    base_domain              = string
    root_domain              = string
    external_label           = string
    internal_label           = string
    hosted_zone_id           = string
    external_fqdn            = string
    internal_fqdn            = string
    external_wildcard_domain = string
    internal_wildcard_domain = string
  })
}

variable "cert_manager" {
  description = "cert-manager specific bootstrap values."
  type = object({
    email  = string
    server = string
  })
}

variable "external_dns" {
  description = "external-dns specific bootstrap values."
  type = object({
    txt_owner_id          = string
    txt_prefix            = string
    policy                = string
    log_level             = string
    interval              = string
    trigger_loop_on_event = bool
  })
}

variable "karpenter" {
  description = "Karpenter controller bootstrap values."
  type = object({
    namespace               = string
    service_account         = string
    controller_role_arn     = string
    interruption_queue_name = string
  })
}

variable "gateway_api" {
  description = "Gateway API and AWS Load Balancer Controller values."
  type = object({
    namespace          = string
    gateway_class_name = string
    controller = object({
      default_target_type = string
      enable_alb_gateway  = bool
      enable_nlb_gateway  = bool
      enable_shield_addon = bool
      log_level           = string
    })
    load_balancer = object({
      ip_address_type             = string
      external_scheme             = string
      internal_scheme             = string
      deletion_protection_enabled = bool
      idle_timeout_seconds        = number
      external_shield_enabled     = bool
      internal_shield_enabled     = bool
    })
    external_gateway = object({
      name                = string
      http_port           = number
      https_port          = number
      hostname            = string
      allowed_routes_from = string
    })
    internal_gateway = object({
      name                = string
      http_port           = number
      https_port          = number
      hostname            = string
      allowed_routes_from = string
    })
  })
}

variable "gitops_root_app_repo_url" {
  description = "Git repository URL for the Argo CD root application."
  type        = string
  default     = "https://github.com/KhaledSaiidi/devops-autopilot.git"
}

variable "gitops_root_app_target_revision" {
  description = "Git revision for the Argo CD root application."
  type        = string
  default     = "main"
}

variable "gitops_root_app_path" {
  description = "Repository path for the Argo CD root application."
  type        = string
  default     = "gitops/argo-apps/overlays/default/root"
}
