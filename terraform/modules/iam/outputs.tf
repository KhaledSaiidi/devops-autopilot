output "eks_cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane."
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_arn" {
  description = "IAM role ARN for the EKS worker nodes."
  value       = aws_iam_role.eks_node_role.arn
}

output "ssh_private_key_path" {
  description = "Path to the generated SSH private key."
  value       = var.create_ssh_key ? local_file.private_key[0].filename : null
}

output "ssh_key_name" {
  description = "AWS key pair name for EC2 nodes."
  value       = var.create_ssh_key ? aws_key_pair.eks_keypair[0].key_name : null
}