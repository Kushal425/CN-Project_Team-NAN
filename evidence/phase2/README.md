# Phase 2 evidence

Lab run on 23 November 2026. Each packet summary is a filtered export of the adjacent original capture. Packet numbers refer to that capture.

## 01 · Restored baseline

- [Four verified HTTPS replies from both backends](01-restored-baseline/04-client-load-balancing.png)
- [DNS, TCP, and TLS capture](01-restored-baseline/04-dns-tcp-tls.pcapng) · [Selected packets](01-restored-baseline/04-baseline-packets.tsv)

The capture includes the earlier TLS trust troubleshooting and the successful retry traffic. The terminal screenshot shows the verified HTTPS responses.

## 02 · Backup DNS

- [Two resolver addresses entered](02-backup-dns/06-client-two-resolver.png) · [Primary timeout and successful HTTPS](02-backup-dns/06-dns-failover-terminal.png)
- [Backup DNS reply screenshot](02-backup-dns/06-wireshark-backup-answer.png) · [Original capture](02-backup-dns/06-dns-failover.pcapng) · [Selected packets](02-backup-dns/06-dns-failover-packets.tsv)

Frame 8 shows the backup resolver answer from `10.7.26.226`.

## 03 · DNS TTL

- [Initial 60-second TTL](03-dns-ttl/07-ttl-before.png) · [Observed address change](03-dns-ttl/07-ttl-observed-address-change.png)
- [Original capture](03-dns-ttl/07-dns-ttl.pcapng) · [Selected packets](03-dns-ttl/07-dns-ttl-packets.tsv)

The observed comparison was made 145 seconds after the first client lookup. Both resolvers and the client returned the updated address at the later check.

## 04 · Backend isolation

- [Kushal is allowed to reach both backend ports](04-backend-isolation/08-isolation-gateway-allowed.png)
- [Lakshya’s direct requests time out](04-backend-isolation/08-isolation-client-blocked.png)
- [Prachee still receives HTTPS responses from both backends](04-backend-isolation/08-isolation-https-still-works.png)
- [Lakshya’s direct access is restored after rollback](04-backend-isolation/08-isolation-rollback.png)

## 05 · Backend failover

- [Before](05-backend-failover/05-failover-before.png) · [A stopped](05-backend-failover/05-failover-a-stopped.png) · [A recovered](05-backend-failover/05-failover-recovered.png)
- [Wireshark recovery screenshot](05-backend-failover/05-wireshark-backends-recovered.png) · [Original capture](05-backend-failover/05-backend-failover.pcapng) · [Selected packets](05-backend-failover/05-backend-failover-packets.tsv)

Backend A sent resets in frames 90 and 92. Backend B returned HTTP 200 in frame 101. Backend A returned HTTP 200 again in frame 186.

## 06 · Standby edge cutover

- [Standby HTTPS preflight](06-edge-cutover/09-standby-https-preflight.png) · [Primary before cutover](06-edge-cutover/09-cutover-before.png) · [Standby after cutover](06-edge-cutover/09-cutover-after.png) · [Both resolver answers restored](06-edge-cutover/09-cutover-rollback.png)
- [DNS capture](06-edge-cutover/09-dns-cutover.pcapng) · [Selected packets](06-edge-cutover/09-dns-cutover-packets.tsv)

The client recorded the connected IP and the standby’s response header. The before and after requests returned HTTP 200 from the selected gateways.
