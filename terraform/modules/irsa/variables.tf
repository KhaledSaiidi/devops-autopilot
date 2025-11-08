variable "project_name" {
  description = "Project or environment prefix used for IAM resource names."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to IAM resources."
  type        = map(string)
  default     = {}
}

variable "enable_irsa" {
  description = "Create the IAM OIDC provider for IRSA."
  type        = bool
  default     = true
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from EKS (module.eks.oidc_issuer_url). Required if enable_irsa = true."
  type        = string
  default     = ""
}

variable "create_alb_controller_role" {
  description = "Create an IRSA role for the AWS Load Balancer Controller."
  type        = bool
  default     = true
}

variable "alb_controller_namespace" {
  description = "Namespace where the AWS Load Balancer Controller ServiceAccount resides."
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
  description = "Create an IRSA role for the EBS CSI driver."
  type        = bool
  default     = true
}

variable "ebs_csi_namespace" {
  description = "Namespace where the EBS CSI controller ServiceAccount lives."
  type        = string
  default     = "storage-system"
}

variable "ebs_csi_service_account" {
  description = "ServiceAccount name for the EBS CSI controller."
  type        = string
  default     = "ebs-csi-controller-sa"
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
  description = "Create an IRSA role for Crossplane core/provider controllers handling networking workloads."
  type        = bool
  default     = true
}

variable "create_crossplane_data_role" {
  description = "Create an IRSA role for Crossplane data-plane controllers (databases, secrets, storage)."
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
  validation {
    condition     = length(var.crossplane_core_service_accounts) > 0
    error_message = "Provide at least one Crossplane core ServiceAccount for IRSA."
  }
}

variable "crossplane_data_service_accounts" {
  description = "ServiceAccounts allowed to assume the Crossplane data role."
  type        = list(string)
  default     = ["provider-aws-data"]
  validation {
    condition     = length(var.crossplane_data_service_accounts) > 0
    error_message = "Provide at least one Crossplane data ServiceAccount for IRSA."
  }
}

variable "crossplane_core_passrole_arns" {
  description = "Optional list of IAM role ARNs Crossplane core controllers may pass to AWS services."
  type        = list(string)
  default     = []
}

variable "crossplane_kms_key_arns" {
  description = "KMS keys Crossplane data controllers may use (encrypt/decrypt/data key)."
  type        = list(string)
  default     = []
}
