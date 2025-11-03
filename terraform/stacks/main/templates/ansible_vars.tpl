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
  cluster_autoscaler_role_arn: "${ca_role_arn}"
  alb_controller_role_arn: "${alb_role_arn}"

tooling:
  kubectl_version: "${kubectl_version}"
  helm_version: "${helm_version}"

bastion:
  public_ip: "${bastion_public_ip}"

argocd_namespace: "${argocd_namespace}"
argocd_create_namespace: ${argocd_create_namespace}
argocd_server_service_type: "${argocd_server_service_type}"
argocd_enable_envsubst_plugin: ${argocd_enable_envsubst_plugin}
argocd_enable_lovely_plugin: ${argocd_enable_lovely_plugin}
argocd_wait_timeout: ${argocd_wait_timeout}
argocd_wait_interval: ${argocd_wait_interval}
