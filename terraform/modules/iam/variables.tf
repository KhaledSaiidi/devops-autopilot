variable "project_name" {
  description = "Project or environment prefix used for IAM resource names."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to IAM resources."
  type        = map(string)
  default     = {}
}
