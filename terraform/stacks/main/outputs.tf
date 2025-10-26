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
# IAM Outputs
############################################
output "eks_cluster_role_arn" {
  value       = module.iam.eks_cluster_role_arn
  description = "IAM role ARN for the EKS control plane."
}
output "eks_node_role_arn" {
  value       = module.iam.eks_node_role_arn
  description = "IAM role ARN for the EKS worker nodes."
}

############################################
# Nodegroup / Bastion Outputs
############################################
output "bastion_public_ip" {
  value       = module.nodegroup.bastion_public_ip
  description = "Public IP of the bastion host (if enabled)."
}

output "ssh_private_key_path" {
  value       = module.nodegroup.ssh_private_key_path
  description = "Path to the generated SSH private key (if created)."
}

############################################
# EKS Outputs
############################################
output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "The name of the EKS cluster."
}
output "eks_cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS cluster API endpoint URL."
}
output "kubeconfig_path" {
  value       = module.eks.kubeconfig_path
  description = "Local path to the generated kubeconfig file."
}
