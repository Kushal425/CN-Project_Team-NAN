#!/usr/bin/env bash
# NAN Phase 1 - Demo verification script
# Run this before the evaluation to confirm all services are reachable.
# Usage: bash scripts/verify.sh

set -euo pipefail

DNS_SERVER="10.7.3.114"
GATEWAY_IP="10.7.29.219"
BACKEND_A="10.7.20.70"
BACKEND_B="10.7.0.210"

PASS=0
FAIL=0

check() {
    local label="$1"
    local result="$2"
    local expected="$3"
    if echo "$result" | grep -q "$expected"; then
        echo "[PASS] $label"
        ((PASS++)) || true
    else
        echo "[FAIL] $label"
        echo "       Expected: $expected"
        echo "       Got:      $result"
        ((FAIL++)) || true
    fi
}

echo "========================================="
echo "  NAN Phase 1 — Pre-Demo Verification"
echo "========================================="
echo ""

# DNS checks
echo "--- DNS ---"
result=$(dig app.NAN.test @"$DNS_SERVER" +short 2>/dev/null || echo "FAILED")
check "app.NAN.test resolves to $GATEWAY_IP" "$result" "$GATEWAY_IP"

result=$(dig api.NAN.test @"$DNS_SERVER" +short 2>/dev/null || echo "FAILED")
check "api.NAN.test resolves to $GATEWAY_IP" "$result" "$GATEWAY_IP"

echo ""

# Backend direct access
echo "--- Direct Backend Access ---"
result=$(curl -si --max-time 5 "http://$BACKEND_A:3001/api/status" 2>/dev/null || echo "FAILED")
check "Backend A reachable at $BACKEND_A:3001" "$result" "X-Backend: A"

result=$(curl -si --max-time 5 "http://$BACKEND_B:3002/api/status" 2>/dev/null || echo "FAILED")
check "Backend B reachable at $BACKEND_B:3002" "$result" "X-Backend: B"

echo ""

# HTTPS via nginx (requires CA in trust store, no -k)
echo "--- HTTPS through Nginx ---"
result=$(curl -s --max-time 10 -w "%{http_code}" -o /dev/null "https://app.NAN.test/" 2>/dev/null || echo "FAILED")
check "HTTPS app.NAN.test returns 200" "$result" "200"

result=$(curl -s --max-time 10 -w "%{http_code}" -o /dev/null "https://api.NAN.test/api/status" 2>/dev/null || echo "FAILED")
check "HTTPS api.NAN.test/api/status returns 200" "$result" "200"

echo ""

# Load balancing check (look for both A and B in 10 requests)
echo "--- Load Balancing ---"
BACKENDS_SEEN=""
for i in $(seq 1 10); do
    backend=$(curl -sk --max-time 5 -D - -o /dev/null "https://app.NAN.test/" 2>/dev/null | grep "X-Backend" | tr -d '\r\n' || echo "")
    BACKENDS_SEEN="$BACKENDS_SEEN $backend"
done

if echo "$BACKENDS_SEEN" | grep -q "A" && echo "$BACKENDS_SEEN" | grep -q "B"; then
    echo "[PASS] Round-robin: both Backend A and Backend B responded"
    ((PASS++)) || true
else
    echo "[FAIL] Round-robin: did not see both backends in 10 requests"
    echo "       Saw: $BACKENDS_SEEN"
    ((FAIL++)) || true
fi

echo ""

# Cache-Control header
echo "--- Cache-Control ---"
result=$(curl -sI --max-time 10 "https://api.NAN.test/api/status" 2>/dev/null || echo "FAILED")
check "Cache-Control: max-age=60 present" "$result" "max-age=60"

echo ""
echo "========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "========================================="
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
