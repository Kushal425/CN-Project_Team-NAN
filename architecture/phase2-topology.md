# NAN Phase 2 topology

All devices used the same LAN on 23 November 2026. The subnet was `10.7.0.0/19`, the gateway was `10.7.0.1`, and each Mac used `en0`.

```mermaid
flowchart TD
    C["HTTPS client"]
    DP["Lakshya / Primary DNS / 10.7.28.77"]
    DB["Chinmay / Backup DNS / 10.7.26.226"]
    E["Kushal / Primary edge / 10.7.2.51"]
    S["Prachee / Standby edge / 10.7.2.53"]
    A["Chinmay / Backend A"]
    B["Prachee / Backend B"]
    C -->|"DNS 53"| DP
    C -.->|"DNS 53 when primary is down"| DB
    C -->|"HTTPS 443 in normal operation"| E
    C -.->|"HTTPS 443 after app cutover"| S
    E -->|"HTTP 3001"| A
    E -->|"HTTP 3002"| B
    S -.->|"HTTP 3001"| A
    S -.->|"HTTP 3002 over loopback"| B
```

Both resolvers normally answer with the primary edge IP. The test moved only `app.NAN.test` to standby and kept `api.NAN.test` on the primary. During the isolation test, PF allowed direct access to the backend ports from Kushal’s edge. The team restored direct access before testing the standby edge.

[Deployment inventory and demonstration](../docs/phase2-runbook.md) · [Packet and terminal evidence](../evidence/phase2/README.md)
