variable "EKS_CLUSTER_NAME" {}
variable "NODE_GROUP_ARN" {}
variable "PRI_SUB3_ID" {}
variable "PRI_SUB4_ID" {}

variable "desired_size" {
    description = "desired node size value"
    type = number
    default = 3
}
variable "max_size" {
    description = "desired node size value"
    type = number
    default = 5
}
variable "min_size" {
    description = "desired node size value"
    type = number
    default = 2
}
variable "ami_type" {
  description = "Type of AMI to use for the node group. Common options: AL2_x86_64, AL2_x86_64_GPU, BOTTLEROCKET_x86_64."
  type        = string
  default     = "AL2_x86_64"
}
variable "capacity_type" {
  description = "Node capacity type — either ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"
}
variable "disk_size" {
  description = "Disk size in GiB for worker nodes."
  type        = number
  default     = 30
}
variable "eks_version" {
    description = "desired eks version"
    type = string
    default = "1.33"
}
variable "instance_types" {
  description = "EC2 instance types for the EKS node group. Use a list for multiple types."
  type        = list(string)
  default     = ["t3.medium"]
}