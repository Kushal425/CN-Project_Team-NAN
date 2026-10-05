# NAN — TLS / HTTPS Setup

## Overview

The NAN project uses HTTPS to secure all client-to-gateway traffic. TLS is terminated at the Nginx gateway on Mac 2 (10.7.29.219). Backend communication from Nginx to the backends is plain HTTP on the private LAN.

---

## Certificate Authority

A local private CA named **NAN Local CA** was created using OpenSSL.

The CA is used to sign the server certificate. The CA certificate was added to the macOS trust store on all client machines so that `curl` and the browser accept the certificate without warnings.

```
CA Subject: C=IN; ST=West Bengal; L=Kolkata; O=NAN; OU=Phase1; CN=NAN Local CA
```

The CA private key is NOT committed to the repository. Only the public certificate is distributed to clients.

---

## Server Certificate

A server certificate was issued by the NAN Local CA for the Nginx gateway.

```
Subject: C=IN; ST=West Bengal; L=Kolkata; O=NAN; OU=Phase1; CN=app.NAN.test
Issuer:  NAN Local CA
Valid:   Oct 4 2026 - Oct 4 2027
```

### Important Note on SANs

The certificate CN is `app.NAN.test`. When connecting to `api.NAN.test`, modern TLS clients check Subject Alternative Names (SANs), not just the CN. Ensure the certificate includes SANs for both hostnames if a strict client is used:

- `app.NAN.test`
- `api.NAN.test`

If your OpenSSL CSR was generated without a `[alt_names]` extension, you may see a warning for `api.NAN.test` in strict clients. For the demo, verify that `curl -v https://api.NAN.test/` completes with "SSL certificate verify ok."

---

## TLS Configuration in Nginx

```nginx
server {
    listen 443 ssl;
    server_name app.NAN.test api.NAN.test;

    ssl_certificate     /opt/homebrew/etc/nginx/nan-server.crt;
    ssl_certificate_key /opt/homebrew/etc/nginx/nan-server.key;

    ...
}
```

The private key (`nan-server.key`) is stored outside the repository at `/opt/homebrew/etc/nginx/` on the gateway machine and must never be committed.

---

## TLS Handshake (Observed)

From the `curl -v` evidence:

```
* (OUT), TLS handshake, Client hello (1)
* (IN),  TLS handshake, Server hello (2)
* (IN),  TLS handshake, Unknown (8)          <- TLS 1.3 Extensions
* (IN),  TLS handshake, Certificate (11)
* (IN),  TLS handshake, CERT verify (15)
* (IN),  TLS handshake, Finished (20)
* (OUT), TLS handshake, Finished (20)
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
* SSL certificate verify ok.
```

TLS 1.3 reduces the handshake to 1-RTT before application data begins. The cipher `AEAD-CHACHA20-POLY1305-SHA256` provides authenticated encryption.

---

## TLS Termination Model

```
Client <---[TLS 1.3 encrypted]---> Nginx (10.7.29.219:443)
                                         |
                               [plain HTTP on LAN]
                                         |
                              +----------+----------+
                              |                     |
                        Backend A              Backend B
                     10.7.20.70:3001        10.7.0.210:3002
```

The Nginx gateway is the TLS termination point. It decrypts incoming HTTPS traffic and forwards plain HTTP to the backends. This is the standard pattern for reverse proxies and cloud load balancers (e.g., AWS ALB).

---

## Adding the CA to macOS Trust Store

To allow client machines to trust the NAN Local CA without warnings:

```bash
# Copy nan-ca.crt to the client machine, then:
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain nan-ca.crt
```

After adding, verify with:

```bash
curl -v https://app.NAN.test/
# Should show: SSL certificate verify ok.
```

---

## Files

| File | Location | Committed |
|---|---|---|
| nan-ca.crt | tls/ (public CA cert for distribution) | Yes (public only) |
| nan-server.crt | /opt/homebrew/etc/nginx/ on gateway | No (stays on machine) |
| nan-server.key | /opt/homebrew/etc/nginx/ on gateway | NO - private key |
| nan-ca.key | Not in repo | NO - private key |

---

## Security Notes

- Private keys (`.key` files) must never be committed to the repository.
- The `.gitignore` should explicitly exclude `*.key` files.
- The local CA is for demonstration purposes only; it is not trusted by default on any machine outside the team.
