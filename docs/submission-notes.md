# NAN Phase 1 — Submission Notes

## Project Summary

Team: NAN
Course: Computer Networks
Phase: 1 (Build and Observe)
Submission Date: October 2026

---

## Team Roles and Machines

| Role | Team Member | IP Address | Port(s) |
|---|---|---|---|
| Nginx Gateway / Reverse Proxy | Kushal | 10.7.29.219 | 443, 8080 |
| DNS Server (dnsmasq) | Lakshya | 10.7.3.114 | 53 |
| Backend A (Python HTTP) | Chinmay | 10.7.20.70 | 3001 |
| Backend B (Python HTTP) | Prachee | 10.7.0.210 | 3002 |

---

## Phase 1 Task Completion Status

| Task | Description | Status |
|---|---|---|
| Task A | Establish Private LAN | COMPLETE |
| Task B | Configure Private DNS Server | COMPLETE |
| Task C | Build Two Simple Backend Services | COMPLETE |
| Task D | Configure Edge Reverse Proxy and Load Balancer | COMPLETE |
| Task E | Add HTTPS / TLS | COMPLETE |
| Task F | Demonstrate HTTP Caching Behavior | COMPLETE |
| Task G | Capture Complete Protocol Flow | COMPLETE |

---

## Task A — LAN Setup

All four team machines were connected to the same private Wi-Fi network.

Evidence: evidence/01-lan/backend-connectivity.txt

Direct HTTP connectivity from the gateway machine (Kushal) to both backend machines was verified:
- curl -i http://10.7.20.70:3001/api/status  -> 200 OK, X-Backend: A
- curl -i http://10.7.0.210:3002/api/status  -> 200 OK, X-Backend: B

Topology diagram: architecture/topology.md

Note: Full ping connectivity table between all four machines should be verified and documented at the time of the live demo.

---

## Task B — DNS

dnsmasq was configured on Lakshya's machine (10.7.3.114:53).

DNS records:
- app.NAN.test -> 10.7.29.219
- api.NAN.test -> 10.7.29.219

Configuration file: dns/dnsmasq.conf

Evidence:
- evidence/02-dns/dns-resolution.txt
- dig app.NAN.test returned NOERROR with answer 10.7.29.219 from server 10.7.3.114#53
- dig api.NAN.test returned NOERROR with answer 10.7.29.219 from server 10.7.3.114#53

Note: DNS clients should be configured to use 10.7.3.114 as the resolver. The dnsmasq config uses bind-interfaces to restrict listening to the LAN interface only, which prevents breaking system DNS for other domains.

---

## Task C — Backends

Two Python HTTP backends were built:
- Backend A: backends/backend-a/server.py (port 3001)
- Backend B: backends/backend-b/server.py (port 3002)

Endpoints:
- GET / returns "Backend A" or "Backend B" with X-Backend header
- GET /api/status returns "Backend X is healthy" with X-Backend and Cache-Control: max-age=60

Both backends bind to 0.0.0.0 so they are reachable from all machines on the LAN.

---

## Task D — Nginx Reverse Proxy and Load Balancing

Configuration: nginx/nan.conf

Nginx listens on port 443 (HTTPS) and port 8080 (HTTP fallback).

Round-robin load balancing distributes requests between Backend A and Backend B.

Evidence:
- evidence/04-load-balancing/load-balancing.txt
- evidence/04-load-balancing/01-round-robin.png
- 12 consecutive requests showed perfect alternation: B, A, B, A, B, A...

---

## Task E — HTTPS / TLS

A local CA (NAN Local CA) was created. A server certificate was issued for app.NAN.test.

Nginx terminates TLS on port 443. The CA certificate was added to client trust stores.

TLS version: TLSv1.3
Cipher: AEAD-CHACHA20-POLY1305-SHA256

Evidence:
- evidence/03-https/https-tls.txt
- curl -v https://app.NAN.test/ completed with "SSL certificate verify ok."

TLS documentation: tls/README.md

IMPORTANT for demo: Do not use -k flag. The certificate is properly trusted on client machines.

