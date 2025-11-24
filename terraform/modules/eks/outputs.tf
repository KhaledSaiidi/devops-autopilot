output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS Kubernetes API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file (for Ansible use)."
  value       = var.generate_kubeconfig ? abspath(local_file.kubeconfig[0].filename) : null
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster (used by IRSA)."
  value       = try(aws_eks_cluster.this.identity[0].oidc[0].issuer, null)
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group ID for control plane to node communication."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
