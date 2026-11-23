# NAN Phase 2 Report

Private Network Service Platform · Computer Networks  
Team NAN · 23 November 2026

## 1. Project Overview and Network Architecture

### 1.1 Phase 1 Recap

In October, the team connected four Macs on a private LAN. Lakshya’s dnsmasq mapped both NAN hostnames to Kushal’s nginx gateway. nginx terminated TLS and distributed HTTP requests between Chinmay’s Backend A and Prachee’s Backend B. The team verified HTTPS, observed round-robin responses in the X-Backend header, and recorded DNS, TCP and TLS packets in Wireshark. A backend outage exercise established the starting point for the more controlled Phase 2 resilience tests.

[Phase 1 report](Report.pdf) · [Phase 1 architecture](../architecture/topology.md)

### 1.2 Phase 2 Objective

Phase 2 extends the Phase 1 service without changing the backend application. Team NAN rebuilt the baseline on a new private LAN and added DNS redundancy, backend isolation, upstream recovery, and a standby HTTPS gateway.

### 1.3 Team and Machine Roles

| Member | IPv4 on en0 | Services and ports |
|---|---|---|
| Lakshya | `10.7.28.77` | Primary DNS · UDP/TCP 53 |
| Kushal | `10.7.2.51` | Primary nginx · TCP 443 and 8080 |
| Chinmay | `10.7.26.226` | Backend A · TCP 3001 · Backup DNS · UDP/TCP 53 |
| Prachee | `10.7.2.53` | Backend B · TCP 3002 · Standby nginx · TCP 443 |

### 1.4 Request Flow and Baseline

The four Macs used subnet `10.7.0.0/19` with gateway `10.7.0.1`. Kushal received three replies from each peer. The client resolves the private name, opens TCP to the selected edge, verifies TLS, and sends an HTTPS request. nginx terminates TLS and forwards HTTP to a backend.

```text
Client      -> DNS resolver         UDP/TCP 53
Client      -> nginx gateway        HTTPS / TCP 443
nginx       -> Backend A or B       HTTP / TCP 3001 or 3002
```

> **Result.** Four trusted HTTPS requests returned HTTP 200, with backend IDs B, A, B, A. The status response exposed `Cache-Control: max-age=60`.

[Architecture diagram](../architecture/phase2-topology.md) · [Baseline evidence](../evidence/phase2/01-restored-baseline/04-baseline-packets.tsv)

## 2. Extension A — Backup DNS Resolver

### 2.1 Configuration and Test

Lakshya ran the primary resolver and Chinmay ran a backup with the same project records. Prachee configured both resolver addresses for `nan.test`. When Lakshya stopped dnsmasq, the direct query to the primary timed out. Prachee then reached `api.NAN.test` over verified HTTPS through ordinary name resolution.

```text
Primary DNS  10.7.28.77:53    Direct lookup timed out
Backup DNS   10.7.26.226:53   api.NAN.test A 10.7.2.51 (frame 8)
HTTPS        api.NAN.test    HTTP 200
```

> **Result.** The packet capture identifies Chinmay’s resolver as the server that answered the client during the primary DNS outage.

### 2.2 Learning Summary

DNS availability and application availability are separate. During this test the original resolver was unreachable, while the gateway and backends remained available through the backup answer.

[Capture and Terminal evidence](../evidence/phase2/README.md#02--backup-dns)

## 3. Extension B — DNS TTL and Record Change

### 3.1 Configuration and Evidence

Both resolvers advertised a 60-second TTL for `ttl.NAN.test`. The test record moved from `10.7.2.51` to `10.7.2.53` independently of the application names. Packet frames 4, 6 and 8 show the old answer and the two updated resolver answers.

```text
20:22:00 IST  Client returned 10.7.2.51
20:24:25 IST  Both resolvers and client returned 10.7.2.53
Advertised A-record TTL: 60 seconds
```

> **Result.** Both resolvers delivered the updated address, and the client used it at the later check.

### 3.2 Learning Summary

TTL bounds how long a cached DNS answer can remain valid. A controlled cutover should keep the old gateway available while clients holding earlier answers refresh.

[TTL capture and Terminal evidence](../evidence/phase2/README.md#03--dns-ttl)

## 4. Extension C — Backend Service Isolation

### 4.1 Firewall Rules and Validation

Chinmay and Prachee loaded macOS PF rules scoped to the backend listener on `en0`. The rules permitted Kushal’s primary edge on `10.7.2.51` and blocked other LAN clients from reaching ports 3001 and 3002 directly.

| Source and path | Backend A | Backend B |
|---|---|---|
| Kushal, direct HTTP | 200 OK | 200 OK |
| Lakshya, direct HTTP with rules active | Timed out | Timed out |
| Prachee, HTTPS through nginx | 200 OK | 200 OK |
| Lakshya, direct HTTP after rollback | 200 OK | 200 OK |

> **Result.** The gateway retained access to both ports, ordinary clients used HTTPS through the gateway, and removing the project rules restored Lakshya’s direct access.

### 4.2 Learning Summary

Filtering at each backend enforces the service boundary even if a client knows a backend IP. A dedicated PF anchor gave the team a scoped rollback.

[Gateway, blocked client, HTTPS, and rollback evidence](../evidence/phase2/README.md#04--backend-isolation)

## 5. Extension D — Backend Failover and Recovery

### 5.1 Procedure and Results

Prachee made six verified HTTPS requests in each stage. While Backend A was stopped, its TCP resets appeared in frames 90 and 92. Backend B returned HTTP 200 in frame 101. Backend A returned HTTP 200 again in frame 186 after recovery.

| Stage | HTTP 200 | Backend A | Backend B |
|---|---|---|---|
| Both running | 6 / 6 | 3 | 3 |
| Backend A stopped | 6 / 6 | 0 | 6 |
| Backend A restarted | 6 / 6 | 3 | 3 |

> **Result.** nginx continued to serve all six sampled requests through Backend B while A was down and resumed distributing requests across both servers after A restarted.

### 5.2 Learning Summary

nginx handled an upstream failure via passive retry. Clients using the primary edge IP still depend on that gateway. Automatic edge recovery would require redundant gateways and health-based traffic steering.

[Failover Terminal evidence, packet capture, and recovery view](../evidence/phase2/README.md#05--backend-failover)

## 6. Extension E — Controlled DNS Cutover

### 6.1 Standby Configuration and Cutover

Prachee’s standby nginx used its own NAN CA-signed certificate and forwarded requests to both backends. Four pinned preflight requests returned HTTP 200 with both backend IDs. On the cutover, both resolvers moved `app.NAN.test` to the standby. The primary resolver still answered `10.7.2.51` for `api.NAN.test`.

```text
Before      app.NAN.test -> 10.7.2.51   HTTPS 200
After       app.NAN.test -> 10.7.2.53   HTTPS 200
Standby     X-NAN-Edge: standby
Rollback    Both resolvers -> 10.7.2.51
```

> **Result.** A normal hostname-based HTTPS request reached the standby after the DNS change. Both DNS servers returned the primary address again after rollback.

### 6.2 Learning Summary

DNS can redirect new connections without changing the URL. Using certificates valid for the same hostname preserves client verification at both edges. The old edge remains useful while cached answers age out.

[Preflight, cutover, and rollback evidence](../evidence/phase2/README.md#06--standby-edge-cutover)

## 7. Extension F — Troubleshooting Method

### 7.1 Team Case Study — TLS Trust

Prachee could resolve the hostname and establish TCP to nginx. Wireshark showed the TCP handshake and TLS Hello packets. curl returned error 60 because it could not verify the issuer. The team exported the public NAN CA, compared the fingerprint, and passed it to curl with `--cacert`.

> **Result.** After the CA was supplied, the same client returned four verified HTTPS 200 responses with both backend IDs.

### 7.2 Learning Summary

Checking DNS, TCP, TLS, then HTTP in order isolates the fault. Here the DNS answer and TCP handshake narrowed the investigation to TLS trust before any backend changes were made. The same sequence is the team’s method for the faculty-injected fault during evaluation.

## 8. Summary

Team NAN demonstrated redundant DNS, a controlled record change, restricted backend access, continued service during an upstream outage, and a manual cutover to a second HTTPS gateway. The configuration bundle and evidence are indexed by test for the live demonstration.

[Evidence index](../evidence/phase2/README.md) · [Configuration and demonstration](phase2-runbook.md)
