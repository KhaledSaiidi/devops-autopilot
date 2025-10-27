variable "project_name" {
  description = "Project or environment prefix used for IAM resource names."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all IAM resources."
  type        = map(string)
  default     = {}
}

# OIDC provider + ALB Controller IRSA role

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

variable "cluster_name" {
  description = "EKS cluster name (optional, used in tags/description)."
  type        = string
  default     = ""
}

variable "create_alb_controller_role" {
  description = "Create an IRSA role for the AWS Load Balancer Controller."
  type        = bool
  default     = true
}
variable "lbc_policy_url" {
  description = "Raw URL to the official AWS Load Balancer Controller IAM policy JSON (pin to a specific version)."
  type        = string
  default     = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
}

