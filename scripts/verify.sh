#!/usr/bin/env bash
# Verify the normal Phase 2 baseline from a demo client.
set -euo pipefail

ca_file=${1:-}
if [[ ! -r "$ca_file" ]]; then
    printf 'Usage: bash %s /path/to/nan-ca.crt\n' "$0" >&2
    exit 2
fi

primary_dns=${NAN_PRIMARY_DNS:-10.7.28.77}
backup_dns=${NAN_BACKUP_DNS:-10.7.26.226}
primary_edge=${NAN_PRIMARY_EDGE:-10.7.2.51}

for resolver in "$primary_dns" "$backup_dns"; do
    for name in app.NAN.test api.NAN.test; do
        answer=$(dig "@$resolver" "$name" A +short +time=2 +tries=1)
        if [[ "$answer" != "$primary_edge" ]]; then
            printf 'DNS failure: %s at %s returned %s (expected %s)\n' \
                "$name" "$resolver" "${answer:-no answer}" "$primary_edge" >&2
            exit 1
        fi
        printf 'DNS: %s via %s = %s\n' "$name" "$resolver" "$answer"
    done
done

api_response=$(curl --noproxy '*' --cacert "$ca_file" --max-time 10 \
    --silent --show-error --fail --dump-header - --output /dev/null \
    --write-out $'\npeer=%{remote_ip}\n' https://api.NAN.test/api/status)
printf '%s\n' "$api_response" | tr -d '\r' | grep -F -x "peer=$primary_edge"
printf '%s\n' "$api_response" | tr -d '\r' | grep -E -i '^Cache-Control: .*max-age=60'

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
NAN_EXPECT_EDGE="$primary_edge" bash "$script_dir/failure-demo.sh" both "$ca_file"