Known issue to check: The certificate CN is app.NAN.test. Verify that api.NAN.test is covered by a SAN extension, otherwise strict TLS clients may warn. The current evidence shows SSL certificate verify ok for api.NAN.test, so this appears to be working.

---

## Task F — HTTP Caching

The /api/status endpoint returns Cache-Control: max-age=60.

Evidence:
- evidence/05-cache/cache-control.txt
- evidence/05-cache/01-cache-control-header.png

Demo commands:
```bash
# Show headers
curl -sk -D - -o /dev/null https://api.NAN.test/api/status

# Show cache-control specifically
curl -sk -I https://api.NAN.test/api/status | grep -i cache
```

Note: The evidence shows that the Cache-Control header is correctly sent. For a stronger caching demo, show a browser DevTools network panel with "from cache" or a curl session where the same request returns quickly from cache.

---

## Task G — Wireshark Protocol Capture

Evidence directory: evidence/06-wireshark/

Files:
- NAN-phase1-dns-capture.pcapng  (DNS resolution traffic)
- NAN_phase1_baseline_traffic.pcapng  (full system baseline)
- 01-dns-resolution.png  (Wireshark screenshot: DNS query/response)
- 02-https-tls-traffic.png  (Wireshark screenshot: TLS handshake packets)
- 03-mixed-port-filter.png  (Wireshark screenshot: multiple ports filtered)
- backend-B-port-3002-api-status.png  (Wireshark screenshot: Backend B traffic)

Demo Wireshark filter commands:
```
dns                          -- show DNS packets
tcp.port == 443              -- show HTTPS traffic
tcp.flags.syn == 1           -- show TCP SYN packets (three-way handshake)
tls.handshake               -- show TLS handshake messages
```

---

## Phase 1 Failure Scenarios (Task G requirement)

| Failure | Expected Result | Evidence |
|---|---|---|
| Wrong DNS configured | Name lookup fails, IP still reachable | Demonstrate live during eval |
| DNS record wrong IP | DNS resolves but connection fails | Demonstrate live during eval |
| One backend stopped | Requests continue via other backend | evidence/07-failure/ |
| Both backends stopped | 502 Bad Gateway from nginx | Demonstrate live during eval |
| Wrong destination port | TCP connection refused | Demonstrate live during eval |

Failure evidence: evidence/07-failure/

Files:
- 01-backend-a-failure.png
- 02-backend-b-healthy.png
- 03-backend-a-reset.png
- NAN_phase1_backend_failure_failover.pcapng

---

## Pre-Demo Checklist

Before the evaluation, verify:

- [ ] All four machines on the same Wi-Fi
- [ ] dnsmasq running on 10.7.3.114 (Lakshya)
- [ ] Nginx running on 10.7.29.219 (Kushal)
- [ ] Backend A running on 10.7.20.70:3001 (Chinmay)
- [ ] Backend B running on 10.7.0.210:3002 (Prachee)
- [ ] Client DNS resolver set to 10.7.3.114
- [ ] NAN Local CA in client trust store (no -k needed)
- [ ] dig app.NAN.test returns 10.7.29.219
- [ ] curl -v https://app.NAN.test/ returns 200 with "SSL certificate verify ok."
- [ ] X-Backend alternates A/B in repeated curl requests
- [ ] Wireshark captures loaded and ready to present
- [ ] Network topology diagram ready to show

---

## Quick Demo Commands

```bash
# DNS resolution
dig app.NAN.test @10.7.3.114

# HTTPS connection (no -k for demo)
curl -v https://app.NAN.test/

# Load balancing (watch X-Backend alternate)
for i in {1..10}; do
    echo -n "Request $i: "
    curl -sk https://app.NAN.test/ -D - -o /dev/null | grep X-Backend
done

# Cache-Control headers
curl -sI https://api.NAN.test/api/status

# Backend direct access (bypass nginx)
curl -i http://10.7.20.70:3001/api/status
curl -i http://10.7.0.210:3002/api/status
```

---

## Files NOT in Repository (Security)

The following files contain private cryptographic material and must NOT be committed:

- nan-server.key  (Nginx TLS private key)
- nan-ca.key  (CA private key)

These are stored only on the gateway machine at /opt/homebrew/etc/nginx/.
