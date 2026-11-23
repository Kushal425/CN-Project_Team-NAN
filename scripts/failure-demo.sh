#!/usr/bin/env bash
# Run from a demo client using the NAN resolver and public CA.
set -euo pipefail

mode=${1:-}
ca_file=${2:-}
if [[ "$mode" != both && "$mode" != b-only ]] || [[ ! -r "$ca_file" ]]; then
    printf 'Usage: bash %s both|b-only /path/to/nan-ca.crt\n' "$0" >&2
    exit 2
fi

url=${NAN_STATUS_URL:-https://app.NAN.test/api/status}
expected_peer=${NAN_EXPECT_EDGE:-}
count_a=0
count_b=0
for request in 1 2 3 4 5 6; do
    response=$(curl --noproxy '*' --cacert "$ca_file" --connect-timeout 5 \
        --max-time 10 --silent --show-error --fail --dump-header - \
        --output /dev/null --write-out $'\nstatus=%{http_code} peer=%{remote_ip}\n' "$url")
    status=$(printf '%s\n' "$response" | awk '/^status=/ { print $1 }')
    peer=$(printf '%s\n' "$response" | awk '/^status=/ { sub(/^peer=/, "", $2); print $2 }')
    backend=$(printf '%s\n' "$response" | awk '
        tolower($1) == "x-backend:" { sub(/\r$/, "", $2); print $2 }
    ')
    printf 'Request %s: %s X-Backend: %s\n' "$request" \
        "$(printf '%s\n' "$response" | awk '/^status=/ { print }')" "$backend"
    if [[ "$status" != status=200 ]]; then
        printf 'Expected status=200, got %s\n' "$status" >&2
        exit 1
    fi
    if [[ -n "$expected_peer" && "$peer" != "$expected_peer" ]]; then
        printf 'Expected edge %s, got %s\n' "$expected_peer" "$peer" >&2
        exit 1
    fi
    case "$backend" in
        A) count_a=$((count_a + 1)) ;;
        B) count_b=$((count_b + 1)) ;;
        *) printf 'Unexpected X-Backend value: %s\n' "$backend" >&2; exit 1 ;;
    esac
done

printf 'A=%s B=%s\n' "$count_a" "$count_b"
if [[ "$mode" == both ]]; then
    [[ "$count_a" -gt 0 && "$count_b" -gt 0 ]]
else
    [[ "$count_a" -eq 0 && "$count_b" -eq 6 ]]
fi
