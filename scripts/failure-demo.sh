#!/usr/bin/env bash
# NAN Phase 1 - Failure scenario demonstration script
# Run during evaluation to demonstrate Phase 1 failure scenarios.
# Usage: bash scripts/failure-demo.sh

BACKEND_A="10.7.20.70"
BACKEND_B="10.7.0.210"

echo "========================================"
echo "  NAN Phase 1 — Failure Demonstrations"
echo "========================================"
echo ""

echo "--- Scenario 1: Wrong destination port ---"
echo "Attempting connection to app.NAN.test on port 9999 (should fail)"
curl --max-time 5 -v http://10.7.29.219:9999/ 2>&1 | tail -5 || true
echo ""

echo "--- Scenario 2: DNS name resolution ---"
echo "Resolving app.NAN.test via correct DNS server (10.7.3.114):"
dig app.NAN.test @10.7.3.114 +short
echo ""
echo "Resolving app.NAN.test via public DNS (should fail to resolve):"
dig app.NAN.test @8.8.8.8 +short || echo "(no answer - correct: public DNS does not know .NAN.test)"
echo ""

echo "--- Scenario 3: One backend down ---"
echo "Stop Backend A on Chinmay's machine, then run:"
echo "  for i in {1..6}; do curl -sk https://app.NAN.test/ -D- -o /dev/null | grep X-Backend; done"
echo "All responses should show X-Backend: B only."
echo ""

echo "--- Scenario 4: Both backends down ---"
echo "Stop both backends, then run:"
echo "  curl -sv https://app.NAN.test/"
echo "Expected: 502 Bad Gateway from nginx"
echo ""
