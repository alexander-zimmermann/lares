---
name: known-log-noise
description: >-
  Registry of known, steady-state log/error patterns in this homelab cluster
  that look like failures but are expected noise. Consult this before flagging
  any recurring log error, 5xx burst, or connection error as abnormal —
  especially during log-anomaly health checks. If an observed pattern matches an
  entry here, treat it as normal noise and report PASS, not an incident.
---

## Known steady-state log noise — do NOT flag as anomalies

Each entry below is a sustained, high-frequency log pattern that is expected
steady-state noise. When an investigation encounters a matching pattern, do not
escalate it; note it as expected and move on.

### kube-apiserver → etcd "operation was canceled"
Shape: `grpc: addrConn.createTransport failed to connect to {Addr: "127.0.0.1:2379" ...}`
`... dial tcp 127.0.0.1:2379: operation was canceled`
- Source: kube-apiserver on all control-plane nodes (talos-cp-01/02/03), ~every 30s, continuous.
- Why it is noise: the apiserver's own etcd clientv3 gRPC balancer churns subchannels to local
  etcd and cancels redundant dials. "operation was canceled" = self-cancelled context, NOT etcd down.
- A real etcd fault looks different: "connection refused" / "context deadline exceeded", etcd
  alarms, or raft lag — and the cluster degrades. Verify via `/healthz/etcd` and
  `talosctl etcd alarm list` before escalating.
- Action: ignore. High volume is expected, not a signal.
