###############
# EKS Cluster Role
###############
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(
    {
      Name      = "${var.project_name}-eks-cluster-role"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "elb_full_access" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

###############
# Node Group Role
###############
resource "aws_iam_role" "eks_node_role" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(
    {
      Name      = "${var.project_name}-eks-node-role"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "eks_worker_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

############################################
# IRSA (OIDC provider) — created AFTER EKS
############################################

locals {
  # Strip https:// for condition keys (e.g., oidc.eks.<region>.amazonaws.com/id/<id>:sub)
  oidc_hostpath = var.oidc_issuer_url != "" ? replace(var.oidc_issuer_url, "https://", "") : ""
}

# Get OIDC root CA fingerprint
data "tls_certificate" "eks_oidc" {
  count = var.enable_irsa && var.oidc_issuer_url != "" ? 1 : 0
  url   = var.oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  count = var.enable_irsa && var.oidc_issuer_url != "" ? 1 : 0

  url = var.oidc_issuer_url

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

# Trust policy bound to the ServiceAccount:
#   namespace: kube-system
#   name:      aws-load-balancer-controller
data "aws_iam_policy_document" "alb_controller_trust" {
  count = var.enable_irsa && var.create_alb_controller_role ? 1 : 0

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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

# Permissions policy (you may replace with your curated JSON if you prefer)
data "aws_iam_policy_document" "alb_controller" {
  statement {
    sid = "ControllerAccess"
    actions = [
      "elasticloadbalancing:*",
      "ec2:Describe*",
      "ec2:GetCoipPoolUsage",
      "iam:CreateServiceLinkedRole",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "waf-regional:*WebACL*",
      "wafv2:*WebACL*",
      "shield:*Protection*",
      "shield:GetSubscriptionState",
      "shield:DescribeSubscription"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "alb_controller" {
  count       = var.enable_irsa && var.create_alb_controller_role ? 1 : 0
  name        = "${var.project_name}-alb-controller"
  description = "Permissions for AWS Load Balancer Controller via IRSA"
  policy      = data.aws_iam_policy_document.alb_controller.json

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
