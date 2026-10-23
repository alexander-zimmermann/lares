# Cluster — Omni + Talos

[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.zimmermann.sh%2Ftalos_version&style=flat-square&logo=talos&logoColor=white&color=blue&label=Talos)](https://www.talos.dev/)
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.zimmermann.sh%2Fkubernetes_version&style=flat-square&logo=kubernetes&logoColor=white&color=blue&label=Kubernetes)](https://kubernetes.io/)
[![Omni](https://img.shields.io/badge/Managed%20by-Omni-ff7300?style=flat-square&logo=sidero&logoColor=white)](https://omni.siderolabs.com/)

> **Layer 2 of [the Lares stack](../README.md).** This is just cluster definition — machine shapes and Talos/Kubernetes versions. It has no opinion on what runs underneath (any infra provider works) or on top (standard Kubernetes manifests).

## What this directory does

I let [Omni](https://omni.siderolabs.com/) run my Talos control plane. All I do here is describe the cluster I want — Omni figures out the rest: it hands out bootstrap configs, issues certificates, upgrades nodes one-by-one, and keeps the API servers reachable via its tunnel even when my home IP rotates.

The whole cluster state lives in three YAML files, reconciled into Omni with `omnictl`. No manual `talosctl bootstrap` dance, no per-node config sprawl.

## Files

| File                                                           | Purpose                                                                                        |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| [`homelab-cluster-prod.yaml`](homelab-cluster-prod.yaml)       | Production Omni Cluster Template — Talos/k8s versions, 3× CP + 3× Worker, system extensions    |
| [`homelab-cluster-dev.yaml`](homelab-cluster-dev.yaml)         | Dev-cluster variant (smaller footprint, same shape)                                            |
| [`homelab-machine-classes.yaml`](homelab-machine-classes.yaml) | Auto-provisioning shapes — what a "control plane" or "worker" VM looks like on Proxmox         |
| [`patches/`](patches/)                                         | Omni patches (global settings, CP/DP tuning, egress-gateway address + labels, extra manifests) |

### Cluster shape (prod)

Defined in [`homelab-cluster-prod.yaml`](homelab-cluster-prod.yaml):

- **Talos** v1.12.6, **Kubernetes** v1.34.6
- **Disk encryption** enabled (LUKS)
- **3× control plane**, **3× worker** — all auto-provisioned via machine classes; the workers sit in three machine sets of size 1 (`data-plane`, `data-plane-egress-a`, `data-plane-egress-b`), see [Network](#network)
- **System extensions**: `qemu-guest-agent`, `util-linux-tools`, `i915` (Intel iGPU), `intel-ucode`, `nvidia-open-gpu-kernel-modules-lts`, `iscsi-tools`, `zfs`

### Machine classes

Defined in [`homelab-machine-classes.yaml`](homelab-machine-classes.yaml). Each class tells Omni's infra provider how to spin up a VM.

| Role                 | vCPU | RAM   | Root  | Extra disks                    |
| -------------------- | ---- | ----- | ----- | ------------------------------ |
| `control-plane-prod` | 4    | 4 GB  | 32 GB | —                              |
| `data-plane-prod`    | 6    | 10 GB | 64 GB | 128 GB (storage) + 4 GB (swap) |
| `control-plane-dev`  | 2    | 2 GB  | 32 GB | —                              |
| `data-plane-dev`     | 4    | 4 GB  | 64 GB | 64 GB (storage) + 4 GB (swap)  |

All go to `local-zfs` on my Proxmox host; NUMA, `host` CPU type, `q35` machine, `io_uring` async I/O.

## Network

The nodes live in VLAN 10 "Kubernetes", `192.168.10.0/24`, one of the zones of [ADR 0004](../docs/adr/0004-network-zones-on-the-udm-egress-keys-per-pod-label.md). Every VLAN in the house follows the same address convention — `.1` gateway, `.2`–`.49` fixed addresses configured on the device itself, `.50`–`.199` DHCP (reservations live inside this range), `.200`–`.254` special purpose — and VLAN 10 fills it like this:

| Range         | Use                                                                                                                                                                                                                                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.1`          | UDM gateway `192.168.10.1`, BGP peer (AS 65100); `peerAddress` in [`bgp-cluster-config.yaml`](../kubernetes/components/cilium/base/bgp-cluster-config.yaml)                                                                                                                                                   |
| `.2`, `.3`    | Egress IPs, static on the two gateway workers (set by the Omni patch, not by DHCP)                                                                                                                                                                                                                            |
| `.4`–`.49`    | Free; static addresses only, nothing here takes a lease                                                                                                                                                                                                                                                       |
| `.50`–`.199`  | DHCP, the same range as in every other VLAN. The Talos nodes take their address here and keep it by a UniFi "Fixed IP" reservation on the MAC. The scope must stay on: a VM the Omni provider creates finds Omni through its first lease; a rebuilt VM (new MAC) pulls a new lease and gets a new reservation |
| `.200`–`.254` | One `CiliumLoadBalancerIPPool` without service selector, so every LoadBalancer Service draws from it; the prod overlays pin each Service's IP (`io.cilium/lb-ipam-ips`)                                                                                                                                       |

The machine classes carry `vlan: 10`, so every VM the Proxmox provider creates from now on is tagged into the VLAN. The provider does not touch a VM that already runs; those get their tag by hand in Proxmox.

### Egress gateways

Two workers own the egress IPs `.2` and `.3` that Cilium's egress gateway uses as source address towards the other zones (which pods get one is decided per label in the Cilium component, not here). The binding is the machine set: [`homelab-cluster-prod.yaml`](homelab-cluster-prod.yaml) splits the three workers into `data-plane` (1), `data-plane-egress-a` (1) and `data-plane-egress-b` (1), all of the same machine class, and only the two gateway sets carry [`patches/data-plane-egress-a.yaml`](patches/data-plane-egress-a.yaml) / [`-b.yaml`](patches/data-plane-egress-b.yaml). Omni applies a machine set's patches to whatever machine fills the set, so a rebuilt gateway worker comes back with its address and labels — nothing in the template names a machine UUID or a hostname.

What the patch does on the worker:

- adds the egress IP as a `/32` on the virtio NIC next to DHCP. A `/32` creates no connected route, so the node's own traffic (Omni, NFS, Longhorn) keeps leaving with the DHCP address; only Cilium SNATs to the egress IP.
- excludes the egress IP from `machine.kubelet.nodeIP.validSubnets`. Talos takes the lowest routed IPv4 as kubelet node IP, which would be the egress IP itself.
- sets the node labels `egress-gateway=true` (the pair) and `egress-ip=<address>` (this node alone), which a `CiliumEgressGatewayPolicy` selects per `egressGateways` entry.

Trade-offs of three machine sets: a Talos upgrade still rolls one node at a time cluster-wide (Omni subtracts every not-ready machine from each set's quota), but a config change shared by all three sets — an edit to `data-plane-settings.yaml` — can reach one machine per set at once. Stage a change that needs a reboot by touching one set at a time if that matters. Rebuilding a gateway worker also means Longhorn rebuilds its replicas, as with any worker.

## Swapping the infra provider

The interesting bit: **this layer has one line of Proxmox-specific config**. In every machine class, `spec.autoprovision.providerid: proxmox-infra` pins it. Change that (and the `providerdata` block) and you're on a different hypervisor without touching anything else.

Omni ships [infrastructure providers](https://docs.siderolabs.com/omni/infrastructure-and-extensions/infrastructure-providers) for:

- **libvirt** — for KVM-on-Linux homelabs
- **vSphere** — for corporate-y setups
- **AWS / Hetzner / GCP / Azure** — cloud-backed clusters
- **Bare metal (PXE)** — physical fleet via iPXE + Talos factory images

Each provider has its own `providerdata` schema (see their docs). The rest of the `Cluster` / `ControlPlane` / `Workers` / `MachineClasses` kinds stays identical.

## Usage

From the repo root (uses [go-task](https://taskfile.dev)):

| Task                           | What it does                                                          |                                                       |
| ------------------------------ | --------------------------------------------------------------------- | ----------------------------------------------------- |
| `task cluster:init`            | Register machine classes in Omni (run once, or after editing classes) |                                                       |
| `task cluster:create -- [dev\  | prod]`                                                                | Sync the cluster template to Omni (default: `prod`)   |
| `task cluster:status -- [dev\  | prod]`                                                                | Print current cluster status from Omni                |
| `task cluster:show -- [dev\    | prod]`                                                                | Download `kubeconfig` + `talosconfig` for the cluster |

Underlying command for `create` is `omnictl cluster template sync --file homelab-cluster-prod.yaml`.

## Bootstrap sequence

This only makes sense in combination with [Layer 1 (infrastructure)](../infrastructure/README.md):

1. **Infra up** — `task infra:create` brings the Proxmox VMs online. They boot a Talos image pre-baked with the Omni join token.
2. **Omni sees them** — Machines register automatically and land in Omni as unassigned.
3. **Register classes** — `task cluster:init` pushes [`homelab-machine-classes.yaml`](homelab-machine-classes.yaml) to Omni.
4. **Create the cluster** — `task cluster:create` syncs the template. Omni assigns machines to roles based on their specs matching the classes, hands out Talos configs, bootstraps etcd, signs certs.
5. **Omni applies day-zero manifests** — via `extraManifests` in [`patches/extraManifests-prod.yaml`](patches/extraManifests-prod.yaml), Omni pulls the rendered Cilium, Argo CD, and Talos-CCM manifests from the [`bootstrap` branch](https://github.com/alexander-zimmermann/lares/tree/bootstrap) and applies them to the new cluster. No manual `kubectl apply -k` required.
6. **Fetch kubeconfig** — `task cluster:show` writes `kubeconfig` / `talosconfig` locally. Done.

At this point [Layer 3 (kubernetes)](../kubernetes/README.md) takes over — `task k8s:init` seeds the sealed-secrets master key and Argo CD reconciles the rest.

## License

See [../LICENSE](../LICENSE).
