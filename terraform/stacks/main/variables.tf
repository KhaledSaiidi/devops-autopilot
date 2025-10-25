############################################
# General Project Settings
############################################
variable "project_name" {
  description = "Project prefix used in resource names/tags."
  type        = string
}

variable "aws_region" {
  description = "AWS region of the EKS cluster."
  type        = string
}

variable "bucket" {
  description = "AWS region of the EKS cluster."
  type        = string
  default     = "devops-autopilot-bucket"
}

variable "state_key" {
  description = "AWS region of the EKS cluster."
  type        = string
  default     = "devops-autopilot.tfstate"
}

variable "dynamodb_table" {
  description = "AWS region of the EKS cluster."
  type        = string
  default     = "devops-autopilot-dynamo-table"
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(any)
  default     = {}
}

############################################
# VPC Settings
############################################
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

############################################
# IAM / SSH Key Settings
############################################
variable "create_ssh_key" {
  description = "Whether to create an SSH key pair for EC2 access."
  type        = bool
  default     = false
}

############################################
# EKS Cluster Settings
############################################
variable "cluster_user" {
  description = "Username for the kubeconfig user section (for identification)."
  type        = string
  default     = "khaleds"
}

variable "eks_version" {
  description = "Kubernetes version for the EKS cluster and node groups."
  type        = string
  default     = "1.33"
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

############################################
# Node Group Settings
############################################
variable "desired_size" {
  description = "Desired number of nodes."
  type        = number
  default     = 3
}

variable "max_size" {
  description = "Maximum number of nodes."
  type        = number
  default     = 5
}

variable "min_size" {
  description = "Minimum number of nodes."
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
