output "eks_cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane."
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_cluster_role_name" {
  value = aws_iam_role.eks_cluster_role.name
}
output "eks_node_role_arn" {
  description = "IAM role ARN for the EKS worker nodes."
  value       = aws_iam_role.eks_node_role.arn
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider used for IRSA (if created)."
  value       = try(aws_iam_openid_connect_provider.eks[0].arn, null)
}

output "alb_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller (if created)."
  value       = try(aws_iam_role.alb_controller[0].arn, null)
}

output "ebs_csi_role_arn" {
  value       = try(aws_iam_role.ebs_csi[0].arn, null)
  description = "IAM role ARN for the EBS CSI controller (IRSA)"
}

output "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for Cluster Autoscaler (if created)."
  value       = try(aws_iam_role.cluster_autoscaler[0].arn, null)
}