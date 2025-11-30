locals {
  artifacts_dir         = "${path.root}/artifacts"
  gateway_api_namespace = var.gateway_api_namespace != "" ? var.gateway_api_namespace : var.alb_controller_namespace

  dns_base_domain       = trimspace(var.dns_base_domain)
  dns_env_subdomain     = var.project_name
  dns_internal_label    = "internal"
  dns_external_label    = var.dns_external_label != "" ? var.dns_external_label : "platform"
  dns_root_domain       = local.dns_base_domain != "" ? (local.dns_env_subdomain != "" ? "${local.dns_env_subdomain}.${local.dns_base_domain}" : local.dns_base_domain) : ""
  dns_external_fqdn     = local.dns_base_domain != "" ? "${local.dns_external_label}.${local.dns_root_domain}" : ""
  dns_internal_fqdn     = local.dns_base_domain != "" ? "${local.dns_internal_label}.${local.dns_root_domain}" : ""
  dns_external_wildcard = local.dns_external_fqdn != "" ? "*.${local.dns_external_fqdn}" : ""
  dns_internal_wildcard = local.dns_internal_fqdn != "" ? "*.${local.dns_internal_fqdn}" : ""
  dns_hosted_zone_id    = var.dns_hosted_zone_id != "" ? var.dns_hosted_zone_id : try(data.aws_route53_zone.primary[0].zone_id, "")
  dns_hosted_zone_arn   = local.dns_hosted_zone_id != "" ? "arn:aws:route53:::hostedzone/${local.dns_hosted_zone_id}" : ""
  dns_external_hostname = local.dns_external_wildcard
  dns_internal_hostname = local.dns_internal_wildcard
  # Allow DNS-integrated components (external-dns, cert-manager) to manage delegated zones created later.
  route53_zone_arns = local.dns_hosted_zone_arn != "" ? ["arn:aws:route53:::hostedzone/*"] : []

  external_gateway_hostname = var.gateway_api_external_gateway.hostname != "" ? var.gateway_api_external_gateway.hostname : local.dns_external_hostname
  internal_gateway_hostname = var.gateway_api_internal_gateway.hostname != "" ? var.gateway_api_internal_gateway.hostname : local.dns_internal_hostname
  external_gateway_tls_arn  = var.gateway_api_external_gateway.tls_certificate_arn
  internal_gateway_tls_arn  = var.gateway_api_internal_gateway.tls_certificate_arn
}

data "aws_route53_zone" "primary" {
  count        = local.dns_base_domain != "" && var.dns_hosted_zone_id == "" ? 1 : 0
  name         = "${local.dns_base_domain}."
  private_zone = false
}

resource "null_resource" "artifacts_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.artifacts_dir}"
  }
}

############################################
# 1) Networking
############################################
module "vpc" {
  source               = "../../modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  enable_ipv6          = var.enable_ipv6
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  add_k8s_tags         = var.add_k8s_tags
  cluster_name         = var.cluster_name
  tags                 = var.tags
}

module "nat_gw" {
  source             = "../../modules/nat-gw"
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
}

############################################
# 2) IAM (roles only)
############################################
module "iam" {
  source       = "../../modules/iam"
  project_name = var.project_name
  tags         = var.tags
}

############################################
# 3) KMS (grant cluster role in key policy)
############################################
module "kms" {
  source           = "../../modules/kms"
  project_name     = var.project_name
  cluster_name     = var.cluster_name
  cluster_role_arn = module.iam.eks_cluster_role_arn
  tags             = var.tags
}

############################################
# 4) EKS (enable secrets encryption)
############################################
module "eks" {
  source                    = "../../modules/eks"
  cluster_name              = var.cluster_name
  cluster_role_arn          = module.iam.eks_cluster_role_arn
  subnet_ids                = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  eks_version               = var.eks_version
  aws_region                = var.aws_region
  generate_kubeconfig       = var.generate_kubeconfig
  cluster_user              = var.cluster_user
  endpoint_private_access   = var.endpoint_private_access
  endpoint_public_access    = var.endpoint_public_access
  public_access_cidrs       = var.public_access_cidrs
  service_ipv4_cidr         = var.service_ipv4_cidr
  enabled_cluster_log_types = var.enabled_cluster_log_types
  kms_key_arn               = module.kms.key_arn
  tags                      = var.tags
}

############################################
# 5) Nodegroup (private subnets)
############################################
module "nodegroup" {
  source                        = "../../modules/nodegroup"
  project_name                  = var.project_name
  cluster_name                  = module.eks.cluster_name
  cluster_sg_id                 = module.eks.cluster_security_group_id
  node_group_role_arn           = module.iam.eks_node_role_arn
  private_subnet_ids            = module.vpc.private_subnet_ids
  bastion_instance_profile_name = module.iam.bastion_instance_profile_name

