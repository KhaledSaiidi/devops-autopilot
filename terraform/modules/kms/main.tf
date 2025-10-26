data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  key_description = "${var.project_name} EKS secrets CMK"
}

/*
Key policy:
- Account root = full admin (so you don’t lock yourself out)
- EKS cluster role = the minimal set needed to encrypt/decrypt secrets
  (CreateGrant lets EKS create limited grants during control-plane ops)
*/
resource "aws_kms_key" "eks_secrets" {
  description             = local.key_description
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowRootAccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowEKSClusterRoleUseOfTheKey"
        Effect    = "Allow"
        Principal = { AWS = var.cluster_role_arn }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:EncryptionContext:aws:eks:cluster-name" = var.cluster_name
          }
        }
      }
    ]
  })

  tags = merge({
    Name      = "${var.project_name}-eks-secrets-kms"
    Component = "security"
  }, var.tags)
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.project_name}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}
