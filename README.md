<div align="center">

<img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/kubernetes.png" height="40" alt="Kubernetes" />
&nbsp;
<img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/talos.png" height="40" alt="Talos" />
&nbsp;
<img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/argo-cd.png" height="40" alt="Argo CD" />
&nbsp;
<img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/proxmox.png" height="40" alt="Proxmox" />
&nbsp;
<img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/opentofu.png" height="40" alt="OpenTofu" />

# Lares — A Declarative, Agentic Homelab

_Roman household guardians — a homelab stack across three independent layers: infrastructure, cluster, apps._

</div>

<div align="center">

[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.zimmermann.sh%2Ftalos_version&style=flat-square&logo=talos&logoColor=white&color=blue&label=Talos)](https://talos.dev)
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.zimmermann.sh%2Fkubernetes_version&style=flat-square&logo=kubernetes&logoColor=white&color=blue&label=Kubernetes)](https://kubernetes.io)
[![Nodes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.zimmermann.sh%2Fcluster_node_count&style=flat-square&logo=kubernetes&logoColor=white&label=Nodes)](https://github.com/kashalls/kromgo)
[![Pods](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.zimmermann.sh%2Fcluster_pod_count&style=flat-square&logo=kubernetes&logoColor=white&label=Pods)](https://github.com/kashalls/kromgo)
[![Alerts](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.zimmermann.sh%2Fcluster_alert_count&style=flat-square&logo=prometheus&logoColor=white&label=Alerts)](https://github.com/kashalls/kromgo)

[![License](https://img.shields.io/github/license/alexander-zimmermann/lares?style=flat-square&color=blue)](./LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/alexander-zimmermann/lares?style=flat-square&logo=github&logoColor=white)](https://github.com/alexander-zimmermann/lares/commits/main)
[![Renovate](https://img.shields.io/badge/Renovate-enabled-brightgreen?style=flat-square&logo=renovatebot&logoColor=white)](https://docs.renovatebot.com/)
[![GitOps](https://img.shields.io/badge/GitOps-Argo%20CD-EF7B4D?style=flat-square&logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![Provisioned by Omni](https://img.shields.io/badge/Provisioned%20by-Omni-ff7300?style=flat-square&logo=sidero&logoColor=white)](https://omni.siderolabs.com/)

</div>

---

## About

This is **Lares** — my personal homelab. In Roman religion, the _Lares_ were the guardian spirits of the home: of the threshold, the hearth, the household. The name fits, because what runs here isn't just infrastructure — it's a single [Proxmox VE](https://www.proxmox.com/) box tucked under the desk, running a [Talos Linux](https://www.talos.dev/) Kubernetes cluster that hosts everything from Grafana and Authentik down to the service that scrapes my solar inverter, the bridge that publishes KNX events to NATS, and (eventually) the AI agents that read and act on it all. It's my playground, my production, and the place where I try things before I recommend them to colleagues.

What I care about most is that **everything is declarative end-to-end.** A git push is the only way state reaches the cluster. There is no `kubectl apply`, no `tofu apply` at 2 a.m. from my laptop, no snowflake tweaks. [Renovate](https://docs.renovatebot.com/) opens PRs when new versions drop, I merge them, [Argo CD](https://argo-cd.readthedocs.io/) rolls them out. It's boring. Boring is the point.

The part I'm most proud of is how the repo is **split into three independent layers** — `infrastructure/`, `cluster/`, `kubernetes/`. Each one solves a single problem, speaks a single tool's language, and could be lifted out and reused in isolation. Together they form the stack; apart they're still useful on their own.

## The three layers

### 🧱 Layer 1 — `infrastructure/` · Proxmox IaC

[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.11+-844FBA?style=flat-square&logo=opentofu&logoColor=white)](https://opentofu.org/)
[![Proxmox](https://img.shields.io/badge/Proxmox%20VE-9.0-E57000?style=flat-square&logo=proxmox&logoColor=white)](https://www.proxmox.com/)

[OpenTofu](https://opentofu.org/) with the [`bpg/proxmox`](https://github.com/bpg/terraform-provider-proxmox) provider, driven by split YAML manifests. Manages the Proxmox cluster settings, node config, OS images, templates, and the entire VM/LXC fleet — including Windows 11 VMs with TPM/Secure Boot and a dedicated management VM that hosts Omni.

**This layer has nothing to do with Kubernetes.** I could throw away everything above it and still have a clean, reproducible "Proxmox managed by code" setup.

**Swap-out**: any IaC for any hypervisor. Replace `bpg/proxmox` with `libvirt`, `vsphere`, or a cloud provider and rewrite the `pve_*` modules. The manifest structure and cloud-init plumbing stay.

→ [Full docs](infrastructure/README.md)

### 🚀 Layer 2 — `cluster/` · Omni + Talos

[![Talos](https://img.shields.io/badge/Talos-v1.12.6-blue?style=flat-square&logo=talos&logoColor=white)](https://www.talos.dev/)
[![Omni](https://img.shields.io/badge/Managed%20by-Omni-ff7300?style=flat-square&logo=sidero&logoColor=white)](https://omni.siderolabs.com/)

Three YAML files describe the cluster: versions, machine shapes, system extensions. [Omni](https://omni.siderolabs.com/) does the rest — hands out Talos configs, bootstraps etcd, rotates certificates, tunnels the API server past my dynamic IP.

Machine classes ([`homelab-machine-classes.yaml`](cluster/homelab-machine-classes.yaml)) are auto-provisioned: **3× control plane** (4 vCPU, 4 GB) and **3× worker** (6 vCPU, 10 GB, extra storage disk). Omni picks fresh VMs, assigns roles, done.

**Swap-out**: Omni supports [many infrastructure providers](https://docs.siderolabs.com/omni/infrastructure-and-extensions/infrastructure-providers) — libvirt, vSphere, AWS, Hetzner, bare-metal PXE. Only two fields (`providerid`, `providerdata`) are Proxmox-specific.

→ [Full docs](cluster/README.md)

### ☸️ Layer 3 — `kubernetes/` · Argo CD + Manifests

[![Argo CD](https://img.shields.io/badge/Argo%20CD-GitOps-EF7B4D?style=flat-square&logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![Kustomize](https://img.shields.io/badge/Kustomize-1A73E8?style=flat-square&logo=kubernetes&logoColor=white)](https://kustomize.io/)

Standard CNCF Kubernetes manifests, grouped into `bootstrap/` (day-zero), `components/` (shared infra — ingress, cert-manager, CSI, sealed-secrets, …), and `applications/` (25+ end-user apps). Two Argo CD `ApplicationSet`s auto-discover new folders by convention; I never hand-write an `Application` resource.

**Swap-out**: this tree is vanilla Kubernetes. Strip the `talos-ccm` bootstrap folder and it runs on k3s, kind, EKS, whatever. No Talos lock-in above the control-plane layer.

→ [Full docs](kubernetes/README.md)

> **Why I like this split:** each layer has exactly one job, exactly one tool, and a clean escape hatch. If tomorrow I fall out of love with Proxmox, I rewrite one layer. If I want to move off Omni, I rewrite another. Nothing cascades.

## Architecture

### Stack layers

Three independent layers stacked bottom-up — Proxmox provisions VMs, Omni shapes them into a Talos cluster, Argo CD reconciles every app from `main`.

```mermaid
flowchart TB
    subgraph L3["Layer 3: Apps — Argo CD + Manifests"]
        direction LR
        argo[Argo CD]
        apps[25+ Applications]
        components[Shared Components]
        argo --> apps
        argo --> components
    end
    subgraph L2["Layer 2: Cluster — Omni + Talos"]
        direction LR
        omni[Omni SaaS]
        talos[Talos Cluster<br/>3× CP · 3× Worker]
        omni --> talos
    end
    subgraph L1["Layer 1: Infrastructure — Proxmox + OpenTofu"]
        direction LR
        tofu[OpenTofu]
        pve[Proxmox VE]
        mgmt[Omni Mgmt VM]
        tofu --> pve
        pve --> mgmt
    end

    L1 -- VMs --> L2
    L2 -- kubeconfig --> L3

    renovate[Renovate Bot]
    me[Me]
    repo[(GitHub: main)]

    me -- commits --> repo
    renovate -- PRs --> repo
    repo -- watched --> argo
    mgmt -- hosts --> omni
```

### Smart-Home data flow

NATS is the universal event bus. Every external source publishes there, the bridge writes selected subjects back to KNX, and redpanda-connect ingests everything into TimescaleDB plus a cold parquet archive on rustfs for retrospective analysis by Claude via MCP.

```mermaid
flowchart TB
    subgraph IOT[IoT]
        direction LR
        cam[UniFi Protect Cams]
        ems[EMS-ESP]
        pv[solaredge2mqtt]
        warp[WARP Wallbox]
    end

    webhook[redpanda-connect<br/>unifi_webhook]
    cam -- HTTP --> webhook

    nats[(NATS JetStream<br/>+ MQTT gateway<br/><br/>KNX · EMS_ESP<br/>WARP · SOLAREDGE · UNIFI)]

    webhook -- pub unifi.> --> nats
    ems  -- MQTT --> nats
    pv   -- MQTT --> nats
    warp -- MQTT pub --> nats

    subgraph KX[KNX]
        direction TB
        bridge[knx-nats-bridge]
        nodered[node-RED]
        knx[KNX Bus]
        basalte[Basalte]
        bridge <-- xknx tunnel --> knx
        nodered -- KNX-Ultimate --> knx
        knx --> basalte
    end

    nats <-- pub/sub knx.> --> bridge
    nats -- MQTT sub --> nodered

    subgraph ARCH[Archive + analytics]
        direction LR
        ingest[redpanda-connect<br/>ingest streams]
        tsdb[(TimescaleDB)]
        rustfs[(rustfs<br/>parquet archive)]
        mcp[iot-mcp-bridge<br/>MCP tools + jobs]
        claude((Claude.ai))
        ingest --> tsdb
        ingest --> rustfs
        tsdb -- SELECT --> mcp
        mcp -- MCP/HTTP --> claude
    end

    nats -- sub --> ingest
    mcp -- pub anomaly.> --> nats
```

The KNX bus loops back into the data pipeline: every telegram the writer puts on the bus is seen by the reader on the same tunnel, republished on `knx.<ga>`, and ingested by redpanda-connect into the `knx` hypertable — so TSDB always reflects the live bus state regardless of who originated the write.

## Hardware

### Compute

| Component  | Spec                                                           |
| ---------- | -------------------------------------------------------------- |
| Chassis    | Lenovo ThinkStation P3 Tiny Gen 2                              |
| CPU        | Intel® Core™ Ultra 5 235T vPro® (14 cores, Arrow Lake-S, 35 W) |
| Memory     | 64 GB DDR5-6400 (2× Kingston ValueRAM 32 GB)                   |
| Storage    | 1 TB Micron 7450 PRO NVMe (ZFS, `local-zfs`)                   |
| Hypervisor | Proxmox VE 9                                                   |

### Talos VMs

Six VMs on the one Proxmox host, auto-provisioned by Omni — see [`cluster/homelab-machine-classes.yaml`](cluster/homelab-machine-classes.yaml).

| Role          | Count | vCPU | RAM   | Root  | Extra disks                    |
| ------------- | ----- | ---- | ----- | ----- | ------------------------------ |
| Control plane | 3     | 4    | 4 GB  | 32 GB | —                              |
| Worker        | 3     | 6    | 10 GB | 64 GB | 128 GB (storage) + 4 GB (swap) |

### Network

All-Ubiquiti stack — one uplink per tier, 10 GbE between switches, PoE on the edge.

| Device                                                    | Role                                                 |
| --------------------------------------------------------- | ---------------------------------------------------- |
| EDPNET Belgium                                            | ISP (WAN)                                            |
| [UDM-Pro](https://ui.com/cloud-gateways/udm-pro)          | Gateway / firewall / Network controller              |
| [USW Pro HD 24](https://ui.com/switching/usw-pro-hd-24)   | Core switch (10 GbE uplink to UDM-Pro)               |
| [USW Pro Max 48](https://ui.com/switching/usw-pro-max-48) | Aggregation switch (10 GbE uplink to USW Pro HD 24)  |
| [USW Pro 48 PoE](https://ui.com/switching/usw-pro-48-poe) | Access switch (10 GbE uplink, PoE for APs & cameras) |
| [USP-RPS](https://ui.com/power-backup/usp-rps)            | Redundant power supply for the rack                  |
| 3× [U7 Pro](https://ui.com/wifi/flagship/u7-pro)          | Wi-Fi 7 APs                                          |
| 2× [U6-LR](https://ui.com/wifi/long-range/u6-long-range)  | Wi-Fi 6 long-range APs                               |

### Storage (shared)

| Device                                      | Role                                                                  |
| ------------------------------------------- | --------------------------------------------------------------------- |
| [UNAS Pro](https://ui.com/storage/unas-pro) | 4-bay NAS — bulk storage, backups, S3 targets for PITR/object storage |

## Highlights

A quick taste of what's running — full catalog in [`kubernetes/README.md`](kubernetes/README.md#catalog):

- **GitOps everywhere** — [Argo CD](https://argo-cd.readthedocs.io/) reconciles the cluster, [Renovate](https://docs.renovatebot.com/) opens PRs for every dependency bump.
- **Immutable OS** — [Talos Linux](https://www.talos.dev/) with disk encryption, managed by [Omni](https://omni.siderolabs.com/).
- **Identity & edge** — [Authentik](https://goauthentik.io/) SSO/forward-auth, [Traefik](https://traefik.io/) with pre/post-auth middleware chains, [CrowdSec](https://www.crowdsec.net/) behavior-based IPS, [Cloudflare](https://www.cloudflare.com/) WAF.
- **Data plane** — [CloudNativePG](https://cloudnative-pg.io/) with Barman S3 PITR backups, [TimescaleDB](https://www.timescale.com/) for sensor time-series, [Redis](https://redis.io/), [RustFS](https://github.com/rustfs/rustfs) for S3-compatible object storage.
- **Streaming & agents** — [NATS](https://nats.io/) JetStream as the message bus, [Redpanda Connect](https://docs.redpanda.com/redpanda-connect/about/) fanning streams into TimescaleDB and Parquet on S3, plus protocol bridges (KNX, solar) and an MCP bridge that exposes the data to AI agents.
- **Observability** — [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/), [Loki](https://grafana.com/oss/loki/), [Alloy](https://grafana.com/docs/alloy/), [Gatus](https://gatus.io/), plus [kromgo](https://github.com/kashalls/kromgo) powering the badges above.

## Repository structure

```
lares/
├── infrastructure/   # Layer 1 — Proxmox IaC (OpenTofu + bpg/proxmox)
├── cluster/          # Layer 2 — Omni cluster templates + machine classes
├── kubernetes/       # Layer 3 — Argo CD-reconciled manifests
│
├── tasks/            # Taskfile includes (cluster/, infra/, kubernetes/)
└── Taskfile.yaml     # Top-level entry point — `task --list`
```

Each of the three layer directories has its own detailed README:

- [**infrastructure/README.md**](infrastructure/README.md)
- [**cluster/README.md**](cluster/README.md)
- [**kubernetes/README.md**](kubernetes/README.md)

## Acknowledgements

Standing on the shoulders of giants. This setup borrows patterns and inspiration from:

- [buroa/k8s-gitops](https://github.com/buroa/k8s-gitops) — the kromgo badge idea and a lot of stylistic cues.
- The [home-operations](https://github.com/home-operations) community.

## License

See [LICENSE](LICENSE).
