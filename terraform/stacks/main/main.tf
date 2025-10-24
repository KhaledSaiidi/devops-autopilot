# create VPC
module "VPC" {
  source           = "../../modules/vpc"
  project_name = var.project_name
  vpc_cidr = var.vpc_cidr
  enable_ipv6 = var.enable_ipv6
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  add_k8s_tags = var.add_k8s_tags
  cluster_name = var.cluster_name
  tags = var.tags
}

# create NAT GATEWAY
module "Nat-GW" {
  source           = "../../modules/nat-gw"
  vpc_id = var.vpc_id
  igw_id = var.igw_id
  public_subnet_ids = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids
}

# create IAM
module "IAM" {
  source           = "../../modules/iam"
  PROJECT_NAME     = var.PROJECT_NAME
}

# create EKS Cluster
module "EKS" {
  source               = "../../modules/eks"
  PROJECT_NAME         = var.PROJECT_NAME
  EKS_CLUSTER_ROLE_ARN = module.IAM.EKS_CLUSTER_ROLE_ARN
  PUB_SUB1_ID        = module.VPC.PUB_SUB1_ID
  PUB_SUB2_ID        = module.VPC.PUB_SUB2_ID
  PRI_SUB3_ID        = module.VPC.PRI_SUB3_ID
  PRI_SUB4_ID        = module.VPC.PRI_SUB4_ID
}

# create Node Group
module "NodeGroup" {
  source               = "../../modules/nodegroup"
  eks_cluster_name = var.eks_cluster_name
  node_group_role_arn = var.node_group_role_arn
  private_subnet_ids = var.private_subnet_ids
  desired_size = var.desired_size
  max_size = var.max_size
  min_size = var.min_size
  ami_type = var.ami_type
  capacity_type = var.capacity_type
  disk_size = var.disk_size
  instance_types = var.instance_types
  eks_version = var.eks_version
  force_update_version = var.force_update_version
  extra_labels = var.extra_labels
  tags = var.tags
}