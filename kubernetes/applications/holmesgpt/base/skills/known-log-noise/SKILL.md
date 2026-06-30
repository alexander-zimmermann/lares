---
name: known-log-noise
description: >-
  Decide whether a recurring log/error pattern (repeated connection or gRPC
  errors, 5xx bursts, probe failures, "connection refused" / "operation was
  canceled") is a known benign steady-state pattern in this homelab cluster
  rather than a real incident. Use this whenever a log scan or anomaly check
  surfaces a recurring error, BEFORE concluding an application is failing: it
  lists the patterns that are expected noise and how to confirm each is still
  behaving benignly.
---

## Goal

Classify a recurring log/error pattern as either known-benign steady-state
noise (→ expected, report PASS) or a genuine anomaly (→ escalate). Prevent
false alarms on patterns that look like failures but are normal in this cluster.

## Workflow

1. Identify the pattern precisely: source app/namespace, the literal error
   string, frequency (how often) and duration (how long).
2. Match it against the **Known-benign catalog** below.
3. If it matches an entry, run that entry's **Confirm** check — a benign pattern
   can occasionally coincide with a real fault, so verify it is still behaving
   as expected.
4. If the Confirm check passes → expected noise. If it fails, or the pattern
   matches nothing in the catalog → treat it as a real anomaly.

## Known-benign catalog

### kube-apiserver → etcd "operation was canceled"
- Pattern: `grpc: addrConn.createTransport failed to connect to {Addr: "127.0.0.1:2379" ...}`,
  ending in `operation was canceled` / `context canceled` /
  `authentication handshake failed: context canceled`, W-level, on all
  control-plane nodes (talos-cp-01/02/03), ~every 30s, continuous.
- Why benign: the apiserver's own etcd clientv3 gRPC balancer cancels redundant
  dials. "operation was canceled" is a self-cancelled context, not etcd down.
- Confirm still benign: `talosctl etcd status` shows all members at the same
  RAFT index with a stable leader and no alarms; apiserver pods Running with no
  restarts; `/readyz` passes. A real fault instead shows `connection refused` /
  `context deadline exceeded`, etcd alarms, or raft lag, and the cluster degrades.

### Transient readiness/liveness probe failures during a rollout
- Pattern: `Readiness probe failed: ... context deadline exceeded` or
  `Liveness/Readiness probe failed: ... connect: connection refused`, clustered
  around a Deployment rollout.
- Why benign: expected rollout churn — the OLD pod failing readiness while it
  terminates, or the NEW pod before its port is open. Events cluster at the
  rollout timestamp and stop once the new pod reports Ready.
- Confirm still benign: the new ReplicaSet's pod is now Ready and the failures
  have stopped. A pod that keeps failing probes after the rollout settles, is
  CrashLooping, or a Deployment that never reaches Available is NOT this — escalate.

### ArgoCD application-controller "DiffFromCache: cache: key is missing"
- Pattern: `DiffFromCache error: error getting managed resources for app <name>: cache: key is missing`,
  error-level, from `argocd-application-controller-0` (gitops-controller), low
  rate but recurring across many apps over hours.
- Why benign: ArgoCD's managed-resources diff cache (in argocd-redis) misses or
  expires entries (TTL/eviction); the controller falls back to a live diff and
  logs the miss at error level. Apps still reconcile correctly.
- Confirm still benign: `argocd-redis` and `argocd-application-controller-0` are
  Running with no recent restarts/OOM, AND every ArgoCD Application is
  Synced + Healthy (the live-diff fallback works). A real fault instead shows
  apps going OutOfSync/Unknown, redis CrashLooping/OOM, or a high and rising
  miss rate.

### kube-controller-manager CronJob "the object has been modified"
- Pattern: `"Unhandled Error" err="error syncing CronJobController <ns>/<name>: Operation cannot be fulfilled on cronjobs.batch ...: the object has been modified"`,
  error-level, every ~5-10 min across multiple CronJobs.
- Why benign: optimistic-concurrency retry — the CronJob controller updates
  `.status` while another writer (e.g. an ArgoCD reconcile) touches the same
  object; the controller logs the conflict and requeues, succeeding on retry.
  The cadence tracks the CronJob schedules.
- Confirm still benign: the affected CronJobs still fire on schedule
  (`.status.lastScheduleTime` advancing, their Jobs completing). A real fault
  would be a tight hot-loop (many conflicts per second on one object) or
  CronJobs that stop scheduling — neither is this.

### solaredge2mqtt "Unreadable register" at night
- Pattern: `ERROR | solaredge2mqtt.services.modbus:_read_from_modbus:... - Unreadable register <n>`
  (e.g. 40071), every ~5s on both solaredge2mqtt pods, during night / no-production hours.
- Why benign: the SolarEdge inverter (SE3680H) stops serving its production registers
  when it is not generating (night), so the poller logs the register as unreadable. It
  reads normally again once production resumes at sunrise.
- Confirm still benign: the errors are confined to no-production hours AND the app logs
  successful reads during daylight (e.g. `_map_inverter ... AC <n> W`); pods are not
  restarting. Escalate if "Unreadable register" occurs during daytime production, the
  app stops publishing powerflow, or the pods CrashLoop.

## Synthesize findings

- Matched + Confirm passes → report the pattern as expected steady-state noise;
  do not raise an incident for it.
- Matched + Confirm fails, or no catalog match → a real recurring anomaly;
  report it with the application, namespace and one representative line.

## Recommended remediation

- Confirmed benign noise: none. Note it as expected and move on.
- Pattern that fails its Confirm check or is unknown: escalate via the normal
  investigation flow (identify the owning workload, recent changes/rollouts,
  correlated events and metrics).
