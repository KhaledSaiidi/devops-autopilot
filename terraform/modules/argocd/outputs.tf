output "argocd_values_path" {
  description = "Absolute path to the rendered Argo CD Helm values file."
  value       = abspath(local_file.argocd_values.filename)
}

output "argocd_root_app_path" {
  description = "Absolute path to the rendered Argo CD root Application manifest."
  value       = abspath(local_file.argocd_root_app.filename)
}

output "argocd_namespace" {
  description = "Effective Argo CD namespace."
  value       = local.effective_argocd_namespace
}

output "argocd_server_service_type" {
  description = "Effective Argo CD server service type."
  value       = local.effective_argocd_service_type
}

output "argocd_exec_timeout" {
  description = "Effective Argo CD exec timeout."
  value       = local.effective_argocd_exec_timeout
}
