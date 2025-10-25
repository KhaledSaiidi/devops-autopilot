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