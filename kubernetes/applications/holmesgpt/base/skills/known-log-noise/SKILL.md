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

### kube-apiserver → prometheus-operator admission webhook, "failing open"
- Pattern: `Failed calling webhook, failing open prometheusrulemutate.monitoring.coreos.com:
  ... Post "https://prometheus-operator.prometheus.svc:443/admission-prometheusrules/mutate?timeout=10s":
  context deadline exceeded` (or `connect: connection refused`), W-level from
  `dispatcher.go:210`, each one echoed as an E-level `dispatcher.go:214
  "Unhandled Error"`. Short bursts of seconds on one kube-apiserver pod, not continuous.
- Why benign: the three `prometheus-admission` webhooks are `failurePolicy: Ignore`,
  and the apiserver states the outcome itself — "failing open". prometheus-operator
  runs a single replica, so while it restarts (chart upgrade, node drain, eviction)
  its Service has no endpoint and in-flight PrometheusRule / AlertmanagerConfig
  admissions time out. The object is still admitted; nothing is rejected or lost.
- Confirm still benign: the bursts coincide with a prometheus-operator restart or
  rollout (recent `startedAt` / Unhealthy event on
  `-n prometheus -l app.kubernetes.io/name=prometheus-operator`) and stopped once it
  went Ready; PrometheusRules still reconcile. A real fault instead keeps erroring
  while the operator is stable and Ready (Service/NetworkPolicy/serving-cert problem),
  CrashLoops the operator, or leaves rules never reaching Prometheus.

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

### Isolated liveness/readiness probe blips on a stable pod (no rollout)
- Pattern: a low count of `Unhealthy` events (`Liveness/Readiness probe failed:
  ... context deadline exceeded`) incrementing slowly (single digits over many
  hours) on a pod that is NOT rolling out — e.g. authentik-server. The pod stays
  `1/1 Ready`, does not restart, and the app logs show the health route 200-ing.
- Why benign: an occasional kubelet→pod probe is delayed past its short timeout
  by a transient node/CNI/scheduling hiccup, so the kubelet records one Unhealthy
  event. The failures are isolated (never failureThreshold in a row), so the pod
  never restarts and the endpoint itself is healthy. authentik probes use a 3s
  timeout / failureThreshold 3 → 30s of continuous failure is required to restart.
- Confirm still benign: the pod is Ready with NO restart in the window
  (`restartCount` unchanged, `state.running.startedAt` older than the window),
  the Unhealthy `count` rises only by single digits over hours (not a burst), and
  the app logs show health 200s (`kubectl logs … | grep '/-/health/' | grep -v
  '"status": 200'` is empty; max runtime ≪ the probe timeout). A real fault
  instead restarts the pod (`restartCount` climbing), CrashLoops, flaps the
  Service endpoints, or logs 5xx/timeouts on the health route.

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

### Loki querier ↔ query-scheduler "EOF" / "context canceled"
- Pattern: `error notifying scheduler about finished query" err=EOF` and
  `error processing requests from scheduler err="rpc error: code = Canceled
  desc = context canceled"`, error-level, from `loki-0` (loki namespace),
  recurring every few seconds while queries are running.
- Why benign: normal query lifecycle. When a query finishes or its client
  (Grafana, HolmesGPT) disconnects/cancels, the querier's gRPC stream to the
  in-process query-scheduler closes and Loki logs that close as EOF /
  context-canceled at error level — the query itself still succeeded. The rate
  tracks query volume, so HolmesGPT's own scheduled Loki scans amplify it, and
  it falls silent when query load is idle.
- Confirm still benign: `loki-0` is Running with no recent restarts/OOM and
  queries still return results (Grafana Explore or the Holmes loki toolset
  answer normally). A real fault instead shows client-facing 5xx/timeouts,
  `panic`, rejected writes (`too many outstanding requests`), or the pod
  CrashLooping.

### Loki results-cache "SERVER_ERROR out of memory storing object"
- Pattern: `caller=background.go:202 msg="backgroundCache writeBackLoop Cache.Store fail"
  err="server=<ip>:11211: memcache: unexpected response line from \"set\":
  \"SERVER_ERROR out of memory storing object\""`, **warn**-level, from `loki-0`
  (loki namespace), a few hundred lines per day, arriving in short bursts roughly
  hourly rather than continuously.
- Why benign: `loki-results-cache` is a deliberately fixed-size memcached (`-m 256`
  in a 307Mi pod, max item size `-I 5m`). When the matching slab class holds nothing
  evictable, memcached refuses the `set`. This is the asynchronous write-back path —
  the query result has already been returned to the client, so a refused store only
  means the next identical query is a cache miss served from the object store.
  Nothing fails and nothing is lost.
- Confirm still benign: the lines are warn-level and on the write-back path
  (`background.go` / `Cache.Store fail`), `loki-0` and `loki-results-cache-0` are
  Running with no restarts or OOMKills, and queries still return normally. A real
  fault instead shows the memcached pod OOMKilled/CrashLooping, cache errors on the
  read path or at error level, or client-facing query 5xx/timeouts.

### rustfs `disk_local_background_cleanup` ESTALE / NotFound on `deleted_objects`
- Pattern: `{"level":"ERROR","message":"Disk local background cleanup failed",
  "event":"disk_local_background_cleanup","subsystem":"disk_local",
  "task":"deleted_objects","error":"Io(Os { code: 116, kind: StaleNetworkFileHandle`
  — and the same line with `code: 2, kind: NotFound` — from the single `rustfs`
  pod, a handful of lines per day on a roughly hourly GC pass.
- Why benign: the deleted-objects GC races other paths (scanner, heal, an earlier
  GC pass) that already removed the entry. On the NFS-backed PVC a handle to a
  file the server has already unlinked returns ESTALE; when the lookup instead
  happens after the dentry is gone, the same race returns ENOENT. Two errno values
  alternating on one task is that race — a genuinely stale mount fails
  consistently, not a subset of passes. The removal is idempotent, so nothing is
  left behind.
- Confirm still benign: the mount is usable — `kubectl exec -n rustfs
  deploy/rustfs -c rustfs -- stat -f /data` reports type nfs with free blocks, and
  touch/rm under `/data` succeed — drive health is intact
  (`rustfs_cluster_health_drives_offline_count` 0,
  `rustfs_cluster_erasure_set_{read,write}_health` 1), and the nightly CNPG
  backups complete. Restarts on this pod are OOMKills from the tracked memory
  regression, so check `lastState.terminated.reason` before reading them as
  storage trouble. A real fault instead shows drives going offline/FaultyDisk,
  `InsufficientWriteQuorum` or 5xx on the S3 path, ESTALE on the read/write paths
  rather than only the GC task, or errors on every pass.

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
