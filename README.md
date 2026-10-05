<div align="center">

# 🌐 NAN — Private Network Service Platform

### Computer Networks · Phase 1 · Build & Observe

[![Phase](https://img.shields.io/badge/Phase-1%20Complete-22c55e?style=for-the-badge)](.)
[![TLS](https://img.shields.io/badge/TLS-1.3-3b82f6?style=for-the-badge)](.)
[![DNS](https://img.shields.io/badge/DNS-dnsmasq-f59e0b?style=for-the-badge)](.)
[![Proxy](https://img.shields.io/badge/Proxy-nginx-009639?style=for-the-badge&logo=nginx)](.)
[![Backends](https://img.shields.io/badge/Backends-2%20×%20Python-3776ab?style=for-the-badge&logo=python)](.)

</div>

---

> **The application stays simple — the network is the project.**
>
> NAN is a fully local, four-machine distributed service platform built on a private Wi-Fi LAN. A client types a private domain name, resolves it through a team-owned DNS server, establishes an encrypted HTTPS connection through an Nginx reverse proxy, and receives a response from one of two Python backend servers — every packet captured and explained.

---

## 📋 Table of Contents

- [Team & Machines](#-team--machines)
- [Network Architecture](#-network-architecture)
- [Request Flow](#-request-flow)
- [Configuration Files](#-configuration-files)
- [Services & Endpoints](#-services--endpoints)
- [HTTPS / TLS](#-https--tls)
- [Load Balancing](#-load-balancing)
- [HTTP Caching](#-http-caching)
- [Evidence & Captures](#-evidence--captures)
- [Failure Scenarios](#-failure-scenarios)
- [Pre-Demo Checklist](#-pre-demo-checklist)
- [Project Structure](#-project-structure)
- [Security](#-security)

---

## 👥 Team & Machines

| # | Role | Team Member | IP Address | Port(s) | Software |
|---|---|---|---|---|---|
| Mac 1 | 🔵 DNS Server | **Lakshya** | `10.7.3.114` | `53` | dnsmasq |
| Mac 2 | 🟢 Nginx Gateway | **Kushal** | `10.7.29.219` | `443`, `8080` | nginx + TLS |
| Mac 3 | 🟠 Backend A | **Chinmay** | `10.7.20.70` | `3001` | Python HTTP |
| Mac 4 | 🔴 Backend B | **Prachee** | `10.7.0.210` | `3002` | Python HTTP |

---

## 🗺️ Network Architecture

```
                    ┌─────────────────────────────────────────────────┐
                    │           Private Wi-Fi / LAN Network           │
                    └──────────┬──────────┬────────────┬──────────────┘
                               │          │            │
                  ┌────────────▼──┐  ┌────▼──────┐  ┌─▼───────────┐
                  │  DNS Server   │  │  Backend A │  │  Backend B  │
                  │  Lakshya      │  │  Chinmay   │  │  Prachee    │
                  │  10.7.3.114   │  │ 10.7.20.70 │  │ 10.7.0.210  │
                  │  Port 53      │  │  Port 3001 │  │  Port 3002  │
                  │  dnsmasq      │  │  Python    │  │  Python     │
                  └──────┬────────┘  └─────▲──────┘  └─────▲───────┘
                         │                 │                │
                         │          ┌──────┴────────────────┴──────┐
                         │          │       Nginx Gateway           │
                         │          │       Kushal                  │
                         │          │       10.7.29.219             │
                         │          │       Port 443 / 8080         │
                         │          │       nginx + TLS 1.3         │
                         │          └───────────────┬───────────────┘
                         │                          │
                  ┌──────▼──────────────────────────▼──────┐
                  │           Client Machine               │
                  │    (Mac 1 / Mac 4 — curl / browser)    │
                  └────────────────────────────────────────┘
```

**Cloud Equivalents:**

| Local Component | AWS Equivalent | GCP Equivalent |
|---|---|---|
| dnsmasq (Mac 1) | Route 53 Private Hosted Zone | Cloud DNS |
| Nginx (Mac 2) | Application Load Balancer | HTTP(S) Load Balancer |
| Backend A (Mac 3) | EC2 Instance | Compute Engine VM |
| Backend B (Mac 4) | EC2 Instance | Compute Engine VM |
| Private LAN | VPC | VPC Network |

---

## 🔄 Request Flow

A single `curl https://app.NAN.test/` touches every layer of the stack:

```
Client
  │
  │ ① DNS Query — UDP port 53
  │   "What is the IP for app.NAN.test?"
  ▼
DNS Server  10.7.3.114:53
  │
  │ ② DNS Response — "10.7.29.219"  (TTL 0)
  ▼
Client now knows the gateway IP
  │
  │ ③ TCP SYN → 10.7.29.219:443  (three-way handshake)
  ▼
Nginx Gateway  10.7.29.219:443
  │
  │ ④ TLS 1.3 Handshake
  │   ClientHello → ServerHello → Certificate → Finished
  │   Cipher: AEAD-CHACHA20-POLY1305-SHA256
  │
  │ ⑤ Encrypted HTTP/1.1 Request (inside TLS tunnel)
  │   GET /api/status HTTP/1.1
  │
  │ ⑥ Round-Robin Load Balancing
  ├──[odd]──▶  Backend A  10.7.20.70:3001  (plain HTTP on LAN)
  └──[even]─▶  Backend B  10.7.0.210:3002  (plain HTTP on LAN)
  │
  │ ⑦ Backend returns:
  │   200 OK · X-Backend: A (or B) · Cache-Control: max-age=60
  │
  │ ⑧ Nginx re-encrypts and returns to client inside TLS
  ▼
Client — 200 OK received
```

> Full protocol breakdown with OSI layer mapping: [`architecture/request-flow.md`](architecture/request-flow.md)

---

## 📁 Configuration Files

| File | Purpose |
|---|---|
| [`dns/dnsmasq.conf`](dns/dnsmasq.conf) | dnsmasq — private DNS records + upstream forwarders |
| [`nginx/nan.conf`](nginx/nan.conf) | Nginx — reverse proxy, load balancer, TLS termination |
| [`backends/backend-a/server.py`](backends/backend-a/server.py) | Backend A — Python HTTP server on port 3001 |
| [`backends/backend-b/server.py`](backends/backend-b/server.py) | Backend B — Python HTTP server on port 3002 |
| [`tls/README.md`](tls/README.md) | TLS setup, CA details, cert info, trust store instructions |
| [`architecture/topology.md`](architecture/topology.md) | Full network topology with cloud equivalents |
| [`architecture/request-flow.md`](architecture/request-flow.md) | Step-by-step protocol flow with OSI mapping |
| [`docs/submission-notes.md`](docs/submission-notes.md) | Task completion status and pre-demo checklist |

---

## 🔌 Services & Endpoints

### DNS Records

```
app.NAN.test  ──▶  10.7.29.219  (Nginx Gateway)
api.NAN.test  ──▶  10.7.29.219  (Nginx Gateway)
```

Verified with:
```bash
dig app.NAN.test @10.7.3.114
dig api.NAN.test @10.7.3.114
```

### Backend Endpoints

| Endpoint | Backend A (`10.7.20.70:3001`) | Backend B (`10.7.0.210:3002`) |
|---|---|---|
| `GET /` | `Backend A` | `Backend B` |
| `GET /api/status` | `Backend A is healthy` | `Backend B is healthy` |
| Response header | `X-Backend: A` | `X-Backend: B` |
| Cache header | `Cache-Control: max-age=60` | `Cache-Control: max-age=60` |

---

## 🔒 HTTPS / TLS

TLS is terminated at the Nginx gateway. Backends communicate with Nginx over plain HTTP on the private LAN.

```
Client ◄──── TLS 1.3 encrypted ────► Nginx (10.7.29.219:443)
                                           │
                                  plain HTTP on LAN
                                           │
                               ┌───────────┴───────────┐
                          Backend A               Backend B
                       10.7.20.70:3001         10.7.0.210:3002
```

| Property | Value |
|---|---|
| TLS Version | TLSv1.3 |
| Cipher Suite | AEAD-CHACHA20-POLY1305-SHA256 |
| Certificate CN | `app.NAN.test` |
| Certificate Issuer | `NAN Local CA` |
| Valid | Oct 4 2026 – Oct 4 2027 |

The **NAN Local CA** certificate is added to the macOS trust store on all client machines, so `curl` and the browser accept the certificate without any warnings — no `-k` flag needed.

```bash
# Verified clean TLS — no -k flag
curl -v https://app.NAN.test/
# ✓  SSL certificate verify ok.
```

> Full TLS documentation: [`tls/README.md`](tls/README.md)

---

## ⚖️ Load Balancing

Nginx distributes requests between Backend A and Backend B using **round-robin** (default).

```bash
for i in {1..12}; do
    echo -n "Request $i: "
    curl -sk https://app.NAN.test/ -D - -o /dev/null | grep X-Backend
done
```

**Observed result** (12 requests, perfect alternation):

```
Request 1:  X-Backend: B
Request 2:  X-Backend: A
Request 3:  X-Backend: B
Request 4:  X-Backend: A
Request 5:  X-Backend: B
Request 6:  X-Backend: A
...
```

> Evidence: [`evidence/04-load-balancing/load-balancing.txt`](evidence/04-load-balancing/load-balancing.txt)

---

## 🗄️ HTTP Caching

The `/api/status` endpoint responds with `Cache-Control: max-age=60`, demonstrating HTTP cache behavior.

```bash
curl -sI https://api.NAN.test/api/status
```

```
HTTP/1.1 200 OK
Server: nginx/1.31.6
Content-Type: text/plain
Cache-Control: max-age=60
X-Backend: A
```

| Cache State | Behavior |
|---|---|
| **Fresh hit** (< 60s) | Client serves from local cache — no network request |
| **Conditional (304)** | Client re-validates with `If-None-Match`; server returns 304 with no body |
| **Full request (200)** | Cache expired or flushed — full round-trip to backend |

> Evidence: [`evidence/05-cache/cache-control.txt`](evidence/05-cache/cache-control.txt)

---

## 📡 Evidence & Captures

| # | Evidence | Location |
|---|---|---|
| 1 | LAN connectivity — direct backend access | [`evidence/01-lan/`](evidence/01-lan/) |
| 2 | DNS resolution — `dig` output for both domains | [`evidence/02-dns/`](evidence/02-dns/) |
| 3 | HTTPS / TLS — `curl -v` with full handshake trace | [`evidence/03-https/`](evidence/03-https/) |
| 4 | Load balancing — 12-request round-robin log + screenshot | [`evidence/04-load-balancing/`](evidence/04-load-balancing/) |
| 5 | HTTP caching — `Cache-Control` headers + screenshot | [`evidence/05-cache/`](evidence/05-cache/) |
| 6 | Wireshark — DNS, TCP handshake, TLS handshake, port captures | [`evidence/06-wireshark/`](evidence/06-wireshark/) |
| 7 | Failure scenario — backend down, failover, reset | [`evidence/07-failure/`](evidence/07-failure/) |

### Wireshark Captures

| File | Contains |
|---|---|
| `NAN-phase1-dns-capture.pcapng` | DNS query/response for `app.NAN.test` |
| `NAN_phase1_baseline_traffic.pcapng` | Full system: DNS + TCP + TLS + HTTP |
| `NAN_phase1_backend_failure_failover.pcapng` | Backend A down, failover to B |

**Key Wireshark filters:**
```
dns                     # DNS query and response
tcp.flags.syn == 1      # TCP three-way handshake
tls.handshake           # TLS ClientHello, ServerHello, Certificate
tcp.port == 443         # All HTTPS traffic
tcp.flags.reset == 1    # TCP RST packets (connection refused)
```

> See [`evidence/06-wireshark/README.md`](evidence/06-wireshark/README.md) for a full guide.

---

## 💥 Failure Scenarios

Phase 1 requires demonstrating controlled failures to prove layer independence.

| Scenario | Expected Result | Layer Affected |
|---|---|---|
| Wrong DNS resolver on client | Name resolution fails; direct IP still works | DNS (L7 Application) |
| DNS record points to wrong IP | DNS succeeds; TCP connection to wrong host fails | DNS + Network (L3) |
| One backend stopped | Nginx routes all traffic to the remaining backend | Application upstream |
| Both backends stopped | Nginx returns `502 Bad Gateway` | Application upstream |
| Wrong destination port | TCP `Connection refused`; host is still reachable | Transport (L4) |

> Failure evidence: [`evidence/07-failure/`](evidence/07-failure/)
> Demo commands: [`scripts/failure-demo.sh`](scripts/failure-demo.sh)

---

## ✅ Pre-Demo Checklist

Run the automated verification script before the evaluation:

```bash
bash scripts/verify.sh
```

Manual checks:

- [ ] All four machines on the same Wi-Fi
- [ ] dnsmasq running on `10.7.3.114` (Lakshya)
- [ ] Nginx running on `10.7.29.219` (Kushal)
- [ ] Backend A running on `10.7.20.70:3001` (Chinmay)
- [ ] Backend B running on `10.7.0.210:3002` (Prachee)
- [ ] Client DNS resolver set to `10.7.3.114`
- [ ] NAN Local CA in client trust store (no `-k` needed)
- [ ] `dig app.NAN.test` returns `10.7.29.219`
- [ ] `curl -v https://app.NAN.test/` returns `SSL certificate verify ok.`
- [ ] `X-Backend` alternates A/B in repeated requests
- [ ] Wireshark captures loaded and ready to present

---

## 📂 Project Structure

```
cn-phase1/
│
├── README.md                          ← this file
│
├── architecture/
│   ├── topology.md                    ← network diagram, IP table, cloud equivalents
│   └── request-flow.md               ← step-by-step protocol flow, OSI mapping
│
├── backends/
│   ├── backend-a/
│   │   └── server.py                 ← Backend A (port 3001)
│   └── backend-b/
│       └── server.py                 ← Backend B (port 3002)
│
├── dns/
│   └── dnsmasq.conf                  ← dnsmasq config with .NAN.test records
│
├── nginx/
│   └── nan.conf                      ← reverse proxy, load balancer, TLS config
│
├── tls/
│   ├── README.md                     ← TLS setup, cert details, CA instructions
│   └── nan-server.crt                ← public server certificate (safe to commit)
│
├── scripts/
│   ├── verify.sh                     ← pre-demo automated checks
│   └── failure-demo.sh               ← failure scenario commands
│
├── docs/
│   └── submission-notes.md           ← task completion status, checklist
│
└── evidence/
    ├── 01-lan/                        ← LAN connectivity proof
    ├── 02-dns/                        ← DNS resolution output
    ├── 03-https/                      ← TLS handshake and HTTPS verification
    ├── 04-load-balancing/             ← round-robin load balancing log + screenshot
    ├── 05-cache/                      ← Cache-Control header demonstration
    ├── 06-wireshark/                  ← Wireshark captures + screenshots
    └── 07-failure/                    ← backend failure and failover evidence
```

---

## 🔐 Security

> [!CAUTION]
> The following files contain private cryptographic material and must **never** be committed to this repository.

| File | Location on Machine | Status |
|---|---|---|
| `nan-server.key` | `/opt/homebrew/etc/nginx/` on Kushal's Mac | ❌ Not committed |
| `nan-ca.key` | Lakshya's Mac (CA machine) | ❌ Not committed |
| `nan-server.crt` | `tls/nan-server.crt` | ✅ Public cert — safe |

The `.gitignore` excludes all `*.key` and `*.pem` files.

---

## 📚 Technologies

`macOS` · `Python 3` · `nginx` · `dnsmasq` · `OpenSSL` · `TLS 1.3` · `curl` · `dig` · `Wireshark` · `TCP/IP` · `DNS` · `HTTP/1.1` · `HTTPS` · `REST`

---

<div align="center">

**Team NAN** · Computer Networks Phase 1 · 2026

*Lakshya · Kushal · Chinmay · Prachee*

</div>
