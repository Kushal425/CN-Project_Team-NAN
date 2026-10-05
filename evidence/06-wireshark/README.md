# Wireshark Evidence — NAN Phase 1

## Files

| File | Contents |
|---|---|
| NAN-phase1-dns-capture.pcapng | DNS query/response for app.NAN.test and api.NAN.test |
| NAN_phase1_baseline_traffic.pcapng | Full system baseline: DNS + TCP + TLS + HTTP through nginx |
| 01-dns-resolution.png | Screenshot: DNS query and A-record response in Wireshark |
| 02-https-tls-traffic.png | Screenshot: TLS handshake packets (ClientHello, ServerHello, Certificate) |
| 03-mixed-port-filter.png | Screenshot: Traffic filtered by port (53, 443, 3001, 3002) |
| backend-B-port-3002-api-status.png | Screenshot: nginx-to-Backend-B TCP traffic on port 3002 |

---

## What to Look for in the Captures

### DNS Resolution (NAN-phase1-dns-capture.pcapng)

Wireshark filter: `dns`

You should see:
1. A DNS Standard query (type A) from the client to 10.7.3.114:53 for `app.NAN.test`
2. A DNS Standard query response with answer `10.7.29.219` (TTL 0)

This proves the private DNS server is resolving the .NAN.test domain correctly.

Key fields to explain:
- Source IP: client machine
- Destination IP: 10.7.3.114 (DNS server / Lakshya)
- Protocol: DNS over UDP
- Port: 53
- Answer section: app.NAN.test A 10.7.29.219

---

### TCP Three-Way Handshake

Wireshark filter: `tcp.flags.syn == 1 && tcp.port == 443`

You should see:
1. SYN from client to 10.7.29.219:443
2. SYN-ACK from 10.7.29.219:443 to client
3. ACK from client to 10.7.29.219:443

Key fields to explain:
- Sequence numbers (ISN in SYN)
- Acknowledgement numbers
- Ephemeral source port (client, >1024)
- Well-known destination port (443)

---

### TLS Handshake (NAN_phase1_baseline_traffic.pcapng)

Wireshark filter: `tls.handshake`

You should see:
1. Client Hello - client advertises supported TLS versions and cipher suites
2. Server Hello - server selects TLS 1.3 and CHACHA20-POLY1305
3. Certificate - server sends nan-server.crt
4. Certificate Verify - server proves private key ownership
5. Finished (both directions) - handshake complete

After Finished, all subsequent packets appear as `Application Data` (encrypted). The HTTP payload is NOT visible, which proves encryption is working.

TLS version observed: TLSv1.3
Cipher: AEAD-CHACHA20-POLY1305-SHA256

---

### HTTP Headers

Use `curl -v` output rather than Wireshark for HTTP headers, since the payload is encrypted.

The curl evidence in evidence/03-https/https-tls.txt shows:
- Request: GET / HTTP/1.1, Host: app.NAN.test
- Response: HTTP/1.1 200 OK, X-Backend: B (or A), Cache-Control: max-age=60

---

### Port Identification Summary

| Traffic | Source Port | Destination Port | Protocol |
|---|---|---|---|
| DNS query | Client ephemeral | 53 | UDP |
| DNS response | 53 | Client ephemeral | UDP |
| HTTPS client to nginx | Client ephemeral | 443 | TCP |
| Nginx to Backend A | Nginx ephemeral | 3001 | TCP |
| Nginx to Backend B | Nginx ephemeral | 3002 | TCP |

---

## Wireshark Filters Reference

```
# DNS traffic only
dns

# All HTTPS traffic
tcp.port == 443

# TCP three-way handshake (SYN packets)
tcp.flags.syn == 1

# TLS handshake messages
tls.handshake

# Traffic from/to DNS server
ip.addr == 10.7.3.114

# Traffic from/to nginx gateway
ip.addr == 10.7.29.219

# Backend A traffic
ip.addr == 10.7.20.70

# Backend B traffic
ip.addr == 10.7.0.210

# Show all project traffic
ip.addr == 10.7.3.114 or ip.addr == 10.7.29.219 or ip.addr == 10.7.20.70 or ip.addr == 10.7.0.210
```
