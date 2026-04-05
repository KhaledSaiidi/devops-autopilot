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

output "eks_node_role_name" {
  value       = module.iam.eks_node_role_name
  description = "IAM role name for the EKS worker nodes."
}

output "ebs_csi_role_arn" {
  value       = module.irsa.ebs_csi_role_arn
  description = "IAM role ARN for the EBS CSI controller (IRSA)"
}

output "alb_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller."
  value       = module.irsa.alb_controller_role_arn
}

output "karpenter_controller_role_arn" {
  description = "IRSA role ARN for the Karpenter controller."
  value       = try(module.karpenter[0].controller_role_arn, null)
}

output "crossplane_core_role_arn" {
  description = "IRSA role ARN for Crossplane networking/ingress controllers."
  value       = module.irsa.crossplane_core_role_arn
}

output "crossplane_data_role_arn" {
  description = "IRSA role ARN for Crossplane data-plane controllers."
  value       = module.irsa.crossplane_data_role_arn
}

output "external_secrets_role_arn" {
  description = "IRSA role ARN for External Secrets Operator."
  value       = module.irsa.external_secrets_role_arn
}

output "external_secrets_bootstrap_secret_arn" {
  description = "ARN of the bootstrap AWS Secrets Manager secret consumed by External Secrets."
  value       = module.external_secrets_bootstrap_secret.arn
}

output "external_secrets_bootstrap_secret_name" {
  description = "Name of the bootstrap AWS Secrets Manager secret consumed by External Secrets."
  value       = module.external_secrets_bootstrap_secret.name
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

output "oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster (used by IRSA)."
  value       = module.eks.oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider used for IRSA (if created)."
  value       = module.irsa.oidc_provider_arn
}

output "inventory_path" {
  value       = abspath(local_file.ansible_inventory.filename)
  description = "Local path to the generated kubeconfig file."
}

output "ansible_vars_path" {
  value       = abspath(local_file.ansible_vars.filename)
  description = "Absolute path to the generated Ansible vars YAML."
}

output "argocd_values_path" {
  value       = module.argocd.argocd_values_path
  description = "Absolute path to the rendered Argo CD Helm values file."
}

output "argocd_root_app_path" {
  value       = module.argocd.argocd_root_app_path
  description = "Absolute path to the rendered Argo CD root Application manifest."
}
