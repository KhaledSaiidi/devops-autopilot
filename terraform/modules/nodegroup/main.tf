resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.private_subnet_ids

  # --- SSH remote access (optional) ---
  dynamic "remote_access" {
    for_each = var.enable_ssh && var.ssh_key_name != null ? [1] : []
    content {
      ec2_ssh_key               = var.ssh_key_name
      # If you pass SGs here, restricts SSH to those; empty means AWS uses a default behavior.
      # For a hardened setup, pass a Bastion/SSM SG here.
      source_security_group_ids = var.source_security_group_ids
    }
  }

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
      role = "${var.cluster_name}-node-group-role"
      name = "${var.cluster_name}-node-group"
    },
    var.extra_labels
  )

  tags = merge(
    {
      Name      = "${var.cluster_name}-node-group"
      ManagedBy = "Terraform"
      Component = "eks"
    },
    var.tags
  )
}

#########################
# SSH Key Pair (Optional)
#########################

resource "tls_private_key" "eks_key" {
  count     = var.create_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "eks_keypair" {
  count      = var.create_ssh_key ? 1 : 0
  key_name   = "${var.project_name}-eks-key"
  public_key = tls_private_key.eks_key[0].public_key_openssh

  tags = merge(
    {
      Name      = "${var.project_name}-eks-keypair"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "local_file" "private_key" {
  count           = var.create_ssh_key ? 1 : 0
  content         = tls_private_key.eks_key[0].private_key_pem
  filename        = "${path.module}/../../keys/${var.project_name}-eks.pem"
  file_permission = "0600"
}