#!/usr/bin/env bash
set -Eeuo pipefail

# --- helpers ---
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1" >&2; exit 1; }; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$ROOT/custom-config-infrastructure.yaml}"

need yq
need jq

echo "🔧 Loading configuration from $CONFIG_FILE ..."

# Render YAML node as compact JSON (arrays/maps) for TF_* envs
json_one_line() { yq -r "$1 // []" "$2" | jq -c .; }

# Export only if non-empty/non-null (for optional strings)
export_if_set() {
  local key="$1" val="$2"
  if [[ -n "${val}" && "${val}" != "null" ]]; then
    export "${key}=${val}"
  fi
}

# -------------------------
# Project-wide
# -------------------------
TF_VAR_project_name=$(yq -r '.project.name' "$CONFIG_FILE"); export TF_VAR_project_name
TF_VAR_aws_region=$(yq -r '.project.region' "$CONFIG_FILE"); export TF_VAR_aws_region
TF_VAR_tags=$(json_one_line '.project.tags' "$CONFIG_FILE"); export TF_VAR_tags

# (Optional) backend helpers
export TF_BACKEND_BUCKET=$(yq -r '.project.bucket' "$CONFIG_FILE")
export TF_BACKEND_KEY=$(yq -r '.project.state_key' "$CONFIG_FILE")
export TF_BACKEND_DYNAMODB_TABLE=$(yq -r '.project.dynamodb_table' "$CONFIG_FILE")

# -------------------------
# VPC
# -------------------------
TF_VAR_vpc_cidr=$(yq -r '.vpc.cidr' "$CONFIG_FILE"); export TF_VAR_vpc_cidr
TF_VAR_enable_ipv6=$(yq -r '.vpc.enable_ipv6' "$CONFIG_FILE"); export TF_VAR_enable_ipv6
TF_VAR_public_subnet_cidrs=$(json_one_line '.vpc.public_subnet_cidrs' "$CONFIG_FILE"); export TF_VAR_public_subnet_cidrs
TF_VAR_private_subnet_cidrs=$(json_one_line '.vpc.private_subnet_cidrs' "$CONFIG_FILE"); export TF_VAR_private_subnet_cidrs
TF_VAR_add_k8s_tags=$(yq -r '.vpc.add_k8s_tags' "$CONFIG_FILE"); export TF_VAR_add_k8s_tags

# -------------------------
# IAM
# -------------------------
TF_VAR_enable_irsa=$(yq -r '.iam.enable_irsa' "$CONFIG_FILE"); export TF_VAR_enable_irsa
TF_VAR_create_alb_controller_role=$(yq -r '.iam.create_alb_controller_role' "$CONFIG_FILE"); export TF_VAR_create_alb_controller_role
TF_VAR_lbc_policy_url=$(yq -r '.iam.lbc_policy_url' "$CONFIG_FILE"); export TF_VAR_lbc_policy_url
TF_VAR_create_ebs_csi_role=$(yq -r '.iam.create_ebs_csi_role' "$CONFIG_FILE"); export TF_VAR_create_ebs_csi_role
TF_VAR_ebs_csi_namespace=$(yq -r '.iam.ebs_csi_namespace' "$CONFIG_FILE"); export TF_VAR_ebs_csi_namespace
TF_VAR_ebs_csi_service_account=$(yq -r '.iam.ebs_csi_service_account' "$CONFIG_FILE"); export TF_VAR_ebs_csi_service_account
TF_VAR_create_cluster_autoscaler_role=$(yq -r '.iam.create_cluster_autoscaler_role' "$CONFIG_FILE"); export TF_VAR_create_cluster_autoscaler_role
TF_VAR_cluster_autoscaler_namespace=$(yq -r '.iam.cluster_autoscaler_namespace' "$CONFIG_FILE"); export TF_VAR_cluster_autoscaler_namespace
TF_VAR_cluster_autoscaler_service_account=$(yq -r '.iam.cluster_autoscaler_service_account' "$CONFIG_FILE"); export TF_VAR_cluster_autoscaler_service_account

# -------------------------
# EKS
# -------------------------
TF_VAR_cluster_name=$(yq -r '.eks.cluster_name' "$CONFIG_FILE"); export TF_VAR_cluster_name
TF_VAR_cluster_user=$(yq -r '.eks.cluster_user' "$CONFIG_FILE"); export TF_VAR_cluster_user
TF_VAR_eks_version=$(yq -r '.eks.version' "$CONFIG_FILE"); export TF_VAR_eks_version
TF_VAR_generate_kubeconfig=$(yq -r '.eks.generate_kubeconfig' "$CONFIG_FILE"); export TF_VAR_generate_kubeconfig
TF_VAR_endpoint_private_access=$(yq -r '.eks.endpoint_private_access' "$CONFIG_FILE"); export TF_VAR_endpoint_private_access
TF_VAR_endpoint_public_access=$(yq -r '.eks.endpoint_public_access' "$CONFIG_FILE"); export TF_VAR_endpoint_public_access
TF_VAR_public_access_cidrs=$(json_one_line '.eks.public_access_cidrs' "$CONFIG_FILE"); export TF_VAR_public_access_cidrs
TF_VAR_service_ipv4_cidr=$(yq -r '.eks.service_ipv4_cidr' "$CONFIG_FILE"); export TF_VAR_service_ipv4_cidr
TF_VAR_enabled_cluster_log_types=$(json_one_line '.eks.enabled_cluster_log_types' "$CONFIG_FILE"); export TF_VAR_enabled_cluster_log_types

