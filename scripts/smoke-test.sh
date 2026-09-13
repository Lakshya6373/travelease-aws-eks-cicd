#!/usr/bin/env bash
# smoke-test.sh
# Runs basic availability checks against a deployed TravelEase instance.
# Usage: ./scripts/smoke-test.sh <base-url>
#   e.g. ./scripts/smoke-test.sh http://my-alb.ap-south-1.elb.amazonaws.com
#
# Exit code: 0 if all checks pass, 1 if any fail.
# Used by CI (cd-pipeline.yml) and runnable locally against any env.

set -euo pipefail

BASE_URL="${1:?Usage: $0 <base-url>}"
PASS=0
FAIL=0
MAX_RETRIES=12
RETRY_DELAY=15  # seconds — ALB may take a minute to fully route traffic

check_endpoint() {
  local path="$1"
  local expected_code="${2:-200}"
  local url="${BASE_URL}${path}"
  local attempt=0

  echo -n "  Checking $url ... "

  while [[ $attempt -lt $MAX_RETRIES ]]; do
    actual_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "$url" || echo "000")

    if [[ "$actual_code" == "$expected_code" ]]; then
      echo "✅ HTTP $actual_code"
      PASS=$((PASS + 1))
      return 0
    fi

    attempt=$((attempt + 1))
    if [[ $attempt -lt $MAX_RETRIES ]]; then
      echo -n "(got $actual_code, retry $attempt/$MAX_RETRIES in ${RETRY_DELAY}s) "
      sleep $RETRY_DELAY
    fi
  done

  echo "❌ FAILED — expected HTTP $expected_code, got $actual_code"
  FAIL=$((FAIL + 1))
  return 1
}

echo ""
echo "🔍 Smoke testing: $BASE_URL"
echo "────────────────────────────────────────────"

check_endpoint "/actuator/health"
check_endpoint "/"
check_endpoint "/destinations"
check_endpoint "/login"
check_endpoint "/register"

echo "────────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  echo "❌ Smoke tests FAILED"
  exit 1
else
  echo "✅ All smoke tests passed"
  exit 0
fi
