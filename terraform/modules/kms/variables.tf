variable "project_name" {
  description = "Project prefix used in names."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name; used in key policy conditions."
  type        = string
}

variable "cluster_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  type        = string
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}