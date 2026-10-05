# NAN — Network Topology

## Network Architecture

The NAN Phase 1 system consists of four macOS machines connected through the same LAN.

```text
                         LAN / Wi-Fi Network
                                |
        +-----------------------+-----------------------+
        |                       |                       |
        v                       v                       v
+---------------+       +---------------+       +---------------+
| DNS Server    |       | Nginx Gateway |       | Backend A     |
|               |       |               |       |               |
| 10.7.3.114    |       | 10.7.29.219   |       | 10.7.20.70    |
| Port 53       |       | 443 / 8080    |       | Port 3001     |
| dnsmasq       |       | Nginx         |       | Python HTTP   |
+---------------+       +-------+-------+       +---------------+
                                |
                                |
                                v
                        +---------------+
                        | Backend B     |
                        |               |
                        | 10.7.0.210    |
                        | Port 3002     |
                        | Python HTTP   |
                        +---------------+

Machines
Role	Machine	IP Address	Port
Nginx / Gateway	Kushal	10.7.29.219	443, 8080
DNS Server	Lakshya	10.7.3.114	53
Backend A	Chinmay	10.7.20.70	3001
Backend B	Prachee	10.7.0.210	3002


Services
DNS
The DNS server runs dnsmasq on:
10.7.3.114:53

It resolves:
app.NAN.test -> 10.7.29.219
api.NAN.test -> 10.7.29.219

Nginx Gateway
Nginx runs on:
10.7.29.219

It provides:
HTTPS: 443
HTTP: 8080

Nginx acts as the reverse proxy and load balancer.
Backend A
10.7.20.70:3001

Backend identifier:
A

Backend B
10.7.0.210:3002

Backend identifier:
B

Traffic Path
Normal application traffic follows:
Client
   |
   | DNS query
   v
DNS Server
10.7.3.114:53
   |
   | app.NAN.test / api.NAN.test
   | -> 10.7.29.219
   v
Nginx Gateway
10.7.29.219:443
   |
   | Reverse Proxy / Load Balancing
   |
   +------------+
   |            |
   v            v
Backend A    Backend B
10.7.20.70   10.7.0.210
:3001        :3002

Failure Scenario
If one backend becomes unavailable, Nginx can continue serving requests through the remaining backend.
Example:
Client
   |
   v
Nginx
   |
   +----X----> Backend A (unavailable)
   |
   +---------> Backend B (available)

The failure scenario was captured and analyzed using Wireshark.
