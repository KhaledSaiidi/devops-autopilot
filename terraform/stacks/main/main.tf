############################################
# 1️⃣ VPC
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

############################################
# 2️⃣ NAT (1 per AZ)
############################################
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
# 3️⃣ IAM (cluster role & node role, + optional SSH key)
############################################
module "iam" {
  source         = "../../modules/iam"
  project_name   = var.project_name
  create_ssh_key = var.create_ssh_key
  tags           = var.tags

  # Your IAM module expects these to attach the inline KMS policy
  kms_key_arn  = "" # empty for now; IAM will still create roles
  cluster_name = var.cluster_name
}

############################################
# 4️⃣ KMS (requires the cluster role ARN)
############################################
module "kms" {
  source           = "../../modules/kms"
  project_name     = var.project_name
  cluster_name     = var.cluster_name
  cluster_role_arn = module.iam.eks_cluster_role_arn # <— REQUIRED by your KMS module
  tags             = var.tags
}

# (Optional) Let IAM know the concrete key ARN now (so your inline policy uses the exact ARN).
# If your IAM module's kms policy uses var.kms_key_arn (not the key policy), you can update it via a separate call:
module "iam_kms_bind" {
  source         = "../../modules/iam"
  project_name   = var.project_name
  create_ssh_key = false # don't recreate keypair
  tags           = var.tags

  kms_key_arn  = module.kms.key_arn
  cluster_name = var.cluster_name

  # If your IAM module creates resources unconditionally, skip this block
  # and keep only the first "iam" module. Otherwise, you can merge this logic
  # back into a single IAM module by making the inline kms policy conditional.
}

############################################
# 5️⃣ EKS (uses the KMS key for secrets encryption)
############################################
module "eks" {
  source = "../../modules/eks"

  cluster_name        = var.cluster_name
  cluster_role_arn    = module.iam.eks_cluster_role_arn
  subnet_ids          = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  eks_version         = var.eks_version
  aws_region          = var.aws_region
  generate_kubeconfig = var.generate_kubeconfig
  cluster_user        = var.cluster_user

  endpoint_private_access   = var.endpoint_private_access
  endpoint_public_access    = var.endpoint_public_access
  public_access_cidrs       = var.public_access_cidrs
  service_ipv4_cidr         = var.service_ipv4_cidr
  enabled_cluster_log_types = var.enabled_cluster_log_types

  kms_key_arn = module.kms.key_arn # <— enables the dynamic encryption_config in your EKS module

  tags = var.tags
}

############################################
# 6️⃣ Node Group (private subnets)
############################################
module "nodegroup" {
  source = "../../modules/nodegroup"

  cluster_name        = module.eks.cluster_name
  node_group_role_arn = module.iam.eks_node_role_arn
  private_subnet_ids  = module.vpc.private_subnet_ids

  enable_ssh   = var.create_ssh_key
  ssh_key_name = module.iam.ssh_key_name

  desired_size         = var.desired_size
  min_size             = var.min_size
  max_size             = var.max_size
  ami_type             = var.ami_type
  capacity_type        = var.capacity_type
  disk_size            = var.disk_size
  instance_types       = var.instance_types
  eks_version          = var.eks_version
  force_update_version = var.force_update_version
  extra_labels         = var.extra_labels
  tags                 = var.tags
}