  # SSH control
  enable_ssh     = var.enable_ssh
  create_ssh_key = var.create_ssh_key
  ssh_key_name   = var.ssh_key_name

  # Bastion
  enable_bastion        = true
  public_subnet_ids     = module.vpc.public_subnet_ids
  bastion_admin_cidrs   = var.bastion_admin_cidrs
  bastion_instance_type = var.bastion_instance_type
  bastion_ami_id        = var.bastion_ami_id
  desired_size          = var.desired_size
  min_size              = var.min_size
  max_size              = var.max_size
  ami_type              = var.ami_type
  capacity_type         = var.capacity_type
  disk_size             = var.disk_size
  instance_types        = var.instance_types
  eks_version           = var.eks_version
  force_update_version  = var.force_update_version
  extra_labels          = var.extra_labels
  tags                  = var.tags
}

data "aws_caller_identity" "current" {}

# Manage aws-auth ConfigMap via kubectl server-side apply to adopt existing object.
resource "null_resource" "aws_auth" {
  depends_on = [
    module.eks,
    module.nodegroup
  ]

  triggers = {
    node_role    = module.iam.eks_node_role_arn
    bastion_role = module.iam.bastion_role_arn
    kubeconfig   = module.eks.kubeconfig_path
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -euo pipefail
      cat <<'EOF' | kubectl --kubeconfig="${module.eks.kubeconfig_path}" apply --server-side --force-conflicts -f -
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: aws-auth
        namespace: kube-system
      data:
        mapRoles: |
          - rolearn: ${module.iam.eks_node_role_arn}
            username: system:node:{{EC2PrivateDNSName}}
            groups:
              - system:bootstrappers
              - system:nodes
          - rolearn: ${module.iam.bastion_role_arn}
            username: bastion
            groups:
              - system:masters
      EOF
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# Allow bastion SG to reach the EKS control plane (private endpoint) on 443.
resource "aws_security_group_rule" "cluster_api_from_bastion" {
  description              = "Allow bastion to reach EKS API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = module.nodegroup.bastion_security_group_id
}

############################################
# 6) IRSA roles (after cluster exists)
############################################
module "irsa" {
  source                             = "../../modules/irsa"
  project_name                       = var.project_name
  tags                               = var.tags
  enable_irsa                        = var.enable_irsa
  oidc_issuer_url                    = module.eks.oidc_issuer_url
  create_alb_controller_role         = var.create_alb_controller_role
  alb_controller_namespace           = var.alb_controller_namespace
  alb_controller_service_account     = var.alb_controller_service_account
  lbc_policy_url                     = var.lbc_policy_url
  create_cluster_autoscaler_role     = var.create_cluster_autoscaler_role
  cluster_autoscaler_namespace       = var.cluster_autoscaler_namespace
  cluster_autoscaler_service_account = var.cluster_autoscaler_service_account
  create_ebs_csi_role                = var.create_ebs_csi_role
  ebs_csi_namespace                  = var.ebs_csi_namespace
  ebs_csi_service_account            = var.ebs_csi_service_account
  create_crossplane_core_role        = var.create_crossplane_core_role
  create_crossplane_data_role        = var.create_crossplane_data_role
  crossplane_namespace               = var.crossplane_namespace
  crossplane_core_service_accounts   = var.crossplane_core_service_accounts
  crossplane_data_service_accounts   = var.crossplane_data_service_accounts
  crossplane_core_passrole_arns      = var.crossplane_core_passrole_arns
  crossplane_kms_key_arns            = length(var.crossplane_kms_key_arns) > 0 ? var.crossplane_kms_key_arns : [module.kms.key_arn]
  create_cert_manager_role           = var.create_cert_manager_role
  cert_manager_namespace             = var.cert_manager_namespace
  cert_manager_service_account       = var.cert_manager_service_account
  create_external_dns_role           = var.create_external_dns_role
  external_dns_namespace             = var.external_dns_namespace
  external_dns_service_account       = var.external_dns_service_account
  route53_zone_arns                  = local.route53_zone_arns
}

#########################
# Generate inventory file
#########################

resource "local_file" "ansible_inventory" {
  filename        = "${path.root}/artifacts/${var.project_name}-inventory.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.tpl", {
    bastion_public_ip    = module.nodegroup.bastion_public_ip
    ansible_user         = "ec2-user"
    ssh_private_key_path = module.nodegroup.ssh_private_key_path
  })

  depends_on = [null_resource.artifacts_dir]
}

resource "local_file" "ansible_vars" {
  filename        = "${path.root}/artifacts/${var.project_name}-ansible-vars.yaml"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/ansible_vars.tpl", {
    # Identity / meta
    project_name = var.project_name
    aws_region   = var.aws_region

    # Cluster
    cluster_name         = module.eks.cluster_name
    cluster_endpoint     = module.eks.cluster_endpoint
    oidc_issuer_url      = module.eks.oidc_issuer_url
    kubeconfig_path      = module.eks.kubeconfig_path
    ssh_private_key_path = module.nodegroup.ssh_private_key_path

    # Networking
    vpc_id             = module.vpc.vpc_id
    public_subnet_ids  = module.vpc.public_subnet_ids
    private_subnet_ids = module.vpc.private_subnet_ids

    # IRSA / roles
    ebs_csi_role_arn                   = module.irsa.ebs_csi_role_arn
    ebs_csi_namespace                  = var.ebs_csi_namespace
    ebs_csi_service_account            = var.ebs_csi_service_account
    ca_role_arn                        = module.irsa.cluster_autoscaler_role_arn
    alb_role_arn                       = module.irsa.alb_controller_role_arn
    alb_controller_namespace           = var.alb_controller_namespace
    alb_controller_service_account     = var.alb_controller_service_account
    cluster_autoscaler_namespace       = var.cluster_autoscaler_namespace
    cluster_autoscaler_service_account = var.cluster_autoscaler_service_account
    eks_cluster_role_arn               = module.iam.eks_cluster_role_arn
    eks_node_role_arn                  = module.iam.eks_node_role_arn
    crossplane_core_role_arn           = module.irsa.crossplane_core_role_arn
    crossplane_data_role_arn           = module.irsa.crossplane_data_role_arn
    crossplane_namespace               = var.crossplane_namespace
    crossplane_core_service_accounts   = var.crossplane_core_service_accounts
    crossplane_data_service_accounts   = var.crossplane_data_service_accounts
    cert_manager_role_arn              = module.irsa.cert_manager_role_arn
    cert_manager_namespace             = var.cert_manager_namespace
    cert_manager_service_account       = var.cert_manager_service_account
    external_dns_role_arn              = module.irsa.external_dns_role_arn
    external_dns_namespace             = var.external_dns_namespace
    external_dns_service_account       = var.external_dns_service_account

    # Tooling versions (optional)
    kubectl_version = var.kubectl_version
    helm_version    = var.helm_version

    # Bastion convenience (read-only info for play logic)
    bastion_public_ip      = module.nodegroup.bastion_public_ip
    kubeconfig_remote_path = "/home/ec2-user/.kube/config"
    nodegroup_desired_size = var.desired_size
    nodegroup_min_size     = var.min_size
    nodegroup_max_size     = var.max_size

    # Argo CD overrides
    argocd_namespace              = var.argocd_namespace
    argocd_create_namespace       = var.argocd_create_namespace
    argocd_server_service_type    = var.argocd_server_service_type
    argocd_enable_envsubst_plugin = var.argocd_enable_envsubst_plugin
    argocd_enable_lovely_plugin   = var.argocd_enable_lovely_plugin
    argocd_wait_timeout           = var.argocd_wait_timeout
    argocd_wait_interval          = var.argocd_wait_interval
    argocd_reconciliation_timeout = var.argocd_reconciliation_timeout
    argocd_exec_timeout           = var.argocd_exec_timeout

    gateway_api = {
      namespace          = local.gateway_api_namespace
      gateway_class_name = var.gateway_api_gateway_class_name
      controller         = var.gateway_api_controller
      load_balancer      = var.gateway_api_load_balancer
      external_gateway = merge(
        var.gateway_api_external_gateway,
        {
          hostname = local.external_gateway_hostname
        }
      )
      internal_gateway = merge(
        var.gateway_api_internal_gateway,
        {
          hostname = local.internal_gateway_hostname
        }
      )
    }

    dns = {
      base_domain              = local.dns_base_domain
      root_domain              = local.dns_root_domain
      external_label           = local.dns_external_label
      internal_label           = local.dns_internal_label
      hosted_zone_id           = local.dns_hosted_zone_id
      hosted_zone_arn          = local.dns_hosted_zone_arn
      external_fqdn            = local.dns_external_fqdn
      internal_fqdn            = local.dns_internal_fqdn
      external_wildcard_domain = local.dns_external_wildcard
      internal_wildcard_domain = local.dns_internal_wildcard
    }

    cert_manager = {
      email  = var.cert_manager_email
      server = var.cert_manager_server
    }

    external_dns = {
      txt_owner_id          = var.external_dns_txt_owner_id != "" ? var.external_dns_txt_owner_id : var.project_name
      txt_prefix            = var.external_dns_txt_prefix
      policy                = var.external_dns_policy
      log_level             = var.external_dns_log_level
      interval              = var.external_dns_interval
      trigger_loop_on_event = var.external_dns_trigger_loop_on_event
    }
  })

  depends_on = [null_resource.artifacts_dir]
}

#########################
# Keep GitOps namespaces in sync with config
#########################
