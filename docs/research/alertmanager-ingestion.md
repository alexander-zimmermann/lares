# Getting non-Prometheus events into Alertmanager

Research note for [lares#1592](https://github.com/alexander-zimmermann/lares/issues/1592).

Scope: house anomalies (a room too humid, an appliance left on) produced by a Python
service, which can stay open for days. Cluster runs kube-prometheus-stack; Alertmanager
today has two Pushover receivers and is fed only by Prometheus rules
(`kubernetes/applications/prometheus/base/values.yaml`).

All version-specific statements were checked against `main` of the upstream repositories
on 2026-08-30.

---

## TL;DR

There are exactly **two** ways an event can enter Alertmanager, plus one way to avoid
entering it directly:

| Path | Direction | What the sender must do |
| --- | --- | --- |
| `POST /api/v2/alerts` | inbound | Re-send the alert on a timer, forever, until it is over |
| Webhook receiver | **outbound only** | Nothing — this is Alertmanager → you, not you → Alertmanager |
| Exporter + scrape + alerting rule | inbound, via Prometheus | Expose a gauge; Prometheus owns the alert lifecycle |

The "webhook ingestion" idea does not exist in Alertmanager. `webhook_config` is a
*notification* integration ([`docs/integrations.md`][am-integrations],
[`webhook_config`][cfg-webhook]). Anything on the internet that "receives a webhook and
turns it into an alert" is a third-party adapter that then does `POST /api/v2/alerts`
itself.

Recommendation for this use case: **exporter + alerting rule** (see
[Recommendation](#recommendation)).

---

## 1. Path A — the alerts API (`POST /api/v2/alerts`)

### The API

APIv2 is the only alert API. "APIv1 was deprecated in Alertmanager version 0.16.0 and
removed in Alertmanager version 0.27.0." ([`docs/alerts_api.md`][alerts-api])

`POST api/v2/alerts`, `Content-Type: application/json`, body is a JSON **array**
([`docs/alerts_api.md`][alerts-api]):

```json
[
  {
    "labels": { "alertname": "<required_value>", "<name>": "<value>" },
    "annotations": { "<name>": "<value>" },
    "startsAt": "<RFC3339>",
    "endsAt": "<RFC3339>",
    "generatorURL": "<value>"
  }
]
```

Only `labels` is required by the OpenAPI schema; `startsAt`, `endsAt`, `annotations`
and `generatorURL` are optional ([`api/v2/openapi.yaml`][openapi], `postableAlert`).
Server-side validation additionally requires at least one label pair and
`endsAt >= startsAt` ([`alert/alert.go`][alert-go], `func (a *Alert) Validate`).

"Labels are used to deduplicate identical instances of the same alert, while annotations
are used to include other information about the alert, such as a summary, description or
a URL to a runbook." ([`docs/alerts_api.md`][alerts-api]) — i.e. **the label set is the
identity of the alert**. Two POSTs with the same labels are the same alert; changing any
label creates a different one.

### Timestamp semantics (this is the whole game)

From [`api/v2/api.go`][api-go] (`postAlertsHandler`) and [`docs/alerts_api.md`][alerts-api]:

- `startsAt` omitted → set to now (or to `endsAt` if only `endsAt` was given).
- `endsAt` omitted → `Timeout = true` and `endsAt = now + global.resolve_timeout`.
- On re-POST, the stored alert is *merged*: the earliest `startsAt` wins; a later
  `endsAt` wins only if it is **not** a timeout-derived one
  ([`alert/alert.go`][alert-go], `func (a *Alert) Merge`).
- "Firing alerts are resolved once their `endsAt` timestamp has elapsed."
  ([`docs/alerts_api.md`][alerts-api])

`resolve_timeout` defaults to `5m` and is set to `5m` explicitly in this repo. The config
docs state it plainly: "ResolveTimeout is the default value used by alertmanager if the
alert does not include EndsAt, after this time passes it can declare the alert as
resolved if it has not been updated. This has no impact on alerts from Prometheus, as
they always include EndsAt." ([`configuration.md`][cfg-global])

### What this implies for the sender

The upstream doc is explicit and this is the load-bearing constraint for a days-long
house situation ([`docs/alerts_api.md`][alerts-api]):

> Clients are expected to re-send firing alerts to the Alertmanager at regular intervals
> until the alert is resolved.
>
> [...]
>
> To ensure resolved notifications are sent for resolved alerts, clients are also
> expected to re-send resolved alerts to the Alertmanager for up to 5 minutes after the
> alert has resolved. As the Alertmanager is stateless, this ensures that a resolved
> notification is sent even if the Alertmanager crashes or is restarted.

So the Python service becomes a **heartbeat**: it must POST every anomaly that is still
true, on a timer shorter than `resolve_timeout` (or set an explicit `endsAt` in the
future and refresh it). If the service is down longer than that window, Alertmanager
declares the anomaly resolved and (with `send_resolved: true`, the Pushover default)
fires a false "resolved" push, followed by a fresh "firing" push when the service comes
back. Two spurious notifications per outage.

The same doc leads with a warning against this path in general:

> **Important**: Prometheus takes care of sending alerts to the Alertmanager. It is
> recommended to configure alerting rules in Prometheus based on time series data instead
> of sending alerts to the Alerts API, as Prometheus supports a number of special cases
> to make sure alerts are delivered even if Alertmanager crashes or restarts.
> ([`docs/alerts_api.md`][alerts-api])

The concepts page frames these client duties the same way: "The Alertmanager has special
requirements for behavior of its client. Those are only relevant for advanced use cases
where Prometheus is not used to send alerts." ([Alertmanager concepts][am-concepts])

`amtool alert add` is the first-party CLI client for the same endpoint, bundled with
every Alertmanager release ([`README.md`][am-readme]) — useful for manual testing.

In-cluster endpoint here would be the operator-created Service referenced in
`prometheusSpec.alerting`: `prometheus-alertmanager` in namespace `prometheus`, port name
`web` = 9093 (kube-prometheus-stack `alertmanager.service.port: 9093`
[values.yaml][kps-values]).

---

## 2. Path B — webhook receiver (not an ingestion path)

`webhook_config` makes Alertmanager **send** an HTTP POST to an endpoint you run:

> The webhook receiver allows configuring a generic receiver. [...] The Alertmanager will
> send HTTP POST requests in the following JSON format to the configured endpoint
> ([`webhook_config`][cfg-webhook])

with `version`, `groupKey`, `status`, `receiver`, `groupLabels`, `commonLabels`,
`commonAnnotations`, `externalURL`, `notification_reason` and an `alerts[]` array
carrying `status`, `labels`, `annotations`, `startsAt`, `endsAt`, `generatorURL`,
`fingerprint`.

Relevant knobs: `send_resolved` (default `true`), `max_alerts` (default `0` = all),
`timeout` (default `0s`; "This will have no effect if set higher than the
`group_interval`") ([`webhook_config`][cfg-webhook]).

This is the right tool if the Python service (or KNX bridge) wants to *consume* alert
state — e.g. drive a KNX anomaly GA from Alertmanager's firing/resolved lifecycle. It is
not a way in.

---

## 3. Path C — exporter → Prometheus scrape → alerting rule

The service exposes `/metrics` with a gauge per anomaly, Prometheus scrapes it, a
`PrometheusRule` turns it into an alert. A `Gauge` is the documented type for exactly
this: "A Gauge tracks a value that can go up and down. Use it for things you sample at a
point in time." ([prometheus/client_python][client-python])

The rule then owns the lifecycle. `for` "causes Prometheus to wait for a certain duration
between first encountering a new expression output vector element and counting an alert
as firing"; `keep_firing_for` "tells Prometheus to keep this alert firing for the
specified duration after the firing condition was last met"
([alerting rules][prom-alerting-rules]).

What Prometheus does for you that a hand-rolled poster must reimplement
([`rules/alerting.go`][rules-alerting], [`rules/manager.go`][rules-manager],
[`cmd/prometheus/main.go`][prom-main]):

- resends every `--rules.alert.resend-delay`, **default `1m`**;
- always sets `EndsAt`: `alert.ValidUntil = ts.Add(4 * max(interval, resendDelay))` for a
  firing alert, or the real resolve time once resolved — so `resolve_timeout` never
  applies and the alert always has ~4 evaluation intervals of headroom;
- restores `for` state across Prometheus restarts
  (`--rules.alert.for-outage-tolerance`, default `1h`;
  `--rules.alert.for-grace-period`, default `10m`).

Auto-resolve comes for free: if the anomaly disappears from the exported metric set,
"this time series will be marked as stale" and "no value is returned for that time
series" ([staleness][prom-staleness]), so the rule stops firing and Alertmanager gets a
proper resolved alert.

**Do not use the Pushgateway for this.** "We only recommend using the Pushgateway in
certain limited cases [...] the only valid use case for the Pushgateway is for capturing
the outcome of a service-level batch job", and "The Pushgateway never forgets series
pushed to it and will expose them to Prometheus forever unless those series are manually
deleted" ([pushing practices][prom-pushing]). A stuck anomaly gauge would alert forever.

Repo-specific: Prometheus here runs an opt-in model — `serviceMonitorSelector`,
`podMonitorSelector` and `scrapeConfigSelector` all require `release: prometheus`
(`kubernetes/applications/prometheus/base/values.yaml`). A new exporter needs a
`ServiceMonitor` carrying that label. Note also that `iot-insights-engine` is currently
all CronJobs (`*/15 * * * *` and friends) — a scraped exporter needs a long-lived
Deployment holding the current anomaly set, not a cron pod.

---

## 4. How the Alertmanager machinery treats API-posted alerts

Everything downstream of ingestion is label-based and **source-agnostic**. Grouping,
inhibition, silencing, muting and repeat all operate on the label set; nothing in the
pipeline distinguishes a Prometheus alert from an API-posted one.

### Grouping

`group_by` selects labels off the alert; labels the alert does not carry are simply
absent from the group key ([`dispatch/dispatch.go`][dispatch], `getGroupLabels`).

**Consequence for this repo:** the root route is
`group_by: ["alertname", "job"]`. An API-posted house anomaly has no `job` label, so its
group key is `{alertname}` only — *every* anomaly sharing an `alertname` collapses into
one group and one notification. To get per-room / per-appliance notifications, either
group by the anomaly's own labels (e.g. `group_by: [alertname, room, device]` on a
dedicated sub-route) or give the alerts distinct `alertname`s.

Timers ([`<route>`][cfg-route]):

- `group_wait` (default `30s`, repo: `30s`) — "How long to wait before sending the first
  notification for a new group of alerts." Also: "If an alert is resolved before
  `group_wait` has elapsed, no notification will be sent for that alert."
- `group_interval` (default `5m`, repo: `1m`) — recurring timer; at each tick
  Alertmanager notifies if alerts were added or resolved. It also "sets the context
  timeout for the notification pipeline for each send".
- `repeat_interval` (default `4h`, repo: `6h`) — "How long to wait before repeating the
  last notification. [...] Since the `repeat_interval` is checked after each
  `group_interval`, it should be a multiple of the `group_interval`. If it's not, the
  `repeat_interval` is rounded up to the next multiple of the `group_interval`."

### repeat_interval over days

For an anomaly open for days, `repeat_interval: 6h` means a Pushover re-nag every 6h for
as long as it stays open. That is a per-route setting, so a dedicated house-anomaly
sub-route can pick its own (e.g. `24h`), inherited fields coming from the parent
([`<route>`][cfg-route]).

One sharp edge, documented in the same section: "if `repeat_interval` is longer then
`--data.retention`, the notification will be repeated at the end of the data retention
period instead." `--data.retention` defaults to `120h` (5 days)
([`cmd/alertmanager/main.go`][am-main]); the operator's `AlertmanagerSpec.retention`
defaults to `120h` ([prometheus-operator API][pop-api]) and kube-prometheus-stack ships
`retention: 120h` ([values.yaml][kps-values]). This repo does not override it. So any
`repeat_interval` above 5 days silently becomes ~5 days.

### Inhibition

"An inhibition rule mutes an alert (target) matching a set of matchers when an alert
(source) exists that matches another set of matchers. Both target and source alerts must
have the same label values for the label names in the `equal` list."
([`<inhibit_rule>`][cfg-inhibit])

Works on API-posted alerts unchanged, and cross-source: a Prometheus alert can inhibit a
house anomaly and vice versa, as long as the `equal` labels line up. Note the semantics
that bite when hand-crafting label sets: "Semantically, a missing label and a label with
an empty value are the same thing. Therefore, if all the label names listed in `equal`
are missing from both the source and target alerts, the inhibition rule will apply."
There are currently no `inhibit_rules` in this repo's config.

### Silencing

"Silences are a straightforward way to simply mute alerts for a given time. A silence is
configured based on matchers, just like the routing tree. Incoming alerts are checked
whether they match all the equality or regular expression matchers of an active silence.
If they do, no notifications will be sent out for that alert."
([Alertmanager concepts][am-concepts])

Fully available for API-posted alerts. Create via the UI, `amtool silence add`
([`README.md`][am-readme]), or `POST /api/v2/silences`, which requires `matchers`,
`startsAt`, `endsAt`, `createdBy` and `comment` ([`api/v2/openapi.yaml`][openapi],
`silence` definition). A silence is exactly the right tool for "yes, I know the cellar is
humid, shut up until Sunday" — it does not resolve the alert, it mutes notification.
Silences outlive restarts (snapshot file, see below) and are garbage-collected only once
they "have ended longer than the configured retention time ago"
([`silence/silence.go`][silence-go], `func (s *Silences) GC`).

Also available and useful for a house: `mute_time_intervals` / `active_time_intervals` on
a route, e.g. no appliance nags between 23:00 and 07:00 ([`<route>`][cfg-route]).

### Ending an alert (resolve)

Three mechanisms, in order of preference:

1. **Explicit resolve** — re-POST the same label set with `endsAt` set to now (or the
   past). "Firing alerts are resolved once their `endsAt` timestamp has elapsed."
   ([`docs/alerts_api.md`][alerts-api]) Keep re-sending the resolved alert for up to
   5 minutes afterwards, per the client expectations above.
2. **Timeout** — stop re-sending; the alert resolves `resolve_timeout` after the last
   POST. This is the implicit path, and it is indistinguishable from "the sender died".
3. **Rule stops firing** (Path C) — Prometheus sends `EndsAt = ResolvedAt`
   ([`rules/manager.go`][rules-manager], `SendAlerts`).

The notification itself: Alertmanager notifies on all-resolved regardless of the
receiver's `send_resolved` flag, in order to clear the notification log — but only the
receivers with `send_resolved: true` actually deliver a message
([`notify/dedup_stage.go`][dedup], `needsUpdate`: "Notify about all alerts being resolved.
This is done irrespective of the `send_resolved` flag to make sure that the firing alerts
are cleared from the notification log.").

---

## 5. Restart behaviour — the part that matters for days-long alerts

**Alerts are not persisted.** The only alert provider is the in-memory one
([`app/app.go`][app-go] → `mem.NewAlerts(...)`), and the source says so directly:
"As we don't persist alerts, we no longer consider them after they are resolved. Alerts
waiting for resolved notifications are held in memory in aggregation groups redundantly."
([`provider/mem/mem.go`][mem-go]). Garbage collection runs every
`--alerts.gc-interval`, default `30m` ([`cmd/alertmanager/main.go`][am-main]).

**Silences and the notification log are persisted.** Both are snapshotted to
`<--storage.path>/silences` and `<--storage.path>/nflog` ([`app/app.go`][app-go]), on a
`--data.maintenance-interval` ticker (default `15m`, "Interval between garbage collection
and snapshotting to disk of the silences and the notification logs",
[`cmd/alertmanager/main.go`][am-main]) **and once more on shutdown**
([`nflog/nflog.go`][nflog], `Maintenance` runs a final `doMaintenance` after the stop
signal). This repo already gives Alertmanager a Longhorn PVC
(`alertmanagerSpec.storage.volumeClaimTemplate`), which is what makes that snapshot
survive a pod restart.

So, on an Alertmanager restart with a house anomaly open for three days:

| Path | What happens |
| --- | --- |
| A (alerts API) | The alert **vanishes** until the Python service POSTs again. Worst case, the gap is one full send interval. If Alertmanager is down longer than the sender's retry window, nothing is lost as long as the sender keeps retrying. If the *sender* is what restarts, and the gap exceeds `resolve_timeout`, the anomaly false-resolves. |
| C (rule) | Prometheus re-sends within `--rules.alert.resend-delay` (1m) on its own, with no cooperation needed. |

Either way there is **no duplicate notification storm** after a restart, because the
notification log survives: when the group re-forms with the same firing set and the
repeat interval has not elapsed, the dedup stage returns `ReasonDoNotNotify`
([`notify/dedup_stage.go`][dedup]). The exception is the retention boundary — nflog
entries expire after `--data.retention` (`expiresAt := now.Add(l.retention)`,
[`nflog/nflog.go`][nflog]), which is the mechanism behind the documented
"`repeat_interval` longer than `--data.retention`" behaviour.

There is one more failure mode worth naming: if Alertmanager crashes hard (no clean
shutdown) more than 15 minutes after the last maintenance tick, the nflog snapshot is
stale and a repeat notification may be sent early. Annoying, not lossy.

---

## 6. Mail receiver

`email_config` fields ([`<email_config>`][cfg-email]); anything not set per-receiver falls
back to the `global.smtp_*` defaults ([`configuration.md`][cfg-global]):

- `to` — required; "Allows a comma separated list of rfc5322 compliant email addresses."
- `from` / `global.smtp_from` — required in practice.
- `smarthost` / `global.smtp_smarthost` — `host:port`.
- `hello` / `global.smtp_hello` — default `"localhost"`.
- Auth: `auth_username` + one of `auth_password{,_file}` (LOGIN/PLAIN) or
  `auth_secret{,_file}` (CRAM-MD5). "If empty, Alertmanager doesn't authenticate to the
  SMTP server. PLAIN is only supported when using TLS."
- `require_tls` / `global.smtp_require_tls` — **default `true`**. With it true and no
  implicit TLS, Alertmanager errors out if the smarthost does not advertise STARTTLS:
  `"'require_tls' is true (default) but %q does not advertise the STARTTLS extension"`
  ([`notify/email/email.go`][email-go]).
- `force_implicit_tls` — default `nil` = auto-detect by port (465 implicit, otherwise
  explicit) ([`<email_config>`][cfg-email], and `useImplicitTLS = Port == "465"` in
  [`notify/email/email.go`][email-go]).
- `html` — defaults to the built-in `email.default.html` template; `text` is optional.
- `send_resolved` — **default `false` for email**, unlike almost every other integration
  (webhook, Pushover, Slack: `true`). For a house anomaly you almost certainly want
  `send_resolved: true`.
- `threading.enabled` (default `false`) — keeps one alert group in one mail thread.

Repo-specific: there is already an in-cluster relay,
`smtprelay.smtprelay.svc.cluster.local:25`, used without auth or TLS by the HolmesGPT
alert bridge (`kubernetes/applications/holmesgpt/base/alert-bridge-cronjob.yaml`).
Pointing Alertmanager at it therefore needs `require_tls: false`, otherwise the STARTTLS
check above fails. Sender address must respect the existing iCloud constraint
(`admin@zimmermann.sh` for prod).

---

## 7. Severity-based routing to different receivers

Standard, first-class, and configuration-only — not hand-rolled. Routing is a tree of
label matchers; the canonical upstream example routes by label to different pagers
([`<route>` example][cfg-route]):

```yaml
route:
  receiver: 'default-receiver'
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  group_by: [cluster, alertname]
  routes:
  - receiver: 'database-pager'
    group_wait: 10s
    matchers:
    - service=~"mysql|cassandra"
  - receiver: 'frontend-pager'
    group_by: [product, environment]
    matchers:
    - team="frontend"
```

`severity` itself is a convention, not a built-in: it is an ordinary rule label. The
upstream alerting-rules example uses `severity: page` ([alerting rules][prom-alerting-rules]),
and this repo already labels every rule `severity: critical|warning`
(`kubernetes/applications/prometheus/base/prometheus-rule.yaml`) — the current
Alertmanager route just ignores it and sends everything to one Pushover receiver.

Mechanics to know:

- Each route may set `matchers`, its own `receiver`, and override any inherited timer.
- `continue: false` (default) stops at the first matching sibling — so order matters, and
  a `severity="critical"` route must sit above a catch-all.
- `continue: true` fans one alert out to several receivers (e.g. Pushover *and* mail for
  critical).

Kubernetes-native alternative: the Prometheus Operator's `AlertmanagerConfig` CRD lets an
app ship its own routes/receivers from its own namespace, selected via
`alertmanagerConfigSelector` ([prometheus-operator API][pop-api]). kube-prometheus-stack
ships `alertmanagerConfigSelector: {}` ([values.yaml][kps-values]) and this repo does not
enable it, so today all routing lives in the single inline `alertmanager.config`.

---

## Recommendation

**Use Path C: a long-lived exporter plus a `PrometheusRule`.** Reasons, in order of
weight:

1. **The days-long lifetime is the deciding factor.** Path A makes the Python service
   permanently responsible for a heartbeat; every deploy, OOM, or node drain longer than
   `resolve_timeout` (5m) produces a false "resolved" Pushover push and then a duplicate
   "firing" one. With Path C, Prometheus is the heartbeat, and it is already
   HA-configured, restart-tolerant and running.
2. **Upstream says so.** "It is recommended to configure alerting rules in Prometheus
   based on time series data instead of sending alerts to the Alerts API, as Prometheus
   supports a number of special cases to make sure alerts are delivered even if
   Alertmanager crashes or restarts." ([`docs/alerts_api.md`][alerts-api])
3. **Free liveness.** A scrape target gives `up`, so "the anomaly detector itself is
   down" becomes an alert rather than silence — which Path A cannot express at all.
4. **Free auto-resolve** via staleness ([staleness][prom-staleness]), instead of an
   explicit `endsAt` POST the service might miss.
5. **It fits the repo.** Opt-in `ServiceMonitor` with `release: prometheus`, rules in
   `prometheus-rule.yaml`, thresholds and `for:` reviewable in Git rather than embedded in
   Python.

Cost: `iot-insights-engine` is CronJob-only today, so this needs a small long-lived
Deployment that holds the current anomaly set as gauges (reading it from TimescaleDB or
NATS). That is the real work. Do **not** substitute a Pushgateway
([pushing practices][prom-pushing]).

Choose Path A only if a long-lived process is genuinely unacceptable. If so: set an
explicit `endsAt` well in the future (hours, not `resolve_timeout`), refresh it on every
detector run, POST an explicit `endsAt = now` to resolve, and repeat that resolve POST
for 5 minutes ([`docs/alerts_api.md`][alerts-api]).

Whichever path: give house anomalies their own sub-route with its own `group_by` (the
current `["alertname", "job"]` will collapse them all into one notification), its own
`repeat_interval`, and — if mail is wanted — a `severity`-matched receiver with
`send_resolved: true` and `require_tls: false` against the in-cluster smtprelay.

---

## Sources

All primary. Upstream repository files were read at `main`.

[alerts-api]: https://github.com/prometheus/alertmanager/blob/main/docs/alerts_api.md
[openapi]: https://github.com/prometheus/alertmanager/blob/main/api/v2/openapi.yaml
[api-go]: https://github.com/prometheus/alertmanager/blob/main/api/v2/api.go
[alert-go]: https://github.com/prometheus/alertmanager/blob/main/alert/alert.go
[mem-go]: https://github.com/prometheus/alertmanager/blob/main/provider/mem/mem.go
[app-go]: https://github.com/prometheus/alertmanager/blob/main/app/app.go
[am-main]: https://github.com/prometheus/alertmanager/blob/main/cmd/alertmanager/main.go
[nflog]: https://github.com/prometheus/alertmanager/blob/main/nflog/nflog.go
[silence-go]: https://github.com/prometheus/alertmanager/blob/main/silence/silence.go
[dedup]: https://github.com/prometheus/alertmanager/blob/main/notify/dedup_stage.go
[dispatch]: https://github.com/prometheus/alertmanager/blob/main/dispatch/dispatch.go
[email-go]: https://github.com/prometheus/alertmanager/blob/main/notify/email/email.go
[am-readme]: https://github.com/prometheus/alertmanager/blob/main/README.md
[am-integrations]: https://github.com/prometheus/alertmanager/blob/main/docs/integrations.md
[am-concepts]: https://prometheus.io/docs/alerting/latest/alertmanager/
[cfg-global]: https://prometheus.io/docs/alerting/latest/configuration/#configuration-file
[cfg-route]: https://prometheus.io/docs/alerting/latest/configuration/#route
[cfg-inhibit]: https://prometheus.io/docs/alerting/latest/configuration/#inhibit_rule
[cfg-email]: https://prometheus.io/docs/alerting/latest/configuration/#email_config
[cfg-webhook]: https://prometheus.io/docs/alerting/latest/configuration/#webhook_config
[prom-alerting-rules]: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/
[prom-staleness]: https://prometheus.io/docs/prometheus/latest/querying/basics/#staleness
[prom-pushing]: https://prometheus.io/docs/practices/pushing/
[prom-main]: https://github.com/prometheus/prometheus/blob/main/cmd/prometheus/main.go
[rules-alerting]: https://github.com/prometheus/prometheus/blob/main/rules/alerting.go
[rules-manager]: https://github.com/prometheus/prometheus/blob/main/rules/manager.go
[client-python]: https://prometheus.github.io/client_python/instrumenting/gauge/
[pop-api]: https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api-reference/api.md
[kps-values]: https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml

Note on the Alertmanager configuration doc: the canonical source is
[`docs/configuration.md`](https://github.com/prometheus/alertmanager/blob/main/docs/configuration.md)
in the Alertmanager repo, rendered at prometheus.io. Quoted defaults were read from that
file at `main`.

Note on location: this repo had no existing convention for research notes
(`docs/` contained only `docs/agents/`), so `docs/research/` was created for them and this
note placed at `docs/research/alertmanager-ingestion.md`.
