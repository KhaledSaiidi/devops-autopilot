output "key_arn" {
  value       = aws_kms_key.eks_secrets.arn
  description = "CMK ARN for EKS secret encryption."
}

output "alias_name" {
  value       = aws_kms_alias.eks_secrets.name
  description = "Friendly alias."
}