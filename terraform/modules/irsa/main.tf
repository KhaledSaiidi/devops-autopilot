#############################
# Official LBC policy (HTTP)
#############################
data "http" "lbc_policy" {
  count = var.enable_irsa && var.create_alb_controller_role ? 1 : 0
  url   = var.lbc_policy_url

  # Optional hardening: ensure we actually got JSON back
  request_headers = { Accept = "application/json" }
}

locals {
  # Strip https:// for condition keys (e.g., oidc.eks.<region>.amazonaws.com/id/<id>:sub)
  oidc_hostpath              = var.oidc_issuer_url != "" ? replace(var.oidc_issuer_url, "https://", "") : ""
  crossplane_core_subjects   = [for sa in var.crossplane_core_service_accounts : "system:serviceaccount:${var.crossplane_namespace}:${sa}"]
  crossplane_data_subjects   = [for sa in var.crossplane_data_service_accounts : "system:serviceaccount:${var.crossplane_namespace}:${sa}"]
  crossplane_s3_bucket_arn   = "arn:aws:s3:::${var.project_name}-crossplane-*"
  crossplane_s3_objects_arn  = "${local.crossplane_s3_bucket_arn}/*"
  crossplane_secret_resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}-*"
  has_route53_zones          = length(var.route53_zone_arns) > 0
  cert_manager_subject       = "system:serviceaccount:${var.cert_manager_namespace}:${var.cert_manager_service_account}"
  external_dns_subject       = "system:serviceaccount:${var.external_dns_namespace}:${var.external_dns_service_account}"
}

# Get OIDC root CA fingerprint
data "tls_certificate" "eks_oidc" {
  count = var.enable_irsa ? 1 : 0
  url   = var.oidc_issuer_url
  lifecycle {
    precondition {
      condition     = var.enable_irsa ? (var.oidc_issuer_url != "" && can(regex("^https://", var.oidc_issuer_url))) : true
      error_message = "IRSA enabled but oidc_issuer_url is empty or invalid. Reference module.eks.oidc_issuer_url."
    }
  }
}

resource "aws_iam_openid_connect_provider" "eks" {
  count           = var.enable_irsa ? 1 : 0
  url             = var.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc[0].certificates[0].sha1_fingerprint]

  tags = merge(
    {
      Name      = "${var.project_name}-eks-oidc"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

############################################
# IRSA role for AWS Load Balancer Controller
############################################

data "aws_iam_policy_document" "alb_controller_trust" {
  count = var.enable_irsa && var.create_alb_controller_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    # Exact audience for IRSA
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Exact SA identity constraint
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values = [
        "system:serviceaccount:${var.alb_controller_namespace}:${var.alb_controller_service_account}"
      ]
    }
  }
}

# Official AWS Load Balancer Controller policy (fetched via HTTP)
resource "aws_iam_policy" "alb_controller" {
  count       = var.enable_irsa && var.create_alb_controller_role ? 1 : 0
  name        = "${var.project_name}-alb-controller"
  description = "Official AWS Load Balancer Controller policy (fetched via http)"
  policy      = data.http.lbc_policy[0].response_body

  lifecycle {
    precondition {
      condition     = can(jsondecode(data.http.lbc_policy[0].response_body))
      error_message = "Failed to fetch/parse the official LBC policy JSON from lbc_policy_url."
    }
  }

  tags = merge(
    {
      Name      = "${var.project_name}-alb-controller-policy"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role" "alb_controller" {
  count              = var.enable_irsa && var.create_alb_controller_role ? 1 : 0
  name               = "${var.project_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_trust[0].json

  tags = merge(
    {
      Name      = "${var.project_name}-alb-controller-role"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  count      = var.enable_irsa && var.create_alb_controller_role ? 1 : 0
  role       = aws_iam_role.alb_controller[0].name
  policy_arn = aws_iam_policy.alb_controller[0].arn
}

# -----------------------------
# EBS CSI IRSA (enable via flag)
# -----------------------------
data "aws_iam_policy_document" "ebs_csi_trust" {
  count = var.enable_irsa && var.create_ebs_csi_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:${var.ebs_csi_namespace}:${var.ebs_csi_service_account}"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count              = var.enable_irsa && var.create_ebs_csi_role ? 1 : 0
  name               = "${var.project_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_trust[0].json

  tags = merge(
    { Name = "${var.project_name}-ebs-csi-role", ManagedBy = "Terraform" },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.enable_irsa && var.create_ebs_csi_role ? 1 : 0
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# =============================================================================
# Cluster Autoscaler IRSA
# =============================================================================

data "aws_iam_policy_document" "cluster_autoscaler_trust" {
  count = var.enable_irsa && var.create_cluster_autoscaler_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    # IRSA audience
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Exact SA identity constraint
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values = [
        "system:serviceaccount:${var.cluster_autoscaler_namespace}:${var.cluster_autoscaler_service_account}"
      ]
    }
  }
}

# Least-privilege policy for Cluster Autoscaler with EKS managed nodegroups
data "aws_iam_policy_document" "cluster_autoscaler_policy_doc" {
  count = var.enable_irsa && var.create_cluster_autoscaler_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeAvailabilityZones"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count       = var.enable_irsa && var.create_cluster_autoscaler_role ? 1 : 0
  name        = "${var.project_name}-cluster-autoscaler"
  description = "Cluster Autoscaler policy for EKS managed nodegroups"
  policy      = data.aws_iam_policy_document.cluster_autoscaler_policy_doc[0].json

  tags = merge(
    { Name = "${var.project_name}-cluster-autoscaler-policy", ManagedBy = "Terraform" },
    var.tags
  )
}

resource "aws_iam_role" "cluster_autoscaler" {
  count              = var.enable_irsa && var.create_cluster_autoscaler_role ? 1 : 0
  name               = "${var.project_name}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_trust[0].json

  tags = merge(
    { Name = "${var.project_name}-cluster-autoscaler-role", ManagedBy = "Terraform" },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count      = var.enable_irsa && var.create_cluster_autoscaler_role ? 1 : 0
  role       = aws_iam_role.cluster_autoscaler[0].name
  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
}

############################################
# Crossplane IRSA Roles
############################################

data "aws_iam_policy_document" "crossplane_core_trust" {
  count = var.enable_irsa && var.create_crossplane_core_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = local.crossplane_core_subjects
    }
  }
}

data "aws_iam_policy_document" "crossplane_core_policy" {
  count = var.enable_irsa && var.create_crossplane_core_role ? 1 : 0

  statement {
    sid    = "Route53Management"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:ListResourceRecordSets",
      "route53:GetHostedZone"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LoadBalancerRead"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "Ec2Describe"
    effect    = "Allow"
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }

  statement {
    sid    = "Tagging"
    effect = "Allow"
    actions = [
      "tag:GetResources",
      "tag:TagResources",
      "tag:UntagResources"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogsRead"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.crossplane_core_passrole_arns) > 0 ? [1] : []
    content {
      sid       = "AllowPassRole"
      effect    = "Allow"
      actions   = ["iam:PassRole"]
      resources = var.crossplane_core_passrole_arns
    }
  }
}

resource "aws_iam_role" "crossplane_core" {
  count              = var.enable_irsa && var.create_crossplane_core_role ? 1 : 0
  name               = "${var.project_name}-crossplane-core"
  assume_role_policy = data.aws_iam_policy_document.crossplane_core_trust[0].json

  tags = merge(
    {
      Name      = "${var.project_name}-crossplane-core-role"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy" "crossplane_core" {
  count  = var.enable_irsa && var.create_crossplane_core_role ? 1 : 0
  name   = "${var.project_name}-crossplane-core"
  role   = aws_iam_role.crossplane_core[0].id
  policy = data.aws_iam_policy_document.crossplane_core_policy[0].json
}

data "aws_iam_policy_document" "crossplane_data_trust" {
  count = var.enable_irsa && var.create_crossplane_data_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = local.crossplane_data_subjects
    }
  }
}

data "aws_iam_policy_document" "crossplane_data_policy" {
  count = var.enable_irsa && var.create_crossplane_data_role ? 1 : 0

  statement {
    sid    = "RDSLifecycle"
    effect = "Allow"
    actions = [
      "rds:*",
      "docdb:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SecretsManagerRW"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecrets",
      "secretsmanager:PutResourcePolicy",
      "secretsmanager:PutSecretValue",
      "secretsmanager:RestoreSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UpdateSecret",
      "secretsmanager:UntagResource",
      "secretsmanager:ReplicateSecretToRegions"
    ]
    resources = [local.crossplane_secret_resource]
  }

  statement {
    sid    = "CrossplaneBuckets"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucketLocation",
      "s3:GetEncryptionConfiguration",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutBucketPolicy",
      "s3:PutEncryptionConfiguration"
    ]
    resources = [local.crossplane_s3_bucket_arn]
  }

  statement {
    sid    = "CrossplaneBucketObjects"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectTagging"
    ]
    resources = [local.crossplane_s3_objects_arn]
  }

  dynamic "statement" {
    for_each = length(var.crossplane_kms_key_arns) > 0 ? [1] : []
    content {
      sid    = "KMSUsage"
      effect = "Allow"
      actions = [
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ]
      resources = var.crossplane_kms_key_arns
    }
  }
}

resource "aws_iam_role" "crossplane_data" {
  count              = var.enable_irsa && var.create_crossplane_data_role ? 1 : 0
  name               = "${var.project_name}-crossplane-data"
  assume_role_policy = data.aws_iam_policy_document.crossplane_data_trust[0].json

  tags = merge(
    {
      Name      = "${var.project_name}-crossplane-data-role"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy" "crossplane_data" {
  count  = var.enable_irsa && var.create_crossplane_data_role ? 1 : 0
  name   = "${var.project_name}-crossplane-data"
  role   = aws_iam_role.crossplane_data[0].id
  policy = data.aws_iam_policy_document.crossplane_data_policy[0].json
}

############################################
# cert-manager DNS01 (Route53) IRSA
############################################
data "aws_iam_policy_document" "cert_manager_trust" {
  count = var.enable_irsa && var.create_cert_manager_role && local.has_route53_zones ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = [local.cert_manager_subject]
    }
  }
}

data "aws_iam_policy_document" "cert_manager_dns" {
  count = var.enable_irsa && var.create_cert_manager_role && local.has_route53_zones ? 1 : 0

  statement {
    sid       = "ChangeRecords"
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = var.route53_zone_arns
  }

  statement {
    sid    = "DescribeZones"
    effect = "Allow"
    actions = [
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:GetChange",
      "route53:ListResourceRecordSets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cert_manager_dns" {
  count       = var.enable_irsa && var.create_cert_manager_role && local.has_route53_zones ? 1 : 0
  name        = "${var.project_name}-cert-manager-dns"
  description = "Allows cert-manager to solve DNS01 challenges via Route53."
  policy      = data.aws_iam_policy_document.cert_manager_dns[0].json

  tags = merge(
    {
      Name      = "${var.project_name}-cert-manager-dns-policy"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role" "cert_manager" {
  count              = var.enable_irsa && var.create_cert_manager_role && local.has_route53_zones ? 1 : 0
  name               = "${var.project_name}-cert-manager"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_trust[0].json

  tags = merge(
    {
      Name      = "${var.project_name}-cert-manager-role"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "cert_manager_dns" {
  count      = var.enable_irsa && var.create_cert_manager_role && local.has_route53_zones ? 1 : 0
  role       = aws_iam_role.cert_manager[0].name
  policy_arn = aws_iam_policy.cert_manager_dns[0].arn
}

############################################
# external-dns (Route53) IRSA
############################################
data "aws_iam_policy_document" "external_dns_trust" {
  count = var.enable_irsa && var.create_external_dns_role && local.has_route53_zones ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = [local.external_dns_subject]
    }
  }
}

data "aws_iam_policy_document" "external_dns" {
  count = var.enable_irsa && var.create_external_dns_role && local.has_route53_zones ? 1 : 0

  statement {
    sid       = "ChangeRecords"
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = var.route53_zone_arns
  }

  statement {
    sid    = "DescribeZones"
    effect = "Allow"
    actions = [
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:GetChange",
      "route53:ListResourceRecordSets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_dns" {
  count       = var.enable_irsa && var.create_external_dns_role && local.has_route53_zones ? 1 : 0
  name        = "${var.project_name}-external-dns"
  description = "Allows external-dns to manage Route53 DNS records."
  policy      = data.aws_iam_policy_document.external_dns[0].json

  tags = merge(
    {
      Name      = "${var.project_name}-external-dns-policy"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role" "external_dns" {
  count              = var.enable_irsa && var.create_external_dns_role && local.has_route53_zones ? 1 : 0
  name               = "${var.project_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_trust[0].json

  tags = merge(
    {
      Name      = "${var.project_name}-external-dns-role"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  count      = var.enable_irsa && var.create_external_dns_role && local.has_route53_zones ? 1 : 0
  role       = aws_iam_role.external_dns[0].name
  policy_arn = aws_iam_policy.external_dns[0].arn
}
