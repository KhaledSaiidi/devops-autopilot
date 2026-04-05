locals {
  effective_name        = trimspace(var.name) != "" ? trimspace(var.name) : "${var.project_name}-bootstrap"
  effective_description = trimspace(var.description) != "" ? trimspace(var.description) : "Bootstrap application secret managed by Terraform."
}

resource "aws_secretsmanager_secret" "this" {
  name                    = local.effective_name
  description             = local.effective_description
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = trimspace(var.kms_key_id) != "" ? trimspace(var.kms_key_id) : null

  tags = merge(
    {
      Name      = local.effective_name
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode(var.secret_values)

  lifecycle {
    precondition {
      condition     = length(var.secret_values) > 0
      error_message = "secret_values must contain at least one key/value pair."
    }
  }
}
