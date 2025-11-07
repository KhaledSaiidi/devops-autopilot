locals {
  artifacts_dir = "${path.root}/artifacts"
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
  source               = "../../modules/nat-gw"
  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  public_subnet_ids    = module.vpc.public_subnet_ids
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

############################################
# 2) IAM (roles only)
############################################
module "iam" {
  source                             = "../../modules/iam"
  project_name                       = var.project_name
  tags                               = var.tags
  enable_irsa                        = var.enable_irsa
  oidc_issuer_url                    = module.eks.oidc_issuer_url
  create_alb_controller_role         = var.create_alb_controller_role
  lbc_policy_url                     = var.lbc_policy_url
  create_cluster_autoscaler_role     = var.create_cluster_autoscaler_role
  cluster_autoscaler_namespace       = var.cluster_autoscaler_namespace
  cluster_autoscaler_service_account = var.cluster_autoscaler_service_account
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
  source              = "../../modules/nodegroup"
  project_name        = var.project_name
  cluster_name        = module.eks.cluster_name
  node_group_role_arn = module.iam.eks_node_role_arn
  private_subnet_ids  = module.vpc.private_subnet_ids

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
    ebs_csi_role_arn = module.iam.ebs_csi_role_arn
    ca_role_arn      = module.iam.cluster_autoscaler_role_arn
    alb_role_arn     = module.iam.alb_controller_role_arn
    eks_cluster_role_arn = module.iam.eks_cluster_role_arn
    eks_node_role_arn    = module.iam.eks_node_role_arn

    # Tooling versions (optional)
    kubectl_version = var.kubectl_version
    helm_version    = var.helm_version

    # Bastion convenience (read-only info for play logic)
    bastion_public_ip      = module.nodegroup.bastion_public_ip
    kubeconfig_remote_path = "/home/ec2-user/.kube/config"

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
  })

  depends_on = [null_resource.artifacts_dir]
}
