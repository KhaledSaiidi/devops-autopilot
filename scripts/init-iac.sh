#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf "[$(date +'%F %T')] %s\n" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

CFG="${1:-$(cd "$(dirname "$0")/.." && pwd)/custom-config-infrastructure.yaml}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK="$ROOT/terraform/stacks/main"

need terraform
need yq

BUCKET="$(yq -r '.project.bucket' "$CFG")"
KEY="$(yq -r '.project.state_key' "$CFG")"
REGION="$(yq -r '.project.region' "$CFG")"
TABLE="$(yq -r '.project.dynamodb_table' "$CFG")"

[ -n "$BUCKET" ] && [ -n "$KEY" ] && [ -n "$REGION" ] && [ -n "$TABLE" ] || die "backend config incomplete in $CFG"

log "Initializing Terraform backend (bucket=$BUCKET key=$KEY region=$REGION table=$TABLE)..."
cd "$STACK"

# Make CI logs cleaner
export TF_IN_AUTOMATION=1

terraform init -reconfigure \
  -backend-config="bucket=$BUCKET" \
  -backend-config="key=$KEY" \
  -backend-config="region=$REGION" \
  -backend-config="dynamodb_table=$TABLE" \
  -backend-config="encrypt=true" \
  -input=false -no-color

log "✅ Terraform backend initialized successfully."
