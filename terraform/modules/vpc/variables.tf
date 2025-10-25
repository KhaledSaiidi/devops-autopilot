variable "project_name" {
  description = "Project prefix used in resource names/tags."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "enable_ipv6" {
  description = "Whether to request an IPv6 /56 for the VPC."
  type        = bool
  default     = false
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
}

variable "add_k8s_tags" {
  description = "Whether to add Kubernetes ELB/internal-ELB and cluster shared tags."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Kubernetes cluster name used for k8s-related subnet tags."
  type        = string
  default     = "eks-cluster"
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(any)
  default     = {}
}
