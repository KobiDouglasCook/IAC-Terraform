#!/bin/bash
set -e
set -o pipefail

# Step 1: Teardown Infrastructure
echo ">>> Tearing Down Infrastructure.."
cd infrastructure
terraform init
terraform destroy -auto-approve
cd ..

# Step 2: Teardown Backend (bootstrap)
echo ">>> Tearing Down Backend..."
cd bootstrap
terraform init
terraform destroy -auto-approve

echo "Terraform Destroy Complete!"