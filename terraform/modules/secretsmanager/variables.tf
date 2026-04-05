variable "project_name" {
  description = "Project or environment prefix used for naming."
  type        = string
}

variable "name" {
  description = "Secrets Manager secret name. Defaults to <project_name>-bootstrap."
  type        = string
  default     = ""
}

variable "description" {
  description = "Description for the Secrets Manager secret."
  type        = string
  default     = ""
}

variable "secret_values" {
  description = "Map of key/value pairs stored as a JSON secret string."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "kms_key_id" {
  description = "Optional KMS key ID or ARN used to encrypt the secret."
  type        = string
  default     = ""
}

variable "recovery_window_in_days" {
  description = "Recovery window before secret deletion is finalized."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags applied to the secret."
  type        = map(string)
  default     = {}
}
