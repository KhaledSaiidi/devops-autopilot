variable "project_name" {
  description = "Project or environment prefix used for IAM resource names."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all IAM resources."
  type        = map(string)
  default     = {}
}

variable "create_ssh_key" {
  description = "Whether to create an SSH key pair for EC2 access."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt Kubernetes Secrets"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "EKS cluster name used in KMS condition"
  type        = string
}