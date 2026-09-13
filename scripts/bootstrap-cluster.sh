#!/usr/bin/env bash
# bootstrap-cluster.sh
# Installs the 5 cluster-level Helm releases in the correct order, then applies platform manifests.
# Usage: ./scripts/bootstrap-cluster.sh <cluster-name> <env> [kubeconfig-context]
#
# Example: ./scripts/bootstrap-cluster.sh travelease-dev dev
#
# Prerequisites:
#   - kubectl configured for the target cluster (aws eks update-kubeconfig --name <cluster>)
#   - Terraform outputs available (via terraform output in the env directory)
#   - helm, kubectl, aws CLI on PATH

set -euo pipefail

CLUSTER_NAME="${1:?Usage: $0 <cluster-name> <env>}"
ENV="${2:?Usage: $0 <cluster-name> <env>}"

echo "==> Bootstrapping cluster: $CLUSTER_NAME (env: $ENV)"

# ── Fetch Terraform outputs ──────────────────────────────────────────────────
TF_DIR="terraform/environments/${ENV}"
echo "==> Reading Terraform outputs from $TF_DIR..."

ALB_ROLE_ARN=$(terraform -chdir="$TF_DIR" output -raw alb_controller_role_arn)
ESO_ROLE_ARN=$(terraform -chdir="$TF_DIR" output -raw eso_role_arn)
VPC_ID=$(terraform -chdir="$TF_DIR" output -raw vpc_id 2>/dev/null || echo "")
GRAFANA_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "travelease/${ENV}/grafana-admin" \
  --query SecretString --output text 2>/dev/null || echo "admin-$(openssl rand -hex 8)")

# ── Add Helm repositories ────────────────────────────────────────────────────
echo "==> Adding Helm repositories..."
helm repo add eks           https://aws.github.io/eks-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana        https://grafana.github.io/helm-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# ── 1. AWS Load Balancer Controller ─────────────────────────────────────────
echo "==> [1/5] Installing AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --create-namespace \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ALB_ROLE_ARN}" \
  --set region="ap-south-1" \
  --wait

# ── 2. Metrics Server ────────────────────────────────────────────────────────
echo "==> [2/5] Installing Metrics Server..."
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --wait

# ── 3. kube-prometheus-stack (Prometheus + Grafana + Alertmanager) ───────────
echo "==> [3/5] Installing kube-prometheus-stack..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f platform/grafana-values-common.yaml \
  --set grafana.adminPassword="${GRAFANA_PASSWORD}" \
  --wait \
  --timeout 8m

# ── 4. Loki Stack (Loki + Promtail) ─────────────────────────────────────────
echo "==> [4/5] Installing Loki Stack..."
helm upgrade --install loki-stack grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=false \
  -f platform/grafana-values-common.yaml \
  --wait \
  --timeout 5m

# ── 5. External Secrets Operator ─────────────────────────────────────────────
echo "==> [5/5] Installing External Secrets Operator..."
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ESO_ROLE_ARN}" \
  --wait

# ── Apply platform manifests ─────────────────────────────────────────────────
echo "==> Applying platform manifests..."
kubectl apply -f platform/namespace.yaml
# Wait for ESO deployment to be ready (CRDs must be established before ClusterSecretStore)
echo "==> Waiting for External Secrets Operator to be ready..."
kubectl wait deployment/external-secrets \
  -n external-secrets \
  --for=condition=Available \
  --timeout=120s
kubectl apply -f platform/cluster-secret-store.yaml

echo ""
echo "✅ Cluster bootstrap complete for ${CLUSTER_NAME}!"
echo "   Grafana admin password stored in Secrets Manager: travelease/${ENV}/grafana-admin"
echo "   Port-forward Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
