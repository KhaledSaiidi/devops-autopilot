#!/usr/bin/env bash
set -Eeuo pipefail

# --- helpers ---
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1" >&2; exit 1; }; }

read_config_json() {
  local expr="$1"
  yq "${YQ_JSON_ARGS[@]}" "${expr} // null" "$CONFIG_FILE"
}

format_env_value() {
  local json="$1"
  local type
  type=$(jq -r 'type' <<<"$json")
  if [[ "$type" == "array" || "$type" == "object" ]]; then
    jq -c '.' <<<"$json"
  else
    jq -r '.' <<<"$json"
  fi
}

export_tf_var() {
  local var_name="$1"
  local expr="$2"
  local allow_empty="${3:-true}"

  local raw_json value type
  raw_json=$(read_config_json "$expr")
  [[ "$raw_json" == "null" ]] && return

  type=$(jq -r 'type' <<<"$raw_json")
  value=$(format_env_value "$raw_json")

  if [[ "$type" == "string" && "$allow_empty" != "true" && -z "$value" ]]; then
    return
  fi

  export "TF_VAR_${var_name}=${value}"
}

export_plain_env() {
  local env_name="$1"
  local expr="$2"
  local raw_json value

  raw_json=$(read_config_json "$expr")
  [[ "$raw_json" == "null" ]] && return

  value=$(format_env_value "$raw_json")
  export "${env_name}=${value}"
}

section_keys() {
  local section="$1"
  yq -r ".${section} | keys | .[]" "$CONFIG_FILE" 2>/dev/null || true
}

load_section() {
  local section="$1"
  local prefix="$2"
  local overrides_ref="$3"
  local skip_ref="$4"
  local optional_ref="$5"

  local -n overrides="$overrides_ref"
  local -n skip="$skip_ref"
  local -n optional="$optional_ref"

  mapfile -t keys < <(section_keys "$section")
  for key in "${keys[@]}"; do
    [[ -n "${skip[$key]:-}" ]] && continue
    local var_name="${overrides[$key]:-${prefix}${key}}"
    local allow_empty="${optional[$key]:-true}"
    export_tf_var "$var_name" ".${section}.${key}" "$allow_empty"
  done
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$ROOT/custom-config-infrastructure.yaml}"

need yq
need jq

YQ_JSON_ARGS=(-o=json)
if ! yq "${YQ_JSON_ARGS[@]}" '.' "$CONFIG_FILE" >/dev/null 2>&1; then
  YQ_JSON_ARGS=()
fi

echo "🔧 Loading configuration from $CONFIG_FILE ..."

# -----------------------------------------------------------------------------
# Terraform variables (data-driven)
# -----------------------------------------------------------------------------
declare -A EMPTY_MAP=()

declare -A PROJECT_OVERRIDES=(
  [name]="project_name"
  [region]="aws_region"
  [tags]="tags"
)
declare -A PROJECT_SKIP=(
  [bucket]=1
  [state_key]=1
  [dynamodb_table]=1
)

load_section "project" "project_" PROJECT_OVERRIDES PROJECT_SKIP EMPTY_MAP

declare -A VPC_OVERRIDES=([cidr]="vpc_cidr")
load_section "vpc" "" VPC_OVERRIDES EMPTY_MAP EMPTY_MAP
load_section "iam" "" EMPTY_MAP EMPTY_MAP EMPTY_MAP

declare -A EKS_OVERRIDES=([version]="eks_version")
load_section "eks" "" EKS_OVERRIDES EMPTY_MAP EMPTY_MAP

declare -A NODEGROUP_OPTIONAL=(
  [ssh_key_name]="false"
  [bastion_ami_id]="false"
)
load_section "nodegroup" "" EMPTY_MAP EMPTY_MAP NODEGROUP_OPTIONAL

load_section "gateway_api" "gateway_api_" EMPTY_MAP EMPTY_MAP EMPTY_MAP
load_section "dns" "dns_" EMPTY_MAP EMPTY_MAP EMPTY_MAP
if [[ -z "${TF_VAR_dns_hosted_zone_id:-}" ]]; then
  echo "❌ dns.hosted_zone_id is required but missing in ${CONFIG_FILE}" >&2
  exit 1
fi
load_section "cert_manager" "cert_manager_" EMPTY_MAP EMPTY_MAP EMPTY_MAP
load_section "external_dns" "external_dns_" EMPTY_MAP EMPTY_MAP EMPTY_MAP

# -----------------------------------------------------------------------------
# Backend configuration (always exported, even if empty)
# -----------------------------------------------------------------------------
export TF_BACKEND_BUCKET=$(yq -r '.project.bucket // ""' "$CONFIG_FILE")
export TF_BACKEND_KEY=$(yq -r '.project.state_key // ""' "$CONFIG_FILE")
export TF_BACKEND_DYNAMODB_TABLE=$(yq -r '.project.dynamodb_table // ""' "$CONFIG_FILE")

# -----------------------------------------------------------------------------
# Ansible-driven values
# -----------------------------------------------------------------------------
declare -A ANSIBLE_ENV_MAP=(
  [debug_level]="ANSIBLE_DEBUG_LEVEL"
  [dry_run]="ANSIBLE_DRY_RUN"
  [ansible_enabled]="ANSIBLE_ENABLED"
)

mapfile -t ansible_keys < <(section_keys "ansible")
for key in "${ansible_keys[@]}"; do
  if [[ -n "${ANSIBLE_ENV_MAP[$key]:-}" ]]; then
    export_plain_env "${ANSIBLE_ENV_MAP[$key]}" ".ansible.${key}"
    export_tf_var "$key" ".ansible.${key}"
    continue
  fi
  export_tf_var "$key" ".ansible.${key}"
done

echo "✅ Environment loaded successfully."
