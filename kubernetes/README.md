# Kubernetes — Argo CD + Manifests

[![Argo CD](https://img.shields.io/badge/Argo%20CD-GitOps-EF7B4D?style=flat-square&logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![Kustomize](https://img.shields.io/badge/Kustomize-1A73E8?style=flat-square&logo=kubernetes&logoColor=white)](https://kustomize.io/)
[![Sealed Secrets](https://img.shields.io/badge/Sealed%20Secrets-encrypted-2F855A?style=flat-square&logo=kubernetes&logoColor=white)](https://github.com/bitnami-labs/sealed-secrets)

> **Layer 3 of [the Lares stack](../README.md).** Standard CNCF-compatible Kubernetes manifests, reconciled by Argo CD. Nothing Talos- or Proxmox-specific lives in here (except a tiny `talos-ccm` bootstrap bit). Drop this directory into k3s, kind, EKS, or whatever — it'll work.

## What this directory does

Argo CD watches `main` and syncs everything under here into the cluster. I never `kubectl apply` anything by hand — a push to `main` is the only way state changes.

Two `ApplicationSet`s (defined in [`bootstrap/gitops-controller/base/`](bootstrap/gitops-controller/base/)) auto-generate Argo `Application`s by scanning directory conventions:

- One scans `components/*/base/kustomization.yaml` → shared infra
- One scans `applications/*/base/kustomization.yaml` → end-user apps

Add a folder that matches the convention and Argo picks it up on the next reconcile. No manual `Application` wiring per app.

## Directory layout

```
kubernetes/
├── bootstrap/          # Day-zero manifests (applied before Argo takes over)
│   ├── cilium/         #   eBPF CNI (kube-proxy replacement, L2 announcements)
│   ├── gitops-controller/  # Argo CD itself + the ApplicationSets that drive everything else
│   └── talos-ccm/      #   Talos cloud-controller-manager (node provider integration)
│
├── components/         # Shared infra used by many apps
│   ├── admission-controller/   # Kyverno (secret replication, admission policies)
│   ├── cert-manager/           # TLS via Cloudflare DNS-01
│   ├── cilium/                 # Cilium CRDs + overlays
│   ├── csi-block-storage-controller/
│   ├── csi-nfs-controller/
│   ├── external-dns/           # Syncs ingress hostnames → Cloudflare
│   ├── gitops-controller/      # Argo CD overlays
│   ├── ingress-controller/     # Traefik + middleware chains (pre/post-auth)
│   ├── metrics-server/
│   ├── prometheus-crds/
│   ├── sealed-secrets-controller/
│   └── talos-ccm/
│
└── applications/       # End-user apps (each with base/ + overlays/{dev,prod})
    ├── authentik/      #   SSO / OIDC
    ├── grafana/        #   Dashboards
    ├── homepage/       #   Service start page
    ├── kromgo/         #   Cluster-stats badges (see top-level README)
    ├── prometheus/     #   Metrics & alerting
    ├── loki/           #   Logs
    ├── cloudnative-pg/ #   Postgres operator
    ├── crowdsec/       #   IPS
    ├── wiki-js/        #   Personal wiki
    └── …               #   (25+ in total)
```

## GitOps flow

```mermaid
flowchart LR
    me[Me]
    renovate[Renovate]
    git[(GitHub: main)]
    appset[ApplicationSets]
    argo[Argo CD]
    cluster[(Cluster)]

    me -- PR + merge --> git
    renovate -- PRs --> git
    git -- polled every 3m --> appset
    appset -- generates --> argo
    argo -- reconciles --> cluster
```

Secrets are encrypted with [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) — the master key lives in `components/sealed-secrets-controller/base/master-key.yaml` and is **not** in git (it's seeded once per cluster via `task k8s:init`). Every `secret.yaml` in the tree has a matching `sealed-secret.yaml` that Argo applies; the controller decrypts it in-cluster.

## Usage

From the repo root (uses [go-task](https://taskfile.dev)):

| Task                                         | What it does                                                                                                |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `task k8s:init`                              | Bootstrap sealed-secrets master key + DHI registry credentials. Run once, right after the cluster comes up. |
| `task k8s:status`                            | Show nodes, pods (all namespaces), and Cilium status.                                                       |
| `task k8s:show`                              | Print the Argo CD admin password.                                                                           |
| `task k8s:seal path/to/secret.yaml`          | Encrypt a plain secret for git. Writes `sealed-secret.yaml` next to it.                                     |
| `task k8s:unseal path/to/sealed-secret.yaml` | Decrypt back to `secret.yaml` (needs local master key).                                                     |
| `task k8s:delete`                            | **Wipe every managed namespace** (prompted). Useful before re-bootstrapping.                                |

## Adding a new app

1. `mkdir -p kubernetes/applications/<name>/base` and drop your manifests in.
2. Create `base/kustomization.yaml` with `namespace: <name>` and list the resources.
3. Create `overlays/{dev,prod}/kustomization.yaml` that reference `../../base` and apply env-specific patches (hostnames, replicas).
4. Commit, push. The `applications` ApplicationSet picks it up within one sync interval.

If your app needs secrets: write them as plain `secret.yaml`, then `task k8s:seal kubernetes/applications/<name>/base/secret.yaml`, commit only the `sealed-secret.yaml`.

## Catalog

All components grouped by what they do. Icons via [homarr-labs/dashboard-icons](https://github.com/homarr-labs/dashboard-icons), served through jsDelivr. Rows without an icon are for projects that don't have a curated brand-icon (yet).

### Platform

|                                                                                                        | Component                                                        | Purpose                                                           |
| :----------------------------------------------------------------------------------------------------: | ---------------------------------------------------------------- | ----------------------------------------------------------------- |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/talos.png" height="18" />        | [Talos Linux](https://www.talos.dev/)                            | Immutable, API-managed Kubernetes OS                              |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/talos.png" height="18" />        | [Omni](https://omni.siderolabs.com/)                             | SaaS control plane for Talos (auto-provisioning, machine classes) |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/cilium.png" height="18" />       | [Cilium](https://cilium.io/)                                     | eBPF CNI (kube-proxy replacement, L2 announcements)               |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/traefik.png" height="18" />      | [Traefik](https://traefik.io/)                                   | Ingress with pre/post-auth middleware chains                      |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/cert-manager.png" height="18" /> | [cert-manager](https://cert-manager.io/)                         | Automated TLS via Cloudflare DNS-01                               |
|                                                                                                        | [external-dns](https://github.com/kubernetes-sigs/external-dns)  | Syncs ingress hostnames to Cloudflare                             |
|                                                                                                        | [Kyverno](https://kyverno.io/)                                   | Policy engine (secret replication, admission)                     |
|                                                                                                        | [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) | Git-safe, cluster-decryptable secrets                             |

### GitOps & Automation

|                                                                                                    | Component                                  | Purpose                                       |
| :------------------------------------------------------------------------------------------------: | ------------------------------------------ | --------------------------------------------- |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/argo-cd.png" height="18" />  | [Argo CD](https://argo-cd.readthedocs.io/) | Declarative sync of `kubernetes/applications` |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/renovate.png" height="18" /> | [Renovate](https://docs.renovatebot.com/)  | Automated dependency PRs                      |

### Security & Identity

|                                                                                                      | Component                                 | Purpose                                 |
| :--------------------------------------------------------------------------------------------------: | ----------------------------------------- | --------------------------------------- |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/authentik.png" height="18" />  | [Authentik](https://goauthentik.io/)      | SSO / OIDC / forward-auth               |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/crowdsec.png" height="18" />   | [CrowdSec](https://www.crowdsec.net/)     | Behavior-based IPS on ingress           |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/cloudflare.png" height="14" /> | [Cloudflare](https://www.cloudflare.com/) | WAF, rate-limiting, edge TLS, tunneling |

### Storage & Data

|                                                                                                      | Component                                                                     | Purpose                                                   |
| :--------------------------------------------------------------------------------------------------: | ----------------------------------------------------------------------------- | --------------------------------------------------------- |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/kubernetes.png" height="18" /> | CSI Block + NFS                                                               | Persistent volumes for workloads                          |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/rustfs.png" height="12" />     | [RustFS](https://github.com/rustfs/rustfs)                                    | S3-compatible object storage                              |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/postgresql.png" height="18" /> | [CloudNativePG](https://cloudnative-pg.io/) + [Barman](https://pgbarman.org/) | Postgres operator with S3 PITR backups                    |
|                                                                                                      | [TimescaleDB](https://www.timescale.com/)                                     | Time-series Postgres for sensor & telemetry data          |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/redis.png" height="18" />      | [Redis](https://redis.io/)                                                    | In-memory cache                                           |
|                                                                                                      | [NATS](https://nats.io/) JetStream + [NACK](https://github.com/nats-io/nack)  | Message bus + KV/object stores; operator-managed          |
|                                                                                                      | [Redpanda Connect](https://docs.redpanda.com/redpanda-connect/about/)         | Stream pipelines (NATS → TimescaleDB / Parquet on RustFS) |

### Observability

|                                                                                                      | Component                                    | Purpose                                     |
| :--------------------------------------------------------------------------------------------------: | -------------------------------------------- | ------------------------------------------- |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/prometheus.png" height="18" /> | [Prometheus](https://prometheus.io/)         | Metrics & alerting                          |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/grafana.png" height="18" />    | [Grafana](https://grafana.com/) + Operator   | Dashboards, dashboards-as-code              |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/loki.png" height="18" />       | [Loki](https://grafana.com/oss/loki/)        | Log aggregation                             |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/alloy.png" height="18" />      | [Alloy](https://grafana.com/docs/alloy/)     | Unified telemetry collector                 |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/gatus.png" height="18" />      | [Gatus](https://gatus.io/)                   | Status page / synthetic probes              |
|                                                                                                      | [kromgo](https://github.com/kashalls/kromgo) | PromQL → shields.io bridge (cluster badges) |

### Applications

|                                                                                                    | Component                                                       | Purpose                                             |
| :------------------------------------------------------------------------------------------------: | --------------------------------------------------------------- | --------------------------------------------------- |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/homepage.png" height="18" /> | [Homepage](https://gethomepage.dev/)                            | Service start page                                  |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/wikijs.png" height="18" />   | [Wiki.js](https://js.wiki/)                                     | Knowledge base                                      |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/node-red.png" height="18" /> | [Node-RED](https://nodered.org/)                                | Flow-based automation                               |
|                                                                                                    | [knx-nats-bridge](https://github.com/alexander-zimmermann/knx-nats-bridge) | KNX bus ↔ NATS subjects (home automation gateway)   |
|                                                                                                    | [iot-mcp-bridge](https://github.com/alexander-zimmermann/iot-mcp-bridge)   | MCP server exposing TimescaleDB / NATS to AI agents |
|                                                                                                    | [SolarEdge2MQTT](https://github.com/DerOetzi/solaredge2mqtt)               | PV inverter → MQTT (consumed by Redpanda Connect)   |
|                                                                                                    | [Fritz!Box Exporter](https://github.com/pdreker/fritz_exporter)            | Prometheus metrics from the Fritz!Box               |
|                                                                                                    | [UniFi Poller](https://github.com/unpoller/unpoller)                       | Prometheus metrics from the UniFi controller        |
|                                                                                                    | [SMTPRelay](https://github.com/grafana/smtprelay)                          | Outbound mail relay for cluster workloads           |

## Portability note

The whole `kubernetes/` tree is standard CNCF Kubernetes. Point a k3s or kind cluster at it and it'll largely just run — the only real Talos-isms are:

- `bootstrap/talos-ccm/` — only makes sense on Talos; strip it on other distros.
- A handful of `securityContext` tweaks tuned for Talos's strict defaults.
- `storageClass` names assuming the Talos CSI drivers.

Everything else (ingress, certs, DNS, Argo CD, all 25+ apps) is portable.

## Bootstrap sequence

### With Omni (this repo's default)

Omni applies Cilium, Argo CD, and Talos-CCM automatically via [`extraManifests`](../cluster/patches/extraManifests-prod.yaml) during cluster creation — see [Layer 2 (cluster)](../cluster/README.md#bootstrap-sequence). The rendered manifests are continuously published to the [`bootstrap` branch](https://github.com/alexander-zimmermann/lares/tree/bootstrap) by the [`cd-render-bootstrap.yaml`](../.github/workflows/cd-render-bootstrap.yaml) workflow — that's what Omni pulls.

So once the cluster is up and `kubeconfig` is on your machine, there's only one step left:

1. `task k8s:init` — seeds the sealed-secrets master key + DHI registry credentials.

That's it. Argo CD is already running and starts reconciling the components / applications trees.

### Without Omni (plain Kubernetes)

If you're running this tree on a different cluster without Omni's `extraManifests` mechanism, apply the bootstrap manifests yourself:

1. `kubectl apply -k kubernetes/bootstrap/cilium/overlays/prod` — CNI online.
2. `kubectl apply -k kubernetes/bootstrap/talos-ccm/overlays/prod` — nodes get proper labels. _(Skip on non-Talos clusters.)_
3. `kubectl apply -k kubernetes/bootstrap/gitops-controller/overlays/prod` — Argo CD + the two ApplicationSets land, reconciliation starts.
4. `task k8s:init` — seed the sealed-secrets master key + DHI registry credentials.

## License

See [../LICENSE](../LICENSE).
