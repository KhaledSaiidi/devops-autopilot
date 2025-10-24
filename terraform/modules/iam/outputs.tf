output "eks_cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane."
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_arn" {
  description = "IAM role ARN for the EKS worker nodes."
  value       = aws_iam_role.eks_node_role.arn
}
