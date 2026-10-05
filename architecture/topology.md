# NAN - Network Topology

## Overview

The NAN Phase 1 system consists of four macOS machines connected on the same private Wi-Fi / LAN segment. Each machine takes a dedicated network role.

---

## Machine Roles and IP Table

| Role | Team Member | IP Address | Port(s) | Software |
|---|---|---|---|---|
| Nginx Gateway / Reverse Proxy | Kushal | 10.7.29.219 | 443, 8080 | nginx |
| DNS Server | Lakshya | 10.7.3.114 | 53 | dnsmasq |
| Backend A | Chinmay | 10.7.20.70 | 3001 | Python HTTP |
| Backend B | Prachee | 10.7.0.210 | 3002 | Python HTTP |

---

## Network Diagram

```
                    Wi-Fi / LAN  (private subnet  10.7.0.0/16 approx)
                                        |
         +--------------+---------------+--------------+--------------+
         |              |               |              |              |
         v              v               v              v              v
   [Wi-Fi Router]  [DNS Server]  [Nginx Gateway]  [Backend A]  [Backend B]
                   10.7.3.114    10.7.29.219       10.7.20.70   10.7.0.210
                   Port 53       Port 443 / 8080   Port 3001    Port 3002
                   dnsmasq       nginx              Python HTTP  Python HTTP
                   Lakshya       Kushal             Chinmay      Prachee
```

---

## DNS Records

The DNS server resolves private .test domain names:

```
app.NAN.test  ->  10.7.29.219  (Nginx Gateway)
api.NAN.test  ->  10.7.29.219  (Nginx Gateway)
```

Clients configure their DNS resolver to 10.7.3.114 to use the project DNS server.

---

## Services Running on Each Machine

### Mac 1 - DNS Server (Lakshya)

- Software: dnsmasq
- Listen: 10.7.3.114:53 (UDP/TCP)
- Config: dns/dnsmasq.conf
- Role: Authoritative resolver for *.NAN.test zone
- Cloud equivalent: AWS Route 53 / GCP Cloud DNS

### Mac 2 - Nginx Gateway (Kushal)

- Software: nginx
- Listen: 10.7.29.219:443 (HTTPS / TLS terminated)
- Listen: 10.7.29.219:8080 (HTTP fallback)
- Config: nginx/nan.conf
- Role: Reverse proxy, TLS termination, load balancer
- Cloud equivalent: AWS ALB / GCP Load Balancer / CDN edge node

### Mac 3 - Backend A (Chinmay)

- Software: Python (http.server)
- Listen: 0.0.0.0:3001
- Source: backends/backend-a/server.py
- Role: Application backend instance A
- Identifier: X-Backend: A

### Mac 4 - Backend B (Prachee)

- Software: Python (http.server)
- Listen: 0.0.0.0:3002
- Source: backends/backend-b/server.py
- Role: Application backend instance B; also acts as test client
- Identifier: X-Backend: B

---

## Traffic Flow: Normal Request

```
Client (Mac 1 or Mac 4)
    |
    |  UDP port 53 - DNS query "app.NAN.test?"
    v
DNS Server (10.7.3.114)
    |
    |  DNS response: "10.7.29.219"
    v
Client knows the gateway IP
    |
    |  TCP SYN -> 10.7.29.219:443
    v
Nginx Gateway (10.7.29.219:443)
    |
    |  TLS handshake (TLSv1.3)
    |  Encrypted HTTP/1.1 request received
    |
    |  Round-robin load balancing
    |
    +---[odd requests]--->  Backend A (10.7.20.70:3001) via plain HTTP
    |
    +---[even requests]-->  Backend B (10.7.0.210:3002) via plain HTTP
    |
    |  Backend HTTP response (X-Backend: A or B)
    |
    |  Nginx re-encrypts and returns to client
    v
Client receives 200 OK inside TLS tunnel
```

---

## Traffic Flow: Backend Failure

```
Client -> DNS -> 10.7.29.219:443 (Nginx)
                      |
                      +---X---> Backend A (STOPPED - connection refused)
                      |
                      +-------> Backend B (still healthy - serves all requests)
```

When Backend A is stopped, Nginx continues serving requests through Backend B only. DNS and TLS are unaffected.

When both backends are stopped:
```
Client -> DNS -> 10.7.29.219:443 (Nginx)
                      |
                      +---X---> Backend A (STOPPED)
                      +---X---> Backend B (STOPPED)
                      |
                      Nginx returns: 502 Bad Gateway
```

---

## Cloud Architecture Equivalents

| Local Component | Cloud Equivalent |
|---|---|
| dnsmasq DNS server | AWS Route 53 / GCP Cloud DNS |
| Nginx on Mac 2 | AWS ALB / GCP HTTP(S) Load Balancer |
| Backend A (Mac 3) | EC2 instance / GCP Compute Engine VM |
| Backend B (Mac 4) | EC2 instance / GCP Compute Engine VM |
| Private LAN | AWS VPC / GCP VPC |
| Self-signed CA | AWS Certificate Manager / GCP Certificate Manager |

---

## Protocol Stack Reference

| Layer | Protocol | Used For |
|---|---|---|
| Application (L7) | DNS, HTTP/1.1 | Name resolution, web requests |
| Presentation (L6) | TLS 1.3 | Encryption at nginx edge |
| Session (L5) | TLS session | Key exchange, cipher negotiation |
| Transport (L4) | TCP, UDP | Reliable streams (TCP), DNS queries (UDP) |
| Network (L3) | IPv4 | Routing between 10.7.x.x addresses |
| Data Link (L2) | 802.11 Wi-Fi | Frame delivery on LAN |
| Physical (L1) | Wi-Fi radio | Bit transmission |
