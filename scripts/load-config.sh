#!/usr/bin/env bash
set -Eeuo pipefail

# --- helpers ---
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1" >&2; exit 1; }; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$ROOT/custom-config.yaml}"

need yq
need jq

echo "🔧 Loading configuration from $CONFIG_FILE ..."

# Export JSON on one line by piping YAML->jq compact (-c)
json_one_line() { yq -r "$1" "$2" | jq -c .; }

# -------------------------
# Project-wide
# -------------------------
TF_VAR_project_name=$(yq -r '.project.name' "$CONFIG_FILE"); export TF_VAR_project_name
TF_VAR_aws_region=$(yq -r '.project.region' "$CONFIG_FILE"); export TF_VAR_aws_region

# -------------------------
# VPC
# -------------------------
TF_VAR_vpc_cidr=$(yq -r '.vpc.cidr' "$CONFIG_FILE"); export TF_VAR_vpc_cidr
TF_VAR_enable_ipv6=$(yq -r '.vpc.enable_ipv6' "$CONFIG_FILE"); export TF_VAR_enable_ipv6
TF_VAR_public_subnet_cidrs=$(json_one_line '.vpc.public_subnet_cidrs' "$CONFIG_FILE"); export TF_VAR_public_subnet_cidrs
TF_VAR_private_subnet_cidrs=$(json_one_line '.vpc.private_subnet_cidrs' "$CONFIG_FILE"); export TF_VAR_private_subnet_cidrs
TF_VAR_add_k8s_tags=$(yq -r '.vpc.add_k8s_tags' "$CONFIG_FILE"); export TF_VAR_add_k8s_tags

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

# -------------------------
# Nodegroup
# -------------------------
TF_VAR_desired_size=$(yq -r '.nodegroup.desired_size' "$CONFIG_FILE"); export TF_VAR_desired_size
TF_VAR_min_size=$(yq -r '.nodegroup.min_size' "$CONFIG_FILE"); export TF_VAR_min_size
TF_VAR_max_size=$(yq -r '.nodegroup.max_size' "$CONFIG_FILE"); export TF_VAR_max_size
TF_VAR_ami_type=$(yq -r '.nodegroup.ami_type' "$CONFIG_FILE"); export TF_VAR_ami_type
TF_VAR_capacity_type=$(yq -r '.nodegroup.capacity_type' "$CONFIG_FILE"); export TF_VAR_capacity_type
TF_VAR_disk_size=$(yq -r '.nodegroup.disk_size' "$CONFIG_FILE"); export TF_VAR_disk_size
TF_VAR_instance_types=$(json_one_line '.nodegroup.instance_types' "$CONFIG_FILE"); export TF_VAR_instance_types

# -------------------------
# IAM
# -------------------------
TF_VAR_create_ssh_key=$(yq -r '.iam.create_ssh_key' "$CONFIG_FILE"); export TF_VAR_create_ssh_key

# -------------------------
# Tags (map as JSON)
# -------------------------
TF_VAR_tags=$(json_one_line '.project.tags' "$CONFIG_FILE"); export TF_VAR_tags

echo "✅ Environment loaded successfully."
