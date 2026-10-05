# NAN — Request Flow (Phase 1)

## Overview

This document traces the complete journey of a single client request through the NAN network stack, from DNS resolution to backend response. Every protocol layer is mapped to the OSI/TCP-IP model.

---

## Full Request Flow Diagram

```
Client Machine (Mac 1 / Mac 4)
  |
  | 1. DNS Query  (UDP, port 53)
  |    "What is the IP for app.NAN.test?"
  v
DNS Server  10.7.3.114:53  (dnsmasq)
  |
  | 2. DNS Response  (UDP, port 53)
  |    "app.NAN.test -> 10.7.29.219"
  v
Client (now knows the destination IP)
  |
  | 3. TCP SYN  (port 443)
  |    Source: <client ephemeral port>
  |    Destination: 10.7.29.219:443
  v
Nginx Gateway  10.7.29.219:443
  |
  | 4. TCP SYN-ACK  (three-way handshake completes)
  |
  | 5. TLS Handshake
  |    ClientHello -> ServerHello -> Certificate -> Key Exchange -> Finished
  |    Cipher: TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
  |
  | 6. Encrypted HTTP/1.1 Request  (inside TLS tunnel)
  |    GET / HTTP/1.1
  |    Host: app.NAN.test
  |
  | 7. Load Balancing Decision  (round-robin)
  |    +--> Request N   -> Backend A  10.7.20.70:3001  (TCP)
  |    +--> Request N+1 -> Backend B  10.7.0.210:3002  (TCP)
  |
  | 8. HTTP Response from chosen backend
  |    200 OK
  |    X-Backend: A  (or B)
  |    Cache-Control: max-age=60  (on /api/status)
  |
  | 9. Nginx forwards response to client inside TLS tunnel
  v
Client receives encrypted HTTP response, decrypts, renders result.
```

---

## Step-by-Step Protocol Breakdown

### Step 1 - DNS Resolution

| Field | Value |
|---|---|
| Protocol | DNS over UDP |
| Source port | Client ephemeral (e.g., 54321) |
| Destination port | 53 |
| DNS server | 10.7.3.114 |
| Query | app.NAN.test A record |
| Response | 10.7.29.219 (TTL 0 - immediate) |
| Layer | Application (DNS) over Transport (UDP) over Network (IP) |

The client's OS queries the configured DNS resolver (10.7.3.114). dnsmasq responds with the static address= mapping. The client does NOT connect directly to any backend - it only learns the IP of the Nginx gateway.

---

### Step 2 - TCP Three-Way Handshake

| Field | Value |
|---|---|
| Protocol | TCP |
| Client to Server | SYN (seq=X) |
| Server to Client | SYN-ACK (seq=Y, ack=X+1) |
| Client to Server | ACK (ack=Y+1) |
| Destination port | 443 |
| Source port | Ephemeral (>1024, assigned by OS) |

This handshake establishes the reliable connection before any application data or TLS is exchanged. The sequence numbers in Wireshark confirm TCP's reliable delivery mechanism.

---

### Step 3 - TLS 1.3 Handshake

| Message | Direction | Purpose |
|---|---|---|
| ClientHello | Client to Server | Proposes TLS versions, cipher suites, SNI extension |
| ServerHello | Server to Client | Selects TLS 1.3, CHACHA20-POLY1305 cipher |
| Certificate | Server to Client | Sends nan-server.crt (CN=app.NAN.test, issuer=NAN Local CA) |
| CertVerify | Server to Client | Proves possession of the private key |
| Finished | Both | Confirms handshake integrity; session keys established |

After Finished, all subsequent data is encrypted. The HTTP payload is not visible in Wireshark - only the TLS record headers.

Certificate Details:
- Subject: C=IN; ST=West Bengal; L=Kolkata; O=NAN; OU=Phase1; CN=app.NAN.test
- Issuer: NAN Local CA
- TLS version: TLSv1.3
- Cipher: AEAD-CHACHA20-POLY1305-SHA256

---

### Step 4 - HTTP/1.1 Request (inside TLS)

```
GET /api/status HTTP/1.1
Host: api.NAN.test
User-Agent: curl/8.7.1
Accept: */*
```

The request is encrypted within the TLS record. In Wireshark, this appears as Application Data - the protocol identifier is visible but the payload is not.

---

### Step 5 - Nginx Load Balancing

Nginx receives the decrypted request and selects an upstream backend using round-robin:

```nginx
upstream nan_backends {
    server 10.7.20.70:3001;   # Backend A
    server 10.7.0.210:3002;   # Backend B
}
```

Nginx opens a plain HTTP (TCP) connection to the chosen backend. The client never knows which backend IP it is talking to - Nginx is the only visible endpoint.

---

### Step 6 - HTTP Response from Backend

```
HTTP/1.1 200 OK
Content-Type: text/plain
Cache-Control: max-age=60
X-Backend: A
Content-Length: 21

Backend A is healthy
```

The X-Backend header identifies which backend processed the request. The Cache-Control: max-age=60 header tells clients (and intermediate caches) the response is valid for 60 seconds.

---

## OSI Layer Mapping

| OSI Layer | Layer Name | Protocol in Use | Where |
|---|---|---|---|
| 7 | Application | DNS, HTTP/1.1 | dnsmasq, backend Python servers, nginx |
| 6 | Presentation | TLS 1.3 (encryption/decryption) | nginx (TLS termination) |
| 5 | Session | TLS session establishment | nginx <-> client |
| 4 | Transport | TCP (port 443, 3001, 3002) / UDP (port 53) | all machines |
| 3 | Network | IPv4 (10.7.x.x addressing) | Wi-Fi LAN router |
| 2 | Data Link | Ethernet / Wi-Fi frames (802.11) | Wi-Fi NIC |
| 1 | Physical | Radio waves (Wi-Fi) | Wi-Fi access point |

---

## Ports in Use

| Service | Protocol | Port | Machine |
|---|---|---|---|
| DNS | UDP | 53 | 10.7.3.114 (Lakshya) |
| HTTPS (nginx) | TCP | 443 | 10.7.29.219 (Kushal) |
| HTTP fallback (nginx) | TCP | 8080 | 10.7.29.219 (Kushal) |
| Backend A | TCP | 3001 | 10.7.20.70 (Chinmay) |
| Backend B | TCP | 3002 | 10.7.0.210 (Prachee) |

---

## Cache Behavior

The /api/status endpoint returns Cache-Control: max-age=60. This means:

- A fresh cache hit: Client serves the response from local cache without sending a new request (within 60 seconds).
- A conditional request (304): After 60 seconds, client re-validates using If-None-Match (ETag) or If-Modified-Since. If unchanged, server returns 304 with no body.
- A full new request (200): Cache has expired or been flushed; full round-trip occurs.

---

## Failure Scenario: One Backend Down

```
Client -> DNS -> 10.7.29.219:443 (nginx)
                     |
                     +----X---> Backend A (10.7.20.70:3001) STOPPED
                     |
                     +--------> Backend B (10.7.0.210:3002) still serving
```

When Backend A is stopped, Nginx detects the failed connection and routes all subsequent requests to Backend B. DNS resolution is unaffected - the problem is at the application layer, not the DNS or TCP layer.

If both backends are stopped, Nginx returns 502 Bad Gateway - the edge is reachable but cannot forward the request.
