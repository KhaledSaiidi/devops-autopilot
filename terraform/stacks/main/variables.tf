############################################
# General Project Settings
############################################
variable "project_name" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "tags" {
  type    = map(any)
  default = {}
}

############################################
# VPC Settings
############################################
variable "vpc_cidr" {
  type = string
}
variable "enable_ipv6" {
  type    = bool
  default = false
}
variable "public_subnet_cidrs" {
  type = list(string)
}
variable "private_subnet_cidrs" {
  type = list(string)
}
variable "add_k8s_tags" {
  type    = bool
  default = true
}
variable "cluster_name" {
  type    = string
  default = "eks-cluster"
}

############################################
# SSH Key Settings
############################################
variable "create_ssh_key" {
  description = "Create SSH keypair via TLS provider for bastion/nodes."
  type        = bool
  default     = false
}
variable "enable_ssh" {
  description = "Enable SSH to worker nodes (restricted to bastion SG)."
  type        = bool
  default     = true
}
variable "ssh_key_name" {
  description = "Existing EC2 keypair to use (ignored if create_ssh_key=true)."
  type        = string
  default     = null
}

############################################
# IAM Settings
############################################
variable "enable_irsa" {
  description = "Create the IAM OIDC provider for IRSA."
  type        = bool
  default     = true
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

variable "create_ebs_csi_role" {
  type    = bool
  default = true
}

variable "ebs_csi_namespace" {
  type    = string
  default = "storage"
}

variable "ebs_csi_service_account" {
  type    = string
  default = "ebs-csi-controller-sa"
}

variable "create_cluster_autoscaler_role" {
  description = "Create an IRSA role for the Cluster Autoscaler."
  type        = bool
  default     = true
}

variable "cluster_autoscaler_namespace" {
  description = "Namespace where the Cluster Autoscaler ServiceAccount lives."
  type        = string
  default     = "kube-system"
}

variable "cluster_autoscaler_service_account" {
  description = "Name of the Cluster Autoscaler ServiceAccount."
  type        = string
  default     = "cluster-autoscaler"
}

############################################
# EKS Cluster Settings
############################################
variable "cluster_user" {
  type    = string
  default = "khaleds"
}

# Single version var drives both modules (avoid mismatches)
variable "eks_version" {
  type    = string
  default = "1.33"
}

variable "endpoint_private_access" {
  type    = bool
  default = true
}
variable "endpoint_public_access" {
  type    = bool
  default = true
}

# Leave [] so the eks module falls back to caller /32 automatically
variable "public_access_cidrs" {
  description = "If empty, EKS module detects caller /32; otherwise use these CIDRs."
  type        = list(string)
  default     = []
}

variable "service_ipv4_cidr" {
  type    = string
  default = "172.20.0.0/16"
}

variable "enabled_cluster_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "generate_kubeconfig" {
  type    = bool
  default = false
}

############################################
# Node Group Settings
############################################
variable "desired_size" {
  type    = number
  default = 3
}
variable "max_size" {
  type    = number
  default = 5
}
variable "min_size" {
  type    = number
  default = 2
}

variable "ami_type" {
  description = "EKS node AMI type (enum like AL2_x86_64, BOTTLEROCKET_x86_64)."
  type        = string
  default     = "AL2_x86_64"
}

variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "disk_size" {
  type    = number
  default = 30
}
variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "bastion_ami_id" {
  description = "Optional explicit AMI ID for bastion; empty uses module fallback."
  type        = string
  default     = ""
}

variable "bastion_admin_cidrs" {
  description = "Admin CIDRs allowed to SSH to bastion (if empty, module auto-detects caller /32)."
  type        = list(string)
  default     = []
}

variable "force_update_version" {
  type    = bool
  default = false
}
variable "extra_labels" {
  type    = map(string)
  default = {}
}

variable "kubectl_version" {
  description = "kubectl version Ansible installs on bastion (e.g., 1.30.5)."
  type        = string
  default     = ""
}

variable "helm_version" {
  description = "Helm version Ansible installs on bastion (e.g., v3.15.3)."
  type        = string
  default     = ""
}