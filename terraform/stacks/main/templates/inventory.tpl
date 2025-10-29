[bastion]
bastion ansible_host=${bastion_public_ip} ansible_user=${ansible_user} ansible_ssh_private_key_file=${ssh_private_key_path} ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[all:vars]
project_name=${project_name}

aws_region=${aws_region}
vpc_id=${vpc_id}
public_subnet_ids=${public_subnet_ids}
private_subnet_ids=${private_subnet_ids}

cluster_name=${cluster_name}
cluster_endpoint=${cluster_endpoint}
kubeconfig_local_path=${kubeconfig_local_path}
kubeconfig_remote_path=${kubeconfig_remote_path}
oidc_issuer_url=${oidc_issuer_url}

EBS_CSI_ROLE_ARN=${ebs_csi_role_arn}
CA_ROLE_ARN=${ca_role_arn}
ALB_ROLE_ARN=${alb_role_arn}

kubectl_version=${kubectl_version}
helm_version=${helm_version}