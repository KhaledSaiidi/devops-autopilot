resource "aws_eks_node_group" "this" {
  cluster_name    = var.eks_cluster_name
  node_group_name = "${var.eks_cluster_name}-node-group"

  node_role_arn = var.node_group_role_arn
  subnet_ids    = var.private_subnet_ids  # ← use list from VPC module outputs

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  ami_type             = var.ami_type
  capacity_type        = var.capacity_type
  disk_size            = var.disk_size
  instance_types       = var.instance_types
  version              = var.eks_version
  force_update_version = var.force_update_version

  labels = merge(
    {
      role = "${var.eks_cluster_name}-node-group-role"
      name = "${var.eks_cluster_name}-node-group"
    },
    var.extra_labels
  )

  tags = merge(
    {
      Name       = "${var.eks_cluster_name}-node-group"
      ManagedBy  = "Terraform"
      Component  = "eks"
    },
    var.tags
  )
}
