locals {
  artifacts_dir = "${path.root}/artifacts"
}
resource "null_resource" "artifacts_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.artifacts_dir}"
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

locals {
  detected_api_cidr   = format("%s/32", chomp(data.http.my_ip.response_body))
  effective_api_cidrs = length(var.public_access_cidrs) > 0 ? var.public_access_cidrs : [local.detected_api_cidr]
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.eks_version

  vpc_config {
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = local.effective_api_cidrs
    subnet_ids              = var.subnet_ids
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.service_ipv4_cidr
  }
  dynamic "encryption_config" {
    for_each = var.kms_key_arn != "" ? [1] : []
    content {
      resources = ["secrets"]
      provider {
        key_arn = var.kms_key_arn
      }
    }
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = merge(
    {
      Name      = "${var.cluster_name}-eks-cluster"
      ManagedBy = "Terraform"
      Component = "eks"
    },
    var.tags
  )
}

#########################
# Generate kubeconfig file (optional)
#########################

resource "local_file" "kubeconfig" {
  count           = var.generate_kubeconfig ? 1 : 0
  filename        = "${path.root}/artifacts/${aws_eks_cluster.this.name}-kubeconfig.yaml"
  file_permission = "0600"
  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name = aws_eks_cluster.this.name
    cluster_user = var.cluster_user
    endpoint     = aws_eks_cluster.this.endpoint
    ca_data      = aws_eks_cluster.this.certificate_authority[0].data
    region       = var.aws_region
  })
  depends_on = [null_resource.artifacts_dir]
}
