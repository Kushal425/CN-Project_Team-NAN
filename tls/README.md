# NAN TLS and HTTPS

The client verifies the requested hostname at the nginx edge. nginx terminates TLS and connects to the Python backends over plain HTTP on the private LAN.

| Edge | Phase 2 listener | Certificate and key |
|---|---|---|
| Kushal, primary | `10.7.2.51:443` | `/opt/homebrew/etc/nginx/nan-server.crt` and `nan-server.key` |
| Prachee, standby | `10.7.2.53:443` | `standby.crt` and `standby.key` beside the standby nginx config |

The original NAN Local CA signed both certificates. Each server certificate covers `app.NAN.test` and `api.NAN.test`. The standby generated its private key on Prachee’s Mac and sent a certificate signing request to Kushal. Kushal signed that request and returned the public standby certificate.

## Client setup

1. Obtain the public `nan-ca.crt` from the team’s CA owner and compare its SHA-256 fingerprint.
2. Pass the CA directly to the demo client:

   ```sh
   openssl x509 -in "$HOME/Downloads/nan-ca.crt" -noout -fingerprint -sha256
   curl --noproxy '*' --cacert "$HOME/Downloads/nan-ca.crt" \
     -v https://app.NAN.test/api/status
   ```

3. For the standby preflight, add `--resolve app.NAN.test:443:10.7.2.53`. For the DNS cutover test, omit that option and record the address the client actually reached with `-w '\nConnected IP: %{remote_ip}\n'`.

For browser demonstrations, import the public test CA into the demo client’s trust store as appropriate for that machine. Keep the CA signing key and both edge private keys out of the repository.

## Evidence and configuration

- [Primary nginx](../nginx/nan.conf) and [standby nginx](../nginx/standby.conf)
- [TLS packet summary](../evidence/phase2/01-restored-baseline/04-baseline-packets.tsv) and [standby HTTPS preflight](../evidence/phase2/06-edge-cutover/09-standby-https-preflight.png)
- [Phase 1 TLS setup and evidence](../docs/Report.pdf)
