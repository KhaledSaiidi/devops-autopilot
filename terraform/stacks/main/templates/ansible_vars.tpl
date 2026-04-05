project_name: "${project_name}"
aws_region: "${aws_region}"

cluster:
  name: "${cluster_name}"
  endpoint: "${cluster_endpoint}"
  oidc_issuer_url: "${oidc_issuer_url}"
  ssh_private_key:
      local_path: "${ssh_private_key_path}"
  kubeconfig:
    local_path: "${kubeconfig_path}"

networking:
  vpc_id: "${vpc_id}"
  public_subnet_ids:
%{ for id in public_subnet_ids }
    - "${id}"
%{ endfor }
  private_subnet_ids:
%{ for id in private_subnet_ids }
    - "${id}"
%{ endfor }

irsa:
  ebs_csi_role_arn: "${ebs_csi_role_arn}"
  ebs_csi_namespace: "${ebs_csi_namespace}"
  ebs_csi_service_account: "${ebs_csi_service_account}"
  alb_controller_role_arn: "${alb_role_arn}"
  alb_controller_namespace: "${alb_controller_namespace}"
  alb_controller_service_account: "${alb_controller_service_account}"
  crossplane_namespace: "${crossplane_namespace}"
  crossplane_core_role_arn: "${crossplane_core_role_arn}"
  crossplane_core_service_accounts:
%{ for sa in crossplane_core_service_accounts }
    - "${sa}"
%{ endfor }
  crossplane_data_role_arn: "${crossplane_data_role_arn}"
  crossplane_data_service_accounts:
%{ for sa in crossplane_data_service_accounts }
    - "${sa}"
%{ endfor }
  cert_manager_role_arn: "${cert_manager_role_arn}"
  cert_manager_namespace: "${cert_manager_namespace}"
  cert_manager_service_account: "${cert_manager_service_account}"
  external_dns_role_arn: "${external_dns_role_arn}"
  external_dns_namespace: "${external_dns_namespace}"
  external_dns_service_account: "${external_dns_service_account}"
  external_secrets_role_arn: "${external_secrets_role_arn}"
  external_secrets_namespace: "${external_secrets_namespace}"
  external_secrets_service_account: "${external_secrets_service_account}"

nodegroup:
  desired_size: ${nodegroup_desired_size}
  min_size: ${nodegroup_min_size}
  max_size: ${nodegroup_max_size}

iam_roles:
  eks_cluster_role_arn: "${eks_cluster_role_arn}"
  eks_node_role_arn: "${eks_node_role_arn}"

tooling:
  kubectl_version: "${kubectl_version}"
  helm_version: "${helm_version}"

bastion:
  public_ip: "${bastion_public_ip}"

artifacts:
  argocd_values_local_path: "${argocd_values_local_path}"
  gitops_root_app_manifest_local_path: "${gitops_root_app_local_path}"

argocd_namespace: "${argocd_namespace}"
argocd_create_namespace: ${argocd_create_namespace}
argocd_server_service_type: "${argocd_server_service_type}"
argocd_wait_timeout: ${argocd_wait_timeout}
argocd_wait_interval: ${argocd_wait_interval}
argocd_reconciliation_timeout: ${argocd_reconciliation_timeout}
argocd_exec_timeout: ${argocd_exec_timeout}

gateway_api:
  namespace: "${gateway_api.namespace}"
  gateway_class_name: "${gateway_api.gateway_class_name}"
  controller:
    default_target_type: "${gateway_api.controller.default_target_type}"
    enable_alb_gateway: ${gateway_api.controller.enable_alb_gateway}
    enable_nlb_gateway: ${gateway_api.controller.enable_nlb_gateway}
    enable_shield_addon: ${gateway_api.controller.enable_shield_addon}
    log_level: "${gateway_api.controller.log_level}"
  load_balancer:
    ip_address_type: "${gateway_api.load_balancer.ip_address_type}"
    external_scheme: "${gateway_api.load_balancer.external_scheme}"
    internal_scheme: "${gateway_api.load_balancer.internal_scheme}"
    deletion_protection_enabled: ${gateway_api.load_balancer.deletion_protection_enabled}
    idle_timeout_seconds: ${gateway_api.load_balancer.idle_timeout_seconds}
    external_shield_enabled: ${gateway_api.load_balancer.external_shield_enabled}
    internal_shield_enabled: ${gateway_api.load_balancer.internal_shield_enabled}
  external_gateway:
    enabled: ${gateway_api.external_gateway.enabled}
    name: "${gateway_api.external_gateway.name}"
    http_port: ${gateway_api.external_gateway.http_port}
    https_port: ${gateway_api.external_gateway.https_port}
    hostname: "${gateway_api.external_gateway.hostname}"
    allowed_routes_from: "${gateway_api.external_gateway.allowed_routes_from}"
    tls_certificate_arn: "${gateway_api.external_gateway.tls_certificate_arn}"
  internal_gateway:
    enabled: ${gateway_api.internal_gateway.enabled}
    name: "${gateway_api.internal_gateway.name}"
    http_port: ${gateway_api.internal_gateway.http_port}
    https_port: ${gateway_api.internal_gateway.https_port}
    hostname: "${gateway_api.internal_gateway.hostname}"
    allowed_routes_from: "${gateway_api.internal_gateway.allowed_routes_from}"
    tls_certificate_arn: "${gateway_api.internal_gateway.tls_certificate_arn}"
dns:
  base_domain: "${dns.base_domain}"
  root_domain: "${dns.root_domain}"
  external_label: "${dns.external_label}"
  internal_label: "${dns.internal_label}"
  hosted_zone_id: "${dns.hosted_zone_id}"
  hosted_zone_arn: "${dns.hosted_zone_arn}"
  external_fqdn: "${dns.external_fqdn}"
  internal_fqdn: "${dns.internal_fqdn}"
  external_wildcard_domain: "${dns.external_wildcard_domain}"
  internal_wildcard_domain: "${dns.internal_wildcard_domain}"
cert_manager:
  email: "${cert_manager.email}"
  server: "${cert_manager.server}"
external_dns:
  txt_owner_id: "${external_dns.txt_owner_id}"
  txt_prefix: "${external_dns.txt_prefix}"
  policy: "${external_dns.policy}"
  log_level: "${external_dns.log_level}"
  interval: "${external_dns.interval}"
  trigger_loop_on_event: ${external_dns.trigger_loop_on_event}
