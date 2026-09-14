#!/usr/bin/env bash
# destroy-all.sh
# Destroys TravelEase infrastructure in the correct, safe dependency order:
# 1. Kubernetes Ingress & Helm releases (waits for AWS ALB to be cleanly deleted)
# 2. Cleans up any orphaned AWS ENIs in the VPC to prevent subnet deletion hang
# 3. Terraform environments: dev (or all: prod -> test -> dev -> shared)
#
# Usage:
#   ./scripts/destroy-all.sh           # Interactively destroys dev (and optionally shared)
#   ./scripts/destroy-all.sh --all     # Destroys prod -> test -> dev -> shared

set -euo pipefail

MODE="${1:-dev}"
REGION="ap-south-1"

echo "================================================================="
echo "⚠️   TravelEase Clean Infrastructure Teardown"
echo "================================================================="
echo "Target: $MODE"
echo ""
read -r -p "Type 'destroy' to confirm: " CONFIRM
if [[ "$CONFIRM" != "destroy" ]]; then
  echo "Aborted."
  exit 1
fi

export TF_VAR_db_master_password="${TF_VAR_db_master_password:-TravelEaseDevPass2026!}"
export TF_VAR_jwt_secret="${TF_VAR_jwt_secret:-travelease-super-secure-jwt-token-secret-key-32chars}"

# ── Step 1: Clean up Helm & Kubernetes Ingress first ─────────────────────────
echo ""
echo "==> [Step 1/3] Deleting Kubernetes Ingress and Helm releases..."
echo "    (Crucial: This triggers AWS to cleanly delete the ALB before cluster teardown)"

if kubectl get ingress -n travelease travelease &>/dev/null; then
  echo "    Deleting Ingress 'travelease'..."
  kubectl delete ingress travelease -n travelease --timeout=60s 2>/dev/null || true
  echo "    Waiting 30s for AWS ALB Controller to delete the Load Balancer in AWS..."
  sleep 30
fi

# Uninstall all Helm releases across namespaces
helm uninstall travelease -n travelease 2>/dev/null || true
helm uninstall kube-prometheus-stack -n monitoring 2>/dev/null || true
helm uninstall loki-stack -n monitoring 2>/dev/null || true
helm uninstall external-secrets -n external-secrets 2>/dev/null || true
helm uninstall metrics-server -n kube-system 2>/dev/null || true
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true

# ── Step 2: Clean up any orphaned VPC ENIs (prevents subnet hang) ─────────────
echo ""
echo "==> [Step 2/3] Checking for orphaned network interfaces (ENIs) in VPC..."
VPC_ID=$(terraform -chdir="terraform/environments/dev" output -raw vpc_id 2>/dev/null | tr -d '\r' || echo "")

if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
  AVAILABLE_ENIS=$(aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=status,Values=available" \
    --query "NetworkInterfaces[*].NetworkInterfaceId" \
    --output text --region "$REGION" 2>/dev/null || echo "")

  if [[ -n "$AVAILABLE_ENIS" ]]; then
    for ENI in $AVAILABLE_ENIS; do
      echo "    Deleting orphaned ENI: $ENI"
      aws ec2 delete-network-interface --network-interface-id "$ENI" --region "$REGION" 2>/dev/null || true
    done
  else
    echo "    No orphaned available ENIs found."
  fi
fi

# ── Step 3: Run Terraform Destroy ─────────────────────────────────────────────
echo ""
echo "==> [Step 3/3] Running Terraform Destroy..."

destroy_env() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    echo ""
    echo "==> Destroying environment: $dir"
    terraform -chdir="$dir" destroy -auto-approve \
      -var="db_master_password=${TF_VAR_db_master_password}" \
      -var="jwt_secret=${TF_VAR_jwt_secret}" 2>/dev/null || {
        echo "    Retrying $dir destroy..."
        terraform -chdir="$dir" destroy -auto-approve \
          -var="db_master_password=${TF_VAR_db_master_password}" \
          -var="jwt_secret=${TF_VAR_jwt_secret}"
      }
  fi
}

if [[ "$MODE" == "--all" ]]; then
  destroy_env "terraform/environments/prod"
  destroy_env "terraform/environments/test"
fi

destroy_env "terraform/environments/dev"

read -r -p "Do you also want to destroy shared ECR repository? [y/N]: " DESTROY_SHARED
if [[ "$DESTROY_SHARED" =~ ^[Yy]$ ]]; then
  destroy_env "terraform/environments/shared"
fi

echo ""
echo "✅ Teardown complete! All AWS resources safely destroyed."
