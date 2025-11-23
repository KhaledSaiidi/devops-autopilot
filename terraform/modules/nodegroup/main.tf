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

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

locals {
  detected_admin_cidr   = format("%s/32", chomp(data.http.my_ip.response_body))
  effective_admin_cidrs = length(var.bastion_admin_cidrs) > 0 ? var.bastion_admin_cidrs : [local.detected_admin_cidr]
}

resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.workers.id
    version = "$Latest"
  }

  # --- SSH remote access ---
  dynamic "remote_access" {
    for_each = (var.enable_ssh && local.effective_ssh_key_name != null && var.enable_bastion) ? [1] : []
    content {
      ec2_ssh_key               = local.effective_ssh_key_name
      source_security_group_ids = [aws_security_group.bastion_sg[0].id]
    }
  }

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  ami_type             = var.ami_type
  capacity_type        = var.capacity_type
  disk_size            = var.disk_size
  instance_types       = var.instance_types
  version              = var.eks_version
  force_update_version = var.force_update_version

  labels = merge(
    {
      role = "${var.cluster_name}-node-group-role"
      name = "${var.cluster_name}-node-group"
    },
    var.extra_labels
  )

  tags = merge(
    {
      Name                                            = "${var.cluster_name}-node-group"
      ManagedBy                                       = "Terraform"
      Component                                       = "eks"
      "k8s.io/cluster-autoscaler/enabled"             = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    },
    var.tags
  )

  # ---- Guardrails ----
  lifecycle {
    precondition {
      condition     = !(var.enable_ssh && !var.enable_bastion)
      error_message = "enable_ssh=true requires enable_bastion=true to avoid exposing SSH."
    }
    precondition {
      condition     = (!var.enable_ssh) || (local.effective_ssh_key_name != null && local.effective_ssh_key_name != "")
      error_message = "SSH is enabled but no EC2 key pair name is available. Either enable create_ssh_key or provide ssh_key_name."
    }
    precondition {
      condition     = length(var.private_subnet_ids) > 0
      error_message = "private_subnet_ids must contain at least one subnet."
    }
    ignore_changes = [scaling_config[0].desired_size]
  }
}

#########################
# SSH Key Pair
#########################

resource "tls_private_key" "eks_key" {
  count     = var.create_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "eks_keypair" {
  count      = var.create_ssh_key ? 1 : 0
  key_name   = "${var.project_name}-eks-key"
  public_key = tls_private_key.eks_key[0].public_key_openssh

  tags = merge(
    {
      Name      = "${var.project_name}-eks-keypair"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "local_file" "private_key" {
  count           = var.create_ssh_key ? 1 : 0
  content         = tls_private_key.eks_key[0].private_key_pem
  filename        = "${path.root}/artifacts/${var.project_name}-eks.pem"
  file_permission = "0600"
  depends_on      = [null_resource.artifacts_dir]
}

locals {
  effective_ssh_key_name = var.create_ssh_key ? aws_key_pair.eks_keypair[0].key_name : var.ssh_key_name
}

resource "aws_launch_template" "workers" {
  name_prefix = "${var.cluster_name}-workers-"

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name = "${var.cluster_name}-worker"
      },
      var.tags
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Allow SSH *to bastion* only from approved CIDRs
resource "aws_security_group" "bastion_sg" {
  count  = var.enable_bastion ? 1 : 0
  name   = "${var.project_name}-bastion-sg"
  vpc_id = data.aws_vpc.selected.id

  ingress {
    description = "SSH from admin CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.effective_admin_cidrs
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({ Name = "${var.project_name}-bastion-sg" }, var.tags)
  lifecycle {
    precondition {
      condition     = length(local.effective_admin_cidrs) > 0
      error_message = "bastion_sg requires at least one admin CIDR (auto-detect should provide caller /32)."
    }
  }
}
data "aws_subnet" "pub0" {
  id = var.public_subnet_ids[0]
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.pub0.vpc_id
}

resource "aws_instance" "bastion" {
  count                       = var.enable_bastion ? 1 : 0
  ami                         = var.bastion_ami_id != "" ? var.bastion_ami_id : data.aws_ssm_parameter.al2023.value
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  associate_public_ip_address = true
  key_name                    = local.effective_ssh_key_name

  vpc_security_group_ids = [aws_security_group.bastion_sg[0].id]

  tags = merge(
    {
      Name      = "${var.project_name}-bastion"
      ManagedBy = "Terraform"
      Component = "bastion"
    },
    var.tags
  )
  lifecycle {
    precondition {
      condition     = (!var.enable_bastion) || length(var.public_subnet_ids) > 0
      error_message = "enable_bastion=true requires at least one public subnet ID."
    }
    precondition {
      condition     = (!var.enable_bastion) || (local.effective_ssh_key_name != null && local.effective_ssh_key_name != "")
      error_message = "enable_bastion=true requires a valid EC2 key pair (create_ssh_key=true or provide ssh_key_name)."
    }
  }
}
