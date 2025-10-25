#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="${1:-$(cd "$(dirname "$0")/.." && pwd)/custom-config.yaml"}"

if ! command -v yq &>/dev/null; then
  echo "❌ 'yq' is required but not installed. https://github.com/mikefarah/yq"
  return 1 2>/dev/null || exit 1
fi

# Warn if not sourced (so exports persist)
(return 0 2>/dev/null) || {
  echo "⚠️  Please 'source scripts/load-config.sh [custom-config.yaml]' so exports persist."
}

echo "🔧 Loading configuration from $CONFIG_FILE ..."

# Project-wide
export TF_VAR_project_name="$(yq -r '.project.name' "$CONFIG_FILE")"
export TF_VAR_aws_region="$(yq -r '.project.region' "$CONFIG_FILE")"

# VPC
export TF_VAR_vpc_cidr="$(yq -r '.vpc.cidr' "$CONFIG_FILE")"
export TF_VAR_enable_ipv6="$(yq -r '.vpc.enable_ipv6' "$CONFIG_FILE")"
export TF_VAR_public_subnet_cidrs="$(yq -o=json '.vpc.public_subnet_cidrs' "$CONFIG_FILE")"
export TF_VAR_private_subnet_cidrs="$(yq -o=json '.vpc.private_subnet_cidrs' "$CONFIG_FILE")"
export TF_VAR_add_k8s_tags="$(yq -r '.vpc.add_k8s_tags' "$CONFIG_FILE")"

# EKS
export TF_VAR_cluster_name="$(yq -r '.eks.cluster_name' "$CONFIG_FILE")"
export TF_VAR_cluster_user="$(yq -r '.eks.cluster_user' "$CONFIG_FILE")"
export TF_VAR_eks_version="$(yq -r '.eks.version' "$CONFIG_FILE")"
export TF_VAR_generate_kubeconfig="$(yq -r '.eks.generate_kubeconfig' "$CONFIG_FILE")"
export TF_VAR_endpoint_private_access="$(yq -r '.eks.endpoint_private_access' "$CONFIG_FILE")"
export TF_VAR_endpoint_public_access="$(yq -r '.eks.endpoint_public_access' "$CONFIG_FILE")"
export TF_VAR_public_access_cidrs="$(yq -o=json '.eks.public_access_cidrs' "$CONFIG_FILE")"
export TF_VAR_service_ipv4_cidr="$(yq -r '.eks.service_ipv4_cidr' "$CONFIG_FILE")"

# Nodegroup
export TF_VAR_desired_size="$(yq -r '.nodegroup.desired_size' "$CONFIG_FILE")"
export TF_VAR_min_size="$(yq -r '.nodegroup.min_size' "$CONFIG_FILE")"
export TF_VAR_max_size="$(yq -r '.nodegroup.max_size' "$CONFIG_FILE")"
export TF_VAR_ami_type="$(yq -r '.nodegroup.ami_type' "$CONFIG_FILE")"
export TF_VAR_capacity_type="$(yq -r '.nodegroup.capacity_type' "$CONFIG_FILE")"
export TF_VAR_disk_size="$(yq -r '.nodegroup.disk_size' "$CONFIG_FILE")"
export TF_VAR_instance_types="$(yq -o=json '.nodegroup.instance_types' "$CONFIG_FILE")"

# IAM
export TF_VAR_create_ssh_key="$(yq -r '.iam.create_ssh_key' "$CONFIG_FILE")"

# Tags (map as JSON)
export TF_VAR_tags="$(yq -o=json '.project.tags' "$CONFIG_FILE")"

echo "✅ Environment loaded successfully."
