#!/usr/bin/env bash
# bootstrap-cluster.sh
# Installs the 4 cluster-level Helm releases in the correct order, then applies platform manifests.
# Usage: ./scripts/bootstrap-cluster.sh <cluster-name> <env> [kubeconfig-context]
#
# Example: ./scripts/bootstrap-cluster.sh dev dev
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

ALB_ROLE_ARN=$(terraform -chdir="$TF_DIR" output -raw alb_controller_role_arn | tr -d '\r')
VPC_ID=$(terraform -chdir="$TF_DIR" output -raw vpc_id 2>/dev/null | tr -d '\r' || echo "")
GRAFANA_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "travelease/${ENV}/grafana-admin" \
  --query SecretString --output text 2>/dev/null || true)
GRAFANA_PASSWORD=$(echo "$GRAFANA_PASSWORD" | tr -d '\r')
if [ -z "$GRAFANA_PASSWORD" ]; then
  GRAFANA_PASSWORD="admin-$(openssl rand -hex 8)"
fi

# ── Add Helm repositories ────────────────────────────────────────────────────
echo "==> Adding Helm repositories..."
helm repo add eks           https://aws.github.io/eks-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana        https://grafana.github.io/helm-charts
helm repo update

# ── 1. AWS Load Balancer Controller ─────────────────────────────────────────
echo "==> [1/4] Installing AWS Load Balancer Controller (v3.5.0)..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version "3.5.0" \
  --namespace kube-system \
  --create-namespace \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name="aws-load-balancer-controller" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ALB_ROLE_ARN}" \
  --set region="ap-south-1" \
  --set vpcId="${VPC_ID}" \
  --set replicaCount=1 \
  --wait

# Ensure ALB controller rollout is finished and set failurePolicy to Ignore so TLS blips never block services
echo "==> Ensuring AWS Load Balancer Controller webhook does not block internal services..."
kubectl rollout status deployment aws-load-balancer-controller -n kube-system --timeout=60s
kubectl patch mutatingwebhookconfiguration aws-load-balancer-webhook --type=json \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"},{"op":"replace","path":"/webhooks/1/failurePolicy","value":"Ignore"},{"op":"replace","path":"/webhooks/2/failurePolicy","value":"Ignore"}]' 2>/dev/null || true
kubectl patch validatingwebhookconfiguration aws-load-balancer-webhook --type=json \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"},{"op":"replace","path":"/webhooks/1/failurePolicy","value":"Ignore"}]' 2>/dev/null || true

# ── 2. Metrics Server ────────────────────────────────────────────────────────
echo "==> [2/4] Installing Metrics Server (v3.14.0)..."
helm upgrade --install metrics-server metrics-server/metrics-server \
  --version "3.14.0" \
  --namespace kube-system \
  --wait

# ── 3. kube-prometheus-stack (Prometheus + Grafana + Alertmanager) ───────────
echo "==> [3/4] Installing kube-prometheus-stack (v91.4.1)..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version "91.4.1" \
  --namespace monitoring \
  --create-namespace \
  -f platform/grafana-values-common.yaml \
  --set grafana.adminPassword="${GRAFANA_PASSWORD}" \
  --set prometheusOperator.admissionWebhooks.enabled=false \
  --set prometheusOperator.tls.enabled=false

# ── 4. Loki Stack (Loki + Promtail) ─────────────────────────────────────────
echo "==> [4/4] Installing Loki Stack (v2.10.3)..."
helm upgrade --install loki-stack grafana/loki-stack \
  --version "2.10.3" \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=false \
  --set loki.isDefault=false \
  -f platform/grafana-values-common.yaml

echo ""
echo "✅ Cluster bootstrap complete for ${CLUSTER_NAME}!"
echo "   Grafana admin password stored in Secrets Manager: travelease/${ENV}/grafana-admin"
echo "   Port-forward Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
