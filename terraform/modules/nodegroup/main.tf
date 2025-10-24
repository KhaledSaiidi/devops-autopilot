resource "aws_eks_node_group" "node_group" {
  cluster_name = var.EKS_CLUSTER_NAME

  node_group_name = "${var.EKS_CLUSTER_NAME}-node_group"

  node_role_arn = var.NODE_GROUP_ARN

  subnet_ids = [
    var.PRI_SUB3_ID,
    var.PRI_SUB4_ID
  ]

  scaling_config {
    desired_size = var.desired_size
    max_size = var.max_size
    min_size = var.min_size
  }

 
  ami_type = var.ami_type

  capacity_type = var.capacity_type

  disk_size = var.disk_size

  force_update_version = false

  instance_types = var.instance_types

  labels = {
    role = "${var.EKS_CLUSTER_NAME}-Node-group-role",
    name = "${var.EKS_CLUSTER_NAME}-node_group"
  }

  # Kubernetes version
  version = var.eks_version
}