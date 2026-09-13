#!/usr/bin/env bash
# destroy-all.sh
# Destroys all Terraform-managed resources in REVERSE order: prod → test → dev → shared → bootstrap.
# Usage: ./scripts/destroy-all.sh
#
# CAUTION: This will destroy ALL infrastructure across all environments.
# Prod has deletion_protection=true on RDS — you must disable it first or use -target.

set -euo pipefail

echo "⚠️  WARNING: This will destroy ALL TravelEase infrastructure."
echo "   Environments: prod, test, dev, shared, bootstrap"
echo ""
read -r -p "Type 'destroy' to confirm: " CONFIRM
if [[ "$CONFIRM" != "destroy" ]]; then
  echo "Aborted."
  exit 1
fi

destroy_env() {
  local dir="$1"
  echo ""
  echo "==> Destroying: $dir"
  if [[ -d "$dir" && -f "$dir/terraform.tfstate" || -f "$dir/.terraform/terraform.tfstate" ]]; then
    terraform -chdir="$dir" destroy -auto-approve \
      -var="db_master_password=${TF_VAR_db_master_password:-dummy}" \
      -var="jwt_secret=${TF_VAR_jwt_secret:-dummy}"
  else
    echo "    (skipping — no state found)"
  fi
}

# Reverse order: prod → test → dev → shared → bootstrap
destroy_env "terraform/environments/prod"
destroy_env "terraform/environments/test"
destroy_env "terraform/environments/dev"
destroy_env "terraform/environments/shared"

echo ""
read -r -p "Also destroy bootstrap (state bucket)? [y/N]: " DESTROY_BOOTSTRAP
if [[ "$DESTROY_BOOTSTRAP" =~ ^[Yy]$ ]]; then
  destroy_env "terraform/bootstrap"
fi

echo ""
echo "✅ All resources destroyed."
