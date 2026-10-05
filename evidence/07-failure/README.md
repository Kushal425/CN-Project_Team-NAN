# Backend Failure Evidence

## Backend Failure / Failover Capture

File:

NAN_phase1_backend_failure_failover.pcapng

This capture records the backend failure test performed on the NAN system.

The architecture contains two backend servers:

Backend A
10.7.20.70:3001

Backend B
10.7.0.210:3002

During the failure test, one backend was made unavailable while requests continued to pass through the Nginx gateway.

The capture can be inspected in Wireshark to observe the network behavior associated with the unavailable upstream and the continued availability of the remaining backend.

Nginx gateway:

10.7.29.219:443

The failure test demonstrates the behavior of the reverse proxy/load-balancing layer when an upstream backend becomes unavailable.

