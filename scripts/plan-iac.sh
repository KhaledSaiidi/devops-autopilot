#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../terraform/stacks/main"

# Load environment
bash ../../scripts/load-config.sh

terraform init -upgrade
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan