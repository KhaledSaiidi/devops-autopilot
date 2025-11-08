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
  oidc_hostpath = var.oidc_issuer_url != "" ? replace(var.oidc_issuer_url, "https://", "") : ""
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
