# Backend Failure Evidence — NAN Phase 1

## Overview

This directory contains evidence from the Phase 1 backend failure test.

The test demonstrates what happens at the network level when one backend becomes unavailable while the Nginx gateway continues running. This maps to the Phase 1 failure scenario: "One backend is stopped."

---

## Architecture During Test

```
Client -> 10.7.29.219:443 (Nginx)
               |
               +---X---> 10.7.20.70:3001  Backend A  (STOPPED)
               |
               +-------> 10.7.0.210:3002  Backend B  (running)
```

---

## Test Sequence

1. Both backends were running and load balancing was confirmed (A and B alternating).
2. Backend A was stopped on Chinmay's machine (10.7.20.70).
3. Requests continued to be sent through Nginx via HTTPS.
4. Wireshark capture was taken during this period.
5. Backend A was restarted and load balancing resumed.

---

## Files

| File | Contents |
|---|---|
| NAN_phase1_backend_failure_failover.pcapng | Wireshark capture during the backend failure test |
| 01-backend-a-failure.png | Screenshot showing Backend A is unavailable / all requests going to B |
| 02-backend-b-healthy.png | Screenshot confirming Backend B continued serving all requests |
| 03-backend-a-reset.png | Screenshot showing Backend A restarted and load balancing resumed |

---

## What This Demonstrates

### Layer Independence

DNS and the Nginx TLS layer were unaffected when Backend A stopped. The failure was purely at the **application upstream layer** - Nginx could not reach 10.7.20.70:3001 via TCP.

This illustrates:
- DNS failure = name resolution stops (different scenario)
- TCP to Nginx port 443 = still works (Nginx is up)
- TCP from Nginx to Backend A = fails (Backend A is down)
- TCP from Nginx to Backend B = still works (Backend B is up)

### Nginx Passive Health Check

Nginx uses passive health checking by default. When a connection to Backend A is refused (TCP RST), Nginx marks it as temporarily unavailable and routes the next request to Backend B. This is configured via `proxy_next_upstream error timeout` in the nginx config.

### 502 Bad Gateway (both backends down)

If both backends are stopped simultaneously, Nginx can no longer forward requests to any upstream. It returns:

```
HTTP/1.1 502 Bad Gateway
```

This shows the boundary between the edge proxy layer and the application backend layer.

---

## Wireshark Filter for Failure Capture

```
# Show all connections from nginx to backends
(ip.addr == 10.7.29.219 and ip.addr == 10.7.20.70) or
(ip.addr == 10.7.29.219 and ip.addr == 10.7.0.210)

# Show TCP RST packets (connection refused)
tcp.flags.reset == 1
```

Look for TCP RST or connection timeout packets from 10.7.29.219 toward 10.7.20.70:3001 when Backend A is stopped.
