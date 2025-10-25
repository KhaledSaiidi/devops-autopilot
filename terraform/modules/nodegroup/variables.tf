variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}
variable "node_group_role_arn" {
  description = "IAM role ARN for the node group."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs where nodes will run."
  type        = list(string)
}

variable "desired_size" {
  description = "Desired number of nodes."
  type        = number
  default     = 3
}

variable "max_size" {
  description = "Max number of nodes."
  type        = number
  default     = 5
}

variable "min_size" {
  description = "Min number of nodes."
  type        = number
  default     = 2
}

variable "ami_type" {
  description = "Node AMI type (e.g., AL2_x86_64, BOTTLEROCKET_x86_64)."
  type        = string
  default     = "AL2_x86_64"
}

variable "capacity_type" {
  description = "Capacity type: ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "disk_size" {
  description = "Node root volume size in GiB."
  type        = number
  default     = 30
}

variable "instance_types" {
  description = "Instance types for the node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_version" {
  description = "Kubernetes version for the node group."
  type        = string
  default     = "1.33"
}

variable "force_update_version" {
  description = "Force version update of the node group."
  type        = bool
  default     = false
}

variable "extra_labels" {
  description = "Additional Kubernetes labels for nodes."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Extra tags to apply to the node group."
  type        = map(string)
  default     = {}
}

variable "enable_ssh" {
  description = "Enable SSH access to worker nodes via EC2 key pair."
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "Name of the EC2 key pair to use for SSH (from IAM module)."
  type        = string
  default     = null
}

variable "source_security_group_ids" {
  description = "Optional source SGs allowed for SSH (22/tcp)."
  type        = list(string)
  default     = []
}