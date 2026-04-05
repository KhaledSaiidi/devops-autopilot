output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider used for IRSA (if created)."
  value       = try(aws_iam_openid_connect_provider.eks[0].arn, null)
}

output "alb_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller."
  value       = try(aws_iam_role.alb_controller[0].arn, null)
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for the EBS CSI controller (IRSA)."
  value       = try(aws_iam_role.ebs_csi[0].arn, null)
}

output "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for Cluster Autoscaler (if created)."
  value       = try(aws_iam_role.cluster_autoscaler[0].arn, null)
}

output "crossplane_core_role_arn" {
  description = "IRSA role ARN used by Crossplane core/provider controllers."
  value       = try(aws_iam_role.crossplane_core[0].arn, null)
}

output "crossplane_data_role_arn" {
  description = "IRSA role ARN for Crossplane data-plane controllers."
  value       = try(aws_iam_role.crossplane_data[0].arn, null)
}

output "cert_manager_role_arn" {
  description = "IRSA role ARN for cert-manager DNS automation."
  value       = try(aws_iam_role.cert_manager[0].arn, null)
}

output "external_dns_role_arn" {
  description = "IRSA role ARN for external-dns."
  value       = try(aws_iam_role.external_dns[0].arn, null)
}

output "external_secrets_role_arn" {
  description = "IRSA role ARN for External Secrets Operator."
  value       = try(aws_iam_role.external_secrets[0].arn, null)
}
