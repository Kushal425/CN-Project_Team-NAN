# NAN Phase 2 configuration and demonstration

## Deployment inventory

| Mac | Role | LAN IPv4 | Configuration |
|---|---|---|---|
| Kushal | Primary nginx | `10.7.2.51` | [nginx/nan.conf](../nginx/nan.conf) |
| Lakshya | Primary DNS | `10.7.28.77` | [dns/dnsmasq.conf](../dns/dnsmasq.conf) |
| Chinmay | Backend A and backup DNS | `10.7.26.226` | [Python](../backends/backend-a/server.py) · [backup DNS](../dns/backup-dnsmasq.conf) · [PF](../firewall/backend-a.pf) |
| Prachee | Backend B and standby nginx | `10.7.2.53` | [Python](../backends/backend-b/server.py) · [standby nginx](../nginx/standby.conf) · [PF](../firewall/backend-b.pf) |

The [topology diagram](../architecture/phase2-topology.md) shows both edges and resolvers. All four Macs used `en0`, gateway `10.7.0.1`, and subnet `10.7.0.0/19` during the lab. Check the current addresses before reusing these files. Run each Python server on its named Mac with `python3 backends/backend-a/server.py` or `python3 backends/backend-b/server.py` from the repository root.

## DNS and HTTPS

1. On Lakshya’s and Chinmay’s Macs, use their respective dnsmasq configs. Use `--test --conf-file=/absolute/path/to/config` first. To reproduce the 60-second TTL test, add `--addn-hosts="$HOME/nan-ttl.hosts" --local-ttl=60` and start each service with `sudo` and `--no-daemon`. Put `10.7.2.51 ttl.NAN.test` in each extra hosts file before startup.
2. On the demo client, save any existing `/etc/resolver/nan.test` file first. The project file contains one `nameserver` line for `10.7.28.77` followed by one for `10.7.26.226`. Use `scutil --dns` to inspect the configuration and `dig @<resolver-IP> <name> A` to query each resolver directly.
3. The primary edge used the Homebrew nginx `servers/` include directory. Run `nginx -t` with the same privileges as the running process before starting or reloading. Keep the server certificates and their corresponding keys at the paths in the nginx configs. The standby uses its separately issued server certificate and private key in the same directory as `standby.conf`. Both certificates cover `app.NAN.test` and `api.NAN.test`.
4. Run the standby from a separate directory containing its config, `standby.crt`, and `standby.key`. Specify that directory with nginx `-p` and the config’s full path with `-c`. Test with `-t` first. The standby logs requests in that directory.
5. Clients can verify HTTPS with `curl --cacert /absolute/path/to/nan-ca.crt https://app.NAN.test/api/status`. For standby preflight, add `--resolve app.NAN.test:443:10.7.2.53`. The actual cutover test uses the normal hostname lookup. Keep the CA signing key and both server keys off GitHub.

## Fault and rollback sequence

| Test | During | Restore |
|---|---|---|
| Backup DNS | Start an `en0` capture filtered to DNS between the client and the two resolvers. Stop Lakshya’s foreground dnsmasq and verify that the direct primary query times out, the hostname-based HTTPS request succeeds, and the backup replies. | Restart Lakshya’s dnsmasq and confirm its direct answer. |
| Backend failover | Stop Chinmay’s Python server. Keep backup dnsmasq running. Repeat verified HTTPS requests and record the backend IDs. Capture ports 3001 and 3002 on the primary edge. | Restart Python on Chinmay’s Mac and verify both IDs return. |
| Backend isolation | On each backend Mac, verify the existing `com.apple/*` filter attachment. Validate the PF file with `sudo pfctl -n -a 'com.apple/000.nan-backends' -f /absolute/path/to/file`, then load it without `-n`. Enable with `sudo pfctl -E` and save that Mac’s token. Test from Kushal, Lakshya and the HTTPS client. | Flush only this project anchor with `sudo pfctl -a 'com.apple/000.nan-backends' -F rules` and release the same reference with `sudo pfctl -X <token>`. Recheck direct access from Lakshya. |
| DNS TTL | Prime the system resolver with `dscacheutil -q host -a name ttl.NAN.test`. Change the test name in both extra hosts files and send HUP to the individual dnsmasq processes. Compare direct `dig` and the native lookup before and after the TTL. For a separate manual-flush demonstration, flush the client before expiry. | Restore the prior extra hosts file on both resolvers and send HUP again. |
| Standby cutover | After standby preflight, save copies of both extra hosts files. Add `10.7.2.53 app.NAN.test` on both resolvers. Send HUP to both dnsmasq processes. Query both resolvers, then record client requests with `curl -w '\nConnected IP: %{remote_ip}\n'`. | Restore both extra hosts files, send HUP and verify both resolvers return `10.7.2.51`. Keep the standby up while any cached standby addresses expire. |

## Demonstration order

1. Show topology, addresses, and peer connectivity.
2. Verify LAN reachability between the four machines.
3. Resolve the project names from the client.
4. Open the service over trusted HTTPS.
5. Show both backend IDs across repeated requests.
6. Show the DNS query/reply, TCP three-way handshake and TLS in Wireshark.
7. Show the HTTP caching headers and demonstrate a browser cache hit or conditional response.
8. Demonstrate backend failure and recovery.
9. Demonstrate backup DNS, TTL behavior, isolation and controlled edge cutover.
10. For the faculty fault, check DNS, TCP, TLS, then HTTP and upstreams. Explain which result isolated the fault.
11. Prepare every member to explain the full request path and their role during the individual viva.

| Presenter | Slides and live role |
|---|---|
| Kushal | 1, 4, 8, 11. Introduce the project, explain the packet flow, run the upstream failover, and close with the live sequence. |
| Lakshya | 2, 5, 6. Explain the LAN inventory, primary and backup DNS, and TTL. |
| Chinmay | 3, 7. Recap Phase 1 and demonstrate the backend access rules and rollback. |
| Prachee | 9, 10. Show the standby edge cutover and explain how the team diagnosed the TLS trust issue. |

## Preflight and backend failover commands

On the demo client with the NAN DNS configuration and public CA:

```sh
CA="$HOME/Downloads/nan-ca.crt"
bash scripts/verify.sh "$CA"
bash scripts/failure-demo.sh both "$CA"
# Run while Backend A is stopped and the gateway is still up.
bash scripts/failure-demo.sh b-only "$CA"
# Restart Backend A before checking recovery.
bash scripts/failure-demo.sh both "$CA"
```

For the HTTP cache demonstration, use a browser that trusts the NAN CA. In the Network panel, make sure **Disable cache** is unchecked. Request the same `/api/status` URL twice within 60 seconds as ordinary GET requests. Compare the response header with the browser’s memory or disk cache indicator. For DNS TTL, use the native resolver as the client and compare its answer with direct `dig` queries to both servers.

Open the [evidence index](../evidence/phase2/README.md) before the demo. The [Phase 2 report](phase2-report.md) summarizes the lab results and points to the corresponding evidence.

The Phase 1 versions of [dnsmasq](../dns/phase1/dnsmasq.conf) and [nginx](../nginx/phase1/nan.conf) are archived for comparison.
