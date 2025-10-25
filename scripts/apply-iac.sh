#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../terraform/stacks/main"

bash ../../scripts/load-config.sh

terraform init -upgrade
terraform apply -auto-approve