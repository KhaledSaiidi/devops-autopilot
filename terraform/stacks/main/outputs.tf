############################################
# VPC Outputs
############################################
output "vpc_id" {
  description = "VPC ID used by all components."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

############################################
# IAM / SSH Key Outputs
############################################
output "eks_cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane."
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_role_arn" {
  description = "IAM role ARN for the EKS worker nodes."
  value       = module.iam.eks_node_role_arn
}

output "ssh_private_key_path" {
  description = "Path to the generated SSH private key (if created)."
  value       = module.iam.ssh_private_key_path
}

############################################
# EKS Outputs
############################################
output "eks_cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint URL."
  value       = module.eks.cluster_endpoint
}

output "kubeconfig_path" {
  description = "Local path to the generated kubeconfig file."
  value       = module.eks.kubeconfig_path
}
