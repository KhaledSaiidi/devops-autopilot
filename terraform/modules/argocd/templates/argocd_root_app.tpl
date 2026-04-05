apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${gitops_root_app_name}
  namespace: ${argocd_namespace}
  labels:
    app.kubernetes.io/managed-by: terraform
    app.kubernetes.io/part-of: gitops-bootstrap
spec:
  project: ${gitops_root_app_project}
  source:
    repoURL: ${gitops_root_app_repo_url}
    targetRevision: ${gitops_root_app_target_revision}
    path: ${gitops_root_app_path}
    plugin:
      env:
        - name: PROJECT_NAME
          value: "${project_name}"
        - name: AWS_REGION
          value: "${aws_region}"
        - name: CLUSTER_NAME
          value: "${cluster_name}"
        - name: CLUSTER_ENDPOINT
          value: "${cluster_endpoint}"
        - name: OIDC_ISSUER_URL
          value: "${oidc_issuer_url}"
        - name: KUBECONFIG_PATH
          value: "${kubeconfig_path}"
        - name: SSH_PRIVATE_KEY_PATH
          value: "${ssh_private_key_path}"
        - name: VPC_ID
          value: "${vpc_id}"
        - name: PUBLIC_SUBNET_IDS
          value: "${public_subnet_ids}"
        - name: PRIVATE_SUBNET_IDS
          value: "${private_subnet_ids}"
        - name: EBS_CSI_ROLE_ARN
          value: "${ebs_csi_role_arn}"
        - name: EBS_CSI_NAMESPACE
          value: "${ebs_csi_namespace}"
        - name: EBS_CSI_SERVICE_ACCOUNT
          value: "${ebs_csi_service_account}"
        - name: ALB_CONTROLLER_ROLE_ARN
          value: "${alb_controller_role_arn}"
        - name: ALB_CONTROLLER_NAMESPACE
          value: "${alb_controller_namespace}"
        - name: ALB_CONTROLLER_SERVICE_ACCOUNT
          value: "${alb_controller_service_account}"
        - name: EKS_CLUSTER_ROLE_ARN
          value: "${eks_cluster_role_arn}"
        - name: EKS_NODE_ROLE_ARN
          value: "${eks_node_role_arn}"
        - name: EKS_NODE_ROLE_NAME
          value: "${eks_node_role_name}"
        - name: BASTION_PUBLIC_IP
          value: "${bastion_public_ip}"
        - name: ARGOCD_NAMESPACE
          value: "${argocd_namespace}"
        - name: ROOT_APP_NAME
          value: "${gitops_root_app_name}"
        - name: CROSSPLANE_NAMESPACE
          value: "${crossplane_namespace}"
        - name: CROSSPLANE_CORE_ROLE_ARN
          value: "${crossplane_core_role_arn}"
        - name: CROSSPLANE_CORE_SERVICE_ACCOUNT
          value: "${crossplane_core_service_account}"
        - name: CROSSPLANE_DATA_ROLE_ARN
          value: "${crossplane_data_role_arn}"
        - name: CROSSPLANE_DATA_SERVICE_ACCOUNT
          value: "${crossplane_data_service_account}"
        - name: CERT_MANAGER_NAMESPACE
          value: "${cert_manager_namespace}"
        - name: CERT_MANAGER_SERVICE_ACCOUNT
          value: "${cert_manager_service_account}"
        - name: CERT_MANAGER_ROLE_ARN
          value: "${cert_manager_role_arn}"
        - name: EXTERNAL_DNS_NAMESPACE
          value: "${external_dns_namespace}"
        - name: EXTERNAL_DNS_SERVICE_ACCOUNT
          value: "${external_dns_service_account}"
        - name: EXTERNAL_DNS_ROLE_ARN
          value: "${external_dns_role_arn}"
        - name: EXTERNAL_SECRETS_NAMESPACE
          value: "${external_secrets_namespace}"
        - name: EXTERNAL_SECRETS_SERVICE_ACCOUNT
          value: "${external_secrets_service_account}"
        - name: EXTERNAL_SECRETS_ROLE_ARN
          value: "${external_secrets_role_arn}"
        - name: EXTERNAL_SECRETS_BOOTSTRAP_SOURCE_SECRET_NAME
          value: "${external_secrets_bootstrap_source_secret_name}"
        - name: EXTERNAL_SECRETS_BOOTSTRAP_SECRET_STORE_NAME
          value: "${external_secrets_bootstrap_secret_store_name}"
        - name: EXTERNAL_SECRETS_BOOTSTRAP_REFRESH_INTERVAL
          value: "${external_secrets_bootstrap_refresh_interval}"
        - name: EXTERNAL_SECRETS_BOOTSTRAP_TARGET_NAMESPACE
          value: "${external_secrets_bootstrap_target_namespace}"
        - name: EXTERNAL_SECRETS_BOOTSTRAP_TARGET_SECRET_NAME
          value: "${external_secrets_bootstrap_target_secret_name}"
        - name: DNS_BASE_DOMAIN
          value: "${dns_base_domain}"
        - name: DNS_ROOT_DOMAIN
          value: "${dns_root_domain}"
        - name: DNS_EXTERNAL_LABEL
          value: "${dns_external_label}"
        - name: DNS_INTERNAL_LABEL
          value: "${dns_internal_label}"
        - name: DNS_HOSTED_ZONE_ID
          value: "${dns_hosted_zone_id}"
        - name: DNS_EXTERNAL_FQDN
          value: "${dns_external_fqdn}"
        - name: DNS_INTERNAL_FQDN
          value: "${dns_internal_fqdn}"
        - name: DNS_EXTERNAL_WILDCARD
          value: "${dns_external_wildcard}"
        - name: DNS_INTERNAL_WILDCARD
          value: "${dns_internal_wildcard}"
        - name: CERT_MANAGER_EMAIL
          value: "${cert_manager_email}"
        - name: CERT_MANAGER_SERVER
          value: "${cert_manager_server}"
        - name: EXTERNAL_DNS_TXT_OWNER_ID
          value: "${external_dns_txt_owner_id}"
        - name: EXTERNAL_DNS_TXT_PREFIX
          value: "${external_dns_txt_prefix}"
        - name: EXTERNAL_DNS_POLICY
          value: "${external_dns_policy}"
        - name: EXTERNAL_DNS_LOG_LEVEL
          value: "${external_dns_log_level}"
        - name: EXTERNAL_DNS_INTERVAL
          value: "${external_dns_interval}"
        - name: EXTERNAL_DNS_TRIGGER_LOOP_ON_EVENT
          value: "${external_dns_trigger_loop_on_event}"
        - name: GATEWAY_API_NAMESPACE
          value: "${gateway_api_namespace}"
        - name: GATEWAY_API_GATEWAY_CLASS_NAME
          value: "${gateway_api_gateway_class_name}"
        - name: GATEWAY_API_CONTROLLER_TARGET_TYPE
          value: "${gateway_api_controller_target_type}"
        - name: GATEWAY_API_CONTROLLER_ENABLE_ALB_GATEWAY
          value: "${gateway_api_controller_enable_alb_gateway}"
        - name: GATEWAY_API_CONTROLLER_ENABLE_NLB_GATEWAY
          value: "${gateway_api_controller_enable_nlb_gateway}"
        - name: GATEWAY_API_CONTROLLER_ENABLE_SHIELD_ADDON
          value: "${gateway_api_controller_enable_shield_addon}"
        - name: GATEWAY_API_CONTROLLER_LOG_LEVEL
          value: "${gateway_api_controller_log_level}"
        - name: GATEWAY_API_LOAD_BALANCER_IP_ADDRESS_TYPE
          value: "${gateway_api_load_balancer_ip_address_type}"
        - name: GATEWAY_API_LOAD_BALANCER_EXTERNAL_SCHEME
          value: "${gateway_api_load_balancer_external_scheme}"
        - name: GATEWAY_API_LOAD_BALANCER_INTERNAL_SCHEME
          value: "${gateway_api_load_balancer_internal_scheme}"
        - name: GATEWAY_API_LOAD_BALANCER_DELETION_PROTECTION
          value: "${gateway_api_load_balancer_deletion_protection}"
        - name: GATEWAY_API_LOAD_BALANCER_IDLE_TIMEOUT
          value: "${gateway_api_load_balancer_idle_timeout}"
        - name: GATEWAY_API_LOAD_BALANCER_EXTERNAL_SHIELD
          value: "${gateway_api_load_balancer_external_shield}"
        - name: GATEWAY_API_LOAD_BALANCER_INTERNAL_SHIELD
          value: "${gateway_api_load_balancer_internal_shield}"
        - name: GATEWAY_API_EXTERNAL_NAME
          value: "${gateway_api_external_name}"
        - name: GATEWAY_API_EXTERNAL_CONFIG_NAME
          value: "${gateway_api_external_config_name}"
        - name: GATEWAY_API_EXTERNAL_HTTP_PORT
          value: "${gateway_api_external_http_port}"
        - name: GATEWAY_API_EXTERNAL_HTTPS_PORT
          value: "${gateway_api_external_https_port}"
        - name: GATEWAY_API_EXTERNAL_HOSTNAME
          value: "${gateway_api_external_hostname}"
        - name: GATEWAY_API_EXTERNAL_ALLOWED_ROUTES
          value: "${gateway_api_external_allowed_routes}"
        - name: GATEWAY_API_INTERNAL_NAME
          value: "${gateway_api_internal_name}"
        - name: GATEWAY_API_INTERNAL_CONFIG_NAME
          value: "${gateway_api_internal_config_name}"
        - name: GATEWAY_API_INTERNAL_HTTP_PORT
          value: "${gateway_api_internal_http_port}"
        - name: GATEWAY_API_INTERNAL_HTTPS_PORT
          value: "${gateway_api_internal_https_port}"
        - name: GATEWAY_API_INTERNAL_HOSTNAME
          value: "${gateway_api_internal_hostname}"
        - name: GATEWAY_API_INTERNAL_ALLOWED_ROUTES
          value: "${gateway_api_internal_allowed_routes}"
        - name: NODEGROUP_DESIRED_SIZE
          value: "${nodegroup_desired_size}"
        - name: NODEGROUP_MIN_SIZE
          value: "${nodegroup_min_size}"
        - name: NODEGROUP_MAX_SIZE
          value: "${nodegroup_max_size}"
        - name: NODEGROUP_INSTANCE_TYPES_JSON
          value: '${nodegroup_instance_types_json}'
        - name: NODEGROUP_CAPACITY_TYPES_JSON
          value: '${nodegroup_capacity_types_json}'
        - name: NODEGROUP_DISK_SIZE
          value: "${nodegroup_disk_size}"
        - name: KARPENTER_AMI_FAMILY
          value: "${karpenter_ami_family}"
        - name: KARPENTER_NAMESPACE
          value: "${karpenter_namespace}"
        - name: KARPENTER_SERVICE_ACCOUNT
          value: "${karpenter_service_account}"
        - name: KARPENTER_ROLE_ARN
          value: "${karpenter_role_arn}"
        - name: KARPENTER_INTERRUPTION_QUEUE_NAME
          value: "${karpenter_interruption_queue_name}"
  destination:
    server: ${gitops_root_app_destination_server}
    namespace: ${gitops_root_app_destination_namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