# -------------------------
# Nodegroup (incl. SSH + Bastion)
# -------------------------
TF_VAR_desired_size=$(yq -r '.nodegroup.desired_size' "$CONFIG_FILE"); export TF_VAR_desired_size
TF_VAR_min_size=$(yq -r '.nodegroup.min_size' "$CONFIG_FILE"); export TF_VAR_min_size
TF_VAR_max_size=$(yq -r '.nodegroup.max_size' "$CONFIG_FILE"); export TF_VAR_max_size
TF_VAR_ami_type=$(yq -r '.nodegroup.ami_type' "$CONFIG_FILE"); export TF_VAR_ami_type
TF_VAR_capacity_type=$(yq -r '.nodegroup.capacity_type' "$CONFIG_FILE"); export TF_VAR_capacity_type
TF_VAR_disk_size=$(yq -r '.nodegroup.disk_size' "$CONFIG_FILE"); export TF_VAR_disk_size
TF_VAR_instance_types=$(json_one_line '.nodegroup.instance_types' "$CONFIG_FILE"); export TF_VAR_instance_types
TF_VAR_force_update_version=$(yq -r '.nodegroup.force_update_version' "$CONFIG_FILE"); export TF_VAR_force_update_version
TF_VAR_extra_labels=$(json_one_line '.nodegroup.extra_labels' "$CONFIG_FILE"); export TF_VAR_extra_labels

# SSH & Bastion (from nodegroup section)
TF_VAR_create_ssh_key=$(yq -r '.nodegroup.create_ssh_key' "$CONFIG_FILE"); export TF_VAR_create_ssh_key
TF_VAR_enable_ssh=$(yq -r '.nodegroup.enable_ssh' "$CONFIG_FILE"); export TF_VAR_enable_ssh

SSH_KEY_NAME_VAL=$(yq -r '.nodegroup.ssh_key_name' "$CONFIG_FILE")
export_if_set "TF_VAR_ssh_key_name" "${SSH_KEY_NAME_VAL}"

TF_VAR_bastion_instance_type=$(yq -r '.nodegroup.bastion_instance_type' "$CONFIG_FILE"); export TF_VAR_bastion_instance_type

BASTION_AMI_ID_VAL=$(yq -r '.nodegroup.bastion_ami_id' "$CONFIG_FILE")
export_if_set "TF_VAR_bastion_ami_id" "${BASTION_AMI_ID_VAL}"

TF_VAR_bastion_admin_cidrs=$(json_one_line '.nodegroup.bastion_admin_cidrs' "$CONFIG_FILE"); export TF_VAR_bastion_admin_cidrs

# -------------------------
# Ansible
# -------------------------
TF_VAR_kubectl_version=$(yq -r '.ansible.kubectl_version' "$CONFIG_FILE"); export TF_VAR_kubectl_version
TF_VAR_helm_version=$(yq -r '.ansible.helm_version' "$CONFIG_FILE"); export TF_VAR_helm_version
ANSIBLE_VERBOSITY=$(yq -r '.ansible.verbosity' "$CONFIG_FILE"); export ANSIBLE_VERBOSITY
ANSIBLE_DRY_RUN=$(yq -r '.ansible.dry_run' "$CONFIG_FILE"); export ANSIBLE_DRY_RUN
ANSIBLE_ENABLED=$(yq -r '.ansible.ansible_enabled' "$CONFIG_FILE"); export ANSIBLE_ENABLED
export_if_set "TF_VAR_argocd_namespace" "$(yq -r '.ansible.argocd_namespace' "$CONFIG_FILE")"
export_if_set "TF_VAR_argocd_create_namespace" "$(yq -r '.ansible.argocd_create_namespace' "$CONFIG_FILE")"
export_if_set "TF_VAR_argocd_server_service_type" "$(yq -r '.ansible.argocd_server_service_type' "$CONFIG_FILE")"
export_if_set "TF_VAR_argocd_enable_envsubst_plugin" "$(yq -r '.ansible.argocd_enable_envsubst_plugin' "$CONFIG_FILE")"
export_if_set "TF_VAR_argocd_enable_lovely_plugin" "$(yq -r '.ansible.argocd_enable_lovely_plugin' "$CONFIG_FILE")"
export_if_set "TF_VAR_argocd_wait_timeout" "$(yq -r '.ansible.argocd_wait_timeout' "$CONFIG_FILE")"
export_if_set "TF_VAR_argocd_wait_interval" "$(yq -r '.ansible.argocd_wait_interval' "$CONFIG_FILE")"

echo "✅ Environment loaded successfully."
