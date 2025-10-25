#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf "[$(date +'%F %T')] %s\n" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK="$ROOT/terraform/stacks/main"
CFG="${1:-$ROOT/custom-config.yaml}"

need terraform
need yq

cd "$STACK"

source "$ROOT/scripts/load-config.sh" "$CFG"

export TF_IN_AUTOMATION=1

terraform fmt -recursive
terraform validate -no-color
terraform destroy -auto-approve -input=false -no-color
log "✅ Infrastructure destroyed successfully."
