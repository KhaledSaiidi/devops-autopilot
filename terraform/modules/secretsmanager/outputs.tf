output "arn" {
  description = "ARN of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.arn
}

output "name" {
  description = "Name of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.this.name
}

output "version_id" {
  description = "Version ID of the current secret value."
  value       = aws_secretsmanager_secret_version.this.version_id
}
