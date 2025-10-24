variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_user" {
  description = "Username for the kubeconfig user section (for identification)."
  type        = string
  default     = "khaleds"
}
variable "cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS control plane (public + private)."
  type        = list(string)
}

variable "eks_version" {
  description = "Desired Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.30"
}

variable "endpoint_private_access" {
  description = "Indicates whether the EKS API endpoint is private."
  type        = bool
  default     = false
}

variable "endpoint_public_access" {
  description = "Indicates whether the EKS API endpoint is public."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "service_ipv4_cidr" {
  description = "CIDR block for Kubernetes services."
  type        = string
  default     = "172.20.0.0/16"
}

variable "enabled_cluster_log_types" {
  description = "List of control plane log types to enable."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "generate_kubeconfig" {
  description = "Whether to generate a kubeconfig file locally."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region of the EKS cluster."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
