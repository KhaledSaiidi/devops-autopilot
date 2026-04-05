output "eks_cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane."
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_cluster_role_name" {
  description = "IAM role name for the EKS control plane."
  value       = aws_iam_role.eks_cluster_role.name
}

output "eks_node_role_arn" {
  description = "IAM role ARN for the EKS worker nodes."
  value       = aws_iam_role.eks_node_role.arn
}

output "eks_node_role_name" {
  description = "IAM role name for the EKS worker nodes."
  value       = aws_iam_role.eks_node_role.name
}

output "bastion_instance_profile_name" {
  description = "Instance profile name for the bastion host."
  value       = aws_iam_instance_profile.bastion.name
}

output "bastion_role_arn" {
  description = "IAM role ARN for the bastion host."
  value       = aws_iam_role.bastion_role.arn
}
