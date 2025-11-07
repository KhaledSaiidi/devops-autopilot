#!/usr/bin/env bash
set -Eeuo pipefail

# -------- utils --------
log() { printf "[$(date +'%F %T')] %s\n" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

usage() {
  cat <<'EOF'
Usage: scripts/apply-ansible.sh [--inventory <file>] [--vars <file>] [--playbook <file>] [--artifacts <dir>] [-v|-vv|-vvv|-vvvv]
Environment:
  ANSIBLE_DRY_RUN     If set to 1/true/yes, runs ansible with --check
  ANSIBLE_VERBOSITY   One of: quiet, normal, verbose, very, debug
Defaults:
  inventory:  <artifacts>/*-inventory.ini
  vars:       <artifacts>/*-ansible-vars.yaml
  ssh key:    <artifacts>/*-eks.pem
  playbook:   ansible/playbooks/bootstrap-iac.yml
  artifacts:  terraform/stacks/main/artifacts
EOF
}

# -------- args --------
INVENTORY=""
VARSFILE=""
PLAYBOOK=""
ARTIFACTS=""
CLI_VERBOSITY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --inventory) INVENTORY="${2:-}"; shift 2 ;;
    --vars)      VARSFILE="${2:-}"; shift 2 ;;
    --playbook)  PLAYBOOK="${2:-}"; shift 2 ;;
    --artifacts) ARTIFACTS="${2:-}"; shift 2 ;;
    -v|-vv|-vvv|-vvvv) CLI_VERBOSITY="$1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown arg: $1 (use -h for help)";;
  esac
done

# -------- layout --------
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK="$ROOT/terraform/stacks/main"
ARTIFACTS="${ARTIFACTS:-$STACK/artifacts}"
PLAYBOOK="${PLAYBOOK:-$ROOT/ansible/playbooks/bootstrap-iac.yml}"
CFG="${CFG:-$ROOT/custom-config-infrastructure.yaml}"

# Point Ansible to the config that defines roles_path, etc.
ANS_CFG_FILE="$ROOT/ansible.cfg"
[[ -f "$ANS_CFG_FILE" ]] || die "Missing $ANS_CFG_FILE"
export ANSIBLE_CONFIG="$ANS_CFG_FILE"
# Make roles discovery absolute & unambiguous regardless of CWD
export ANSIBLE_ROLES_PATH="$ROOT/ansible/roles"

# -------- source ansible vars --------
source "$ROOT/scripts/load-config.sh" "$CFG"

# -------- ansible toggle --------
case "${ANSIBLE_ENABLED:-true}" in
  0|false|False) log "⚙️  Ansible is disabled (ANSIBLE_ENABLED=${ANSIBLE_ENABLED}). Skipping playbook execution."; exit 0 ;;
esac

# -------- deps --------
need ansible-playbook
need ssh
need yq

# -------- helpers --------
latest_file()(
  shopt -s nullglob
  for pat in "$@"; do set -- $pat; done
  ls -1t "$@" 2>/dev/null | head -n1 || true
)

INVENTORY="${INVENTORY:-$(latest_file "$ARTIFACTS"/*-inventory.ini)}"
VARSFILE="${VARSFILE:-$(latest_file "$ARTIFACTS"/*-ansible-vars.yaml)}"
SSH_KEY="${SSH_KEY:-$(latest_file "$ARTIFACTS"/*-eks.pem)}"

[[ -n "$INVENTORY" && -f "$INVENTORY" ]] || die "Inventory not found (expected pattern: $ARTIFACTS/*-inventory.ini)"
[[ -n "$VARSFILE" && -f "$VARSFILE"   ]] || die "Vars file not found (expected pattern: $ARTIFACTS/*-ansible-vars.yaml)"
[[ -n "$SSH_KEY" && -f "$SSH_KEY"     ]] || die "SSH key not found (expected pattern: $ARTIFACTS/*-eks.pem)"
[[ -f "$PLAYBOOK"                     ]] || die "Playbook not found: $PLAYBOOK"

chmod 600 "$SSH_KEY" || true

# -------- env knobs --------
CHECK_FLAG=""
case "${ANSIBLE_DRY_RUN:-}" in 1|true|True) CHECK_FLAG="--check" ;; esac

verbosity_from_env() {
  case "${ANSIBLE_VERBOSITY:-normal}" in
    quiet) echo "" ;;
    normal)      echo "-v" ;;
    verbose)         echo "-vv" ;;
    high)         echo "-vvv" ;;
    debug)        echo "-vvvv" ;;
    *)            echo "" ;;
  esac
}
VERBOSITY="${CLI_VERBOSITY:-$(verbosity_from_env)}"

# Recommended for non-interactive runs
export ANSIBLE_HOST_KEY_CHECKING=False
# (Optional) Quiet known-hosts prompts with SSH args
export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

log "Running Ansible with:"
log "  inventory: $INVENTORY"
log "  vars:      $VARSFILE"
log "  playbook:  $PLAYBOOK"
log "  key:       $SSH_KEY"
log "  config:    $ANSIBLE_CONFIG"
[[ -n "$CHECK_FLAG" ]] && log "  mode:      DRY-RUN"
[[ -n "$VERBOSITY"  ]] && log "  verbosity: $VERBOSITY"

# -------- ensure Ansible collections --------
need ansible-galaxy

COLL_PATH="$ROOT/.ansible/collections"
mkdir -p "$COLL_PATH"

export ANSIBLE_COLLECTIONS_PATHS="$COLL_PATH:$HOME/.ansible/collections:/usr/share/ansible/collections"

have_k8s_core=$(ansible-galaxy collection list -p "$COLL_PATH" kubernetes.core >/dev/null 2>&1 && echo yes || echo no)
have_comm_k8s=$(ansible-galaxy collection list -p "$COLL_PATH" community.kubernetes >/dev/null 2>&1 && echo yes || echo no)
if [[ "$have_k8s_core" != "yes" || "$have_comm_k8s" != "yes" ]]; then
  log "Installing Ansible collections to $COLL_PATH ..."
  ansible-galaxy collection install -r "$ROOT/ansible/requirements.yml" \
    --collections-path "$COLL_PATH" --force-with-deps
else
  log "Ansible collections already present in $COLL_PATH"
fi

# Optional: Python libs needed by kubernetes.core/community.kubernetes modules on the controller
# Set INSTALL_PY_K8S_DEPS=0 to skip
if [[ "${INSTALL_PY_K8S_DEPS:-1}" != "0" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    log "Ensuring python deps for k8s modules (kubernetes, openshift, pyyaml) ..."
    python3 -m pip install --user -q "kubernetes>=26.1.0" "openshift>=0.13.2" pyyaml || true
  fi
fi

set -x
ansible-playbook \
  -i "$INVENTORY" \
  --private-key "$SSH_KEY" \
  -e "@${VARSFILE}" \
  ${CHECK_FLAG} ${VERBOSITY} \
  "$PLAYBOOK"
set +x

log "✅ Ansible run completed."
