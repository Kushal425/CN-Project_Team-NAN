# NAN | Private Network Service Platform

Team NAN built and evaluated a four-Mac private network for Computer Networks. Phase 1 established the LAN, DNS, trusted HTTPS, and load-balanced Python backends. Phase 2 added a backup resolver, backend isolation, and controlled migration to a standby edge.

## Submission and live evaluation

| Deliverable | Where to find it |
|---|---|
| Phase 2 final report | [Report PDF](docs/Phase2-Report.pdf) · [Editable source](docs/phase2-report.md) |
| Final presentation | [Presentation PDF](docs/Phase2-Presentation.pdf) · [Editable PowerPoint](docs/Phase2-Presentation.pptx) |
| Architecture | [Phase 2 topology and protocol flow](architecture/phase2-topology.md) |
| Configuration bundle | [Primary DNS](dns/dnsmasq.conf) · [Backup DNS](dns/backup-dnsmasq.conf) · [Primary nginx](nginx/nan.conf) · [Standby nginx](nginx/standby.conf) · [PF rules](firewall/) |
| Startup and demonstration | [Phase 2 runbook](docs/phase2-runbook.md) · [TLS and certificate setup](tls/README.md) |
| Phase 2 results | [Evidence index with screenshots, captures, and frame numbers](evidence/phase2/README.md) |
| Phase 1 submission | [Report](docs/Report.pdf) · [Original topology](architecture/topology.md) · [Original request flow](architecture/request-flow.md) · [Submission notes](docs/submission-notes.md) |

## Team and machine roles

| Member | Phase 1 responsibility | Phase 2 responsibility | November LAN address |
|---|---|---|---|
| Lakshya | Private DNS | Primary resolver, TTL and DNS cutover coordination, isolation client | `10.7.28.77` |
| Kushal | nginx, TLS and load balancing | Primary edge, failover validation, signing the standby certificate | `10.7.2.51` |
| Chinmay | [Backend A](backends/backend-a/server.py) on TCP 3001 | Backup DNS, Backend A isolation and recovery | `10.7.26.226` |
| Prachee | [Backend B](backends/backend-b/server.py) on TCP 3002 | Standby HTTPS, Backend B isolation and client verification | `10.7.2.53` |

The November LAN used `10.7.0.0/19` and gateway `10.7.0.1`. Confirm all addresses before reusing the configs on a different LAN.

## Phase 1 | Build and observe

- Connected four Macs to a private LAN and configured dnsmasq for `app.NAN.test` and `api.NAN.test`.
- Put an nginx edge in front of two Python HTTP backends. TLS terminated at nginx and round-robin upstream selection appeared in the `X-Backend` header.
- Recorded DNS, TCP and TLS traffic in Wireshark. Verified HTTPS, captured HTTP caching headers, and tested the effect of stopping a backend.
- The submitted October configurations are preserved under [dns/phase1](dns/phase1/) and [nginx/phase1](nginx/phase1/).

## Phase 2 | Harden and recover

| Test | Recorded result | Evidence |
|---|---|---|
| Restored baseline | Four verified HTTPS requests returned B, A, B, A. | [01 Baseline](evidence/phase2/01-restored-baseline/) |
| Backup DNS | Primary timed out. Backup answered, and the client's HTTPS request returned 200. | [02 Backup DNS](evidence/phase2/02-backup-dns/) |
| DNS TTL | Both resolvers advertised a 60-second TTL, and the client later used the updated address. | [03 DNS TTL](evidence/phase2/03-dns-ttl/) |
| Backend isolation | The gateway reached both backend ports. Lakshya's direct requests timed out during the test and succeeded after rollback. | [04 Isolation](evidence/phase2/04-backend-isolation/) |
| Backend failover | Six of six HTTPS requests succeeded through B while A was stopped. Both backends served again after restart. | [05 Failover](evidence/phase2/05-backend-failover/) |
| Edge cutover | `app.NAN.test` moved from the primary to the standby and returned 200 over verified HTTPS. DNS was then restored. | [06 Edge cutover](evidence/phase2/06-edge-cutover/) |

During team troubleshooting, a missing CA trust path caused curl error 60. Supplying the public NAN CA resolved the error. The live evaluation includes a faculty-injected fault and an individual viva for each team member.

## Before the live demo

1. Connect the four Macs to the same LAN and confirm the IPs.
2. Start both Python backends, primary nginx, both DNS resolvers, and standby nginx.
3. From the demo client, run the preflight checks after configuring both team DNS servers and obtaining the public CA.

```sh
bash scripts/verify.sh "$HOME/Downloads/nan-ca.crt"
```

Use the [11-step demonstration sequence](docs/phase2-runbook.md#demonstration-order) and keep the [packet evidence](evidence/phase2/README.md) open.
