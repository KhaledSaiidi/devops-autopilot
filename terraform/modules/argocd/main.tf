locals {
  effective_argocd_namespace      = trimspace(var.argocd_namespace) != "" ? trimspace(var.argocd_namespace) : "argocd"
  effective_argocd_service_type   = trimspace(var.argocd_server_service_type) != "" ? trimspace(var.argocd_server_service_type) : "LoadBalancer"
  effective_argocd_exec_timeout   = trimspace(var.argocd_exec_timeout) != "" ? trimspace(var.argocd_exec_timeout) : "90s"
  argocd_repo_server_timeout_secs = try(tonumber(regexall("[0-9]+", local.effective_argocd_exec_timeout)[0]), 90)
  karpenter_ami_family = can(regex("^AL2023", var.nodegroup.ami_type)) ? "AL2023" : (
    can(regex("^BOTTLEROCKET", var.nodegroup.ami_type)) ? "Bottlerocket" : "AL2"
  )

  argocd_values_artifact_path   = abspath("${var.artifacts_dir}/${var.project_name}-argocd-values.yaml")
  argocd_root_app_artifact_path = abspath("${var.artifacts_dir}/${var.project_name}-argocd-root-app.yaml")
}

resource "local_file" "argocd_values" {
  filename        = local.argocd_values_artifact_path
  file_permission = "0644"

  content = templatefile("${path.module}/templates/argocd_values.tpl", {
    argocd_namespace                = local.effective_argocd_namespace
    argocd_server_service_type      = local.effective_argocd_service_type
    argocd_reconciliation_timeout   = var.argocd_reconciliation_timeout
    argocd_exec_timeout             = local.effective_argocd_exec_timeout
    argocd_repo_server_timeout_secs = local.argocd_repo_server_timeout_secs
    argocd_lovely_plugin_name       = "argocd-lovely-plugin-v1.0"
    argocd_lovely_plugin_image      = "ghcr.io/akuity/argocd-lovely-plugin:v0.18.0"
  })
}

resource "local_file" "argocd_root_app" {
  filename        = local.argocd_root_app_artifact_path
  file_permission = "0644"

  content = templatefile("${path.module}/templates/argocd_root_app.tpl", {
    argocd_namespace                              = local.effective_argocd_namespace
    gitops_root_app_name                          = "app-of-apps"
    gitops_root_app_project                       = "default"
    gitops_root_app_repo_url                      = var.gitops_root_app_repo_url
    gitops_root_app_target_revision               = var.gitops_root_app_target_revision
    gitops_root_app_path                          = var.gitops_root_app_path
    gitops_root_app_destination_server            = "https://kubernetes.default.svc"
    gitops_root_app_destination_namespace         = local.effective_argocd_namespace
    project_name                                  = var.project_name
    aws_region                                    = var.aws_region
    cluster_name                                  = var.cluster.name
    cluster_endpoint                              = var.cluster.endpoint
    oidc_issuer_url                               = var.cluster.oidc_issuer_url
    kubeconfig_path                               = var.cluster.kubeconfig_path
    ssh_private_key_path                          = var.cluster.ssh_private_key_path
    vpc_id                                        = var.networking.vpc_id
    public_subnet_ids                             = join(",", var.networking.public_subnet_ids)
    private_subnet_ids                            = join(",", var.networking.private_subnet_ids)
    ebs_csi_role_arn                              = var.irsa.ebs_csi_role_arn
    ebs_csi_namespace                             = var.irsa.ebs_csi_namespace
    ebs_csi_service_account                       = var.irsa.ebs_csi_service_account
    alb_controller_role_arn                       = var.irsa.alb_controller_role_arn
    alb_controller_namespace                      = var.irsa.alb_controller_namespace
    alb_controller_service_account                = var.irsa.alb_controller_service_account
    eks_cluster_role_arn                          = var.iam_roles.eks_cluster_role_arn
    eks_node_role_arn                             = var.iam_roles.eks_node_role_arn
    eks_node_role_name                            = var.iam_roles.eks_node_role_name
    bastion_public_ip                             = var.bastion_public_ip
    crossplane_namespace                          = var.irsa.crossplane_namespace
    crossplane_core_role_arn                      = var.irsa.crossplane_core_role_arn
    crossplane_core_service_account               = try(var.irsa.crossplane_core_service_accounts[0], "")
    crossplane_data_role_arn                      = var.irsa.crossplane_data_role_arn
    crossplane_data_service_account               = try(var.irsa.crossplane_data_service_accounts[0], "")
    cert_manager_namespace                        = var.irsa.cert_manager_namespace
    cert_manager_service_account                  = var.irsa.cert_manager_service_account
    cert_manager_role_arn                         = var.irsa.cert_manager_role_arn
    external_dns_namespace                        = var.irsa.external_dns_namespace
    external_dns_service_account                  = var.irsa.external_dns_service_account
    external_dns_role_arn                         = var.irsa.external_dns_role_arn
    external_secrets_namespace                    = var.irsa.external_secrets_namespace
    external_secrets_service_account              = var.irsa.external_secrets_service_account
    external_secrets_role_arn                     = var.irsa.external_secrets_role_arn
    external_secrets_bootstrap_source_secret_name = var.external_secrets_bootstrap.source_secret_name
    external_secrets_bootstrap_secret_store_name  = var.external_secrets_bootstrap.secret_store_name
    external_secrets_bootstrap_refresh_interval   = var.external_secrets_bootstrap.refresh_interval
    external_secrets_bootstrap_target_namespace   = var.external_secrets_bootstrap.target_namespace
    external_secrets_bootstrap_target_secret_name = var.external_secrets_bootstrap.target_secret_name
    dns_base_domain                               = var.dns.base_domain
    dns_root_domain                               = var.dns.root_domain
    dns_external_label                            = var.dns.external_label
    dns_internal_label                            = var.dns.internal_label
    dns_hosted_zone_id                            = var.dns.hosted_zone_id
    dns_external_fqdn                             = var.dns.external_fqdn
    dns_internal_fqdn                             = var.dns.internal_fqdn
    dns_external_wildcard                         = var.dns.external_wildcard_domain
    dns_internal_wildcard                         = var.dns.internal_wildcard_domain
    cert_manager_email                            = var.cert_manager.email
    cert_manager_server                           = var.cert_manager.server
    external_dns_txt_owner_id                     = var.external_dns.txt_owner_id
    external_dns_txt_prefix                       = var.external_dns.txt_prefix
    external_dns_policy                           = var.external_dns.policy
    external_dns_log_level                        = var.external_dns.log_level
    external_dns_interval                         = var.external_dns.interval
    external_dns_trigger_loop_on_event            = tostring(var.external_dns.trigger_loop_on_event)
    gateway_api_namespace                         = var.gateway_api.namespace
    gateway_api_gateway_class_name                = var.gateway_api.gateway_class_name
    gateway_api_controller_target_type            = var.gateway_api.controller.default_target_type
    gateway_api_controller_enable_alb_gateway     = tostring(var.gateway_api.controller.enable_alb_gateway)
    gateway_api_controller_enable_nlb_gateway     = tostring(var.gateway_api.controller.enable_nlb_gateway)
    gateway_api_controller_enable_shield_addon    = tostring(var.gateway_api.controller.enable_shield_addon)
    gateway_api_controller_log_level              = var.gateway_api.controller.log_level
    gateway_api_load_balancer_ip_address_type     = var.gateway_api.load_balancer.ip_address_type
    gateway_api_load_balancer_external_scheme     = var.gateway_api.load_balancer.external_scheme
    gateway_api_load_balancer_internal_scheme     = var.gateway_api.load_balancer.internal_scheme
    gateway_api_load_balancer_deletion_protection = tostring(var.gateway_api.load_balancer.deletion_protection_enabled)
    gateway_api_load_balancer_idle_timeout        = tostring(var.gateway_api.load_balancer.idle_timeout_seconds)
    gateway_api_load_balancer_external_shield     = tostring(var.gateway_api.load_balancer.external_shield_enabled)
    gateway_api_load_balancer_internal_shield     = tostring(var.gateway_api.load_balancer.internal_shield_enabled)
    gateway_api_external_name                     = var.gateway_api.external_gateway.name
    gateway_api_external_config_name              = "${var.gateway_api.external_gateway.name}-config"
    gateway_api_external_http_port                = tostring(var.gateway_api.external_gateway.http_port)
    gateway_api_external_https_port               = tostring(var.gateway_api.external_gateway.https_port)
    gateway_api_external_hostname                 = var.gateway_api.external_gateway.hostname
    gateway_api_external_allowed_routes           = var.gateway_api.external_gateway.allowed_routes_from
    gateway_api_internal_name                     = var.gateway_api.internal_gateway.name
    gateway_api_internal_config_name              = "${var.gateway_api.internal_gateway.name}-config"
    gateway_api_internal_http_port                = tostring(var.gateway_api.internal_gateway.http_port)
    gateway_api_internal_https_port               = tostring(var.gateway_api.internal_gateway.https_port)
    gateway_api_internal_hostname                 = var.gateway_api.internal_gateway.hostname
    gateway_api_internal_allowed_routes           = var.gateway_api.internal_gateway.allowed_routes_from
    nodegroup_desired_size                        = tostring(var.nodegroup.desired_size)
    nodegroup_min_size                            = tostring(var.nodegroup.min_size)
    nodegroup_max_size                            = tostring(var.nodegroup.max_size)
    nodegroup_instance_types_json                 = jsonencode(var.nodegroup.instance_types)
    nodegroup_capacity_types_json                 = jsonencode([lower(replace(var.nodegroup.capacity_type, "_", "-"))])
    nodegroup_disk_size                           = tostring(var.nodegroup.disk_size)
    karpenter_ami_family                          = local.karpenter_ami_family
    karpenter_namespace                           = var.karpenter.namespace
    karpenter_service_account                     = var.karpenter.service_account
    karpenter_role_arn                            = var.karpenter.controller_role_arn
    karpenter_interruption_queue_name             = var.karpenter.interruption_queue_name
  })
}
