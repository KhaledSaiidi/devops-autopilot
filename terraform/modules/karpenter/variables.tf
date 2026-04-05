variable "project_name" {
  description = "Project or environment prefix used for AWS resource names."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used by Karpenter."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider backing IRSA."
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from the EKS cluster."
  type        = string
}

variable "namespace" {
  description = "Namespace where the Karpenter controller service account runs."
  type        = string
  default     = "karpenter"
}

variable "service_account" {
  description = "ServiceAccount name used by the Karpenter controller."
  type        = string
  default     = "karpenter"
}

variable "node_role_arn" {
  description = "IAM role ARN to pass through to EC2 nodes launched by Karpenter."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to Karpenter AWS resources."
  type        = map(string)
  default     = {}
}
