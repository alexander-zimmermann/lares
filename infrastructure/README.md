# Infrastructure — Proxmox IaC

[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.11+-844FBA?style=flat-square&logo=opentofu&logoColor=white)](https://opentofu.org/)
[![Proxmox](https://img.shields.io/badge/Proxmox%20VE-9.0-E57000?style=flat-square&logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![Provider](https://img.shields.io/badge/Provider-bpg%2Fproxmox-blue?style=flat-square)](https://github.com/bpg/terraform-provider-proxmox)

> **Layer 1 of [the Lares stack](../README.md).** Pure Proxmox IaC — manages cluster-wide settings, nodes, images, templates, and the VM/LXC fleet. It has zero dependency on Kubernetes. I could rip out everything above this layer and still have a perfectly usable "IaC for Proxmox" setup.

## What this does

I describe my Proxmox setup in YAML manifests, `locals.tf` stitches them together, and [OpenTofu](https://opentofu.org/) plus the [`bpg/proxmox`](https://github.com/bpg/terraform-provider-proxmox) provider make it happen. That covers:

- **Cluster-wide config** — ACME for PVE UI certs, backup jobs to PBS, hardware mappings (USB), users.
- **Per-node config** — repositories, network, optional subscription keys.
- **OS images** — declarative download + SHA-512 verification (Debian Trixie, Ubuntu Noble/Plucky, Windows 11 25H2 + virtio).
- **Cloud-init modules** — reusable blocks for users, vendor bootstrap, network.
- **Templates** — VM and LXC templates (hardware shapes, OS type).
- **Fleet** — actual VMs and containers instantiated from templates.

Specials worth calling out:

- **Deterministic MAC addresses** — `02:01:00:XX:XX:XX` for VMs, `02:02:00:XX:XX:XX` for LXCs (derived from their IDs). Stable DHCP leases across rebuilds.
- **Windows 11 support** — UEFI, TPM 2.0, Secure Boot with pre-enrolled keys, Q35, VirtIO driver ISO.
- **Omni host VM** — one of the VMs (`cluster_mgmt_01`) runs [Omni](https://omni.siderolabs.com/) in Docker Compose via cloud-init. Talos VMs themselves are **not** provisioned here — Omni creates and manages them through its own Proxmox infra provider ([Layer 2](../cluster/README.md)).

## Directory layout

```
infrastructure/
├── main.tf                 # Module wiring
├── locals.tf               # Manifest merging + computed defaults
├── variables.tf            # Input variables (credentials, secrets)
├── outputs.tf
├── providers.tf            # Provider configuration (PVE API endpoints)
├── versions.tf             # OpenTofu + provider versions
├── terraform.tfvars.example
├── manifest/               # YAML — the source of truth
│   ├── 00-cluster/         #   PVE connection, ACME, backup jobs, PBS storage, users
│   ├── 10-pve-node/        #   Node core settings, repos, network
│   ├── 20-image/           #   OS images with checksums
│   ├── 30-cloud-init/      #   Reusable cloud-init modules
│   ├── 40-template/        #   VM / LXC templates
│   └── 50-fleet/           #   Actual VM / container instances
├── modules/                # Reusable OpenTofu modules
│   ├── 00-pve-cluster-*    #   cluster-scope
│   ├── 10-pve-node-*       #   node-scope
│   ├── 20-image
│   ├── 30-cloud-init
│   ├── 40-template-{vm,lxc}
│   └── 50-fleet-{vm,lxc}
└── templates/              # .tftpl files rendered into cloud-init (env files, scripts)
```

The numeric prefixes (`00-` through `50-`) match between `manifest/` and `modules/` so the data flow is obvious — a `50-fleet` YAML references a `40-template` which references a `20-image`, etc.

## Example: declaring an OS image

```yaml
# manifest/20-image/image.yaml
image:
  vm_debian_trixie:
    image_type: import
    image_url: https://cloud.debian.org/images/cloud/trixie/20260327-2429/debian-13-genericcloud-amd64-20260327-2429.qcow2
    image_filename: debian-13-genericcloud-amd64.qcow2
    image_checksum: 09559ec27d263997827dd8cddf76e97ea8e0f1803380aa501ea7eaa4b4968cd76ffef4ec7eb07ef1a9ccbeb0925a5020492ea9ed53eb167d62f3a2285039912c
    image_checksum_algorithm: sha512
```

`locals.tf` pulls every `manifest/20-image/*.yaml` in, merges them, and passes the map to the `20-image` module which handles the actual download + verification. Renovate keeps the `image_url` and `image_checksum` fresh via PRs — see [`image.yaml`](manifest/20-image/image.yaml) for the live catalog.

## Usage

From the repo root (uses [go-task](https://taskfile.dev)):

| Task                | What it does                                                              |
| ------------------- | ------------------------------------------------------------------------- |
| `task infra:init`   | `tofu init` — download providers. Run once or after provider updates.     |
| `task infra:status` | `tofu plan` — dry-run, drift check.                                       |
| `task infra:create` | `tofu apply` — zero-to-hero. Builds everything declared in the manifests. |
| `task infra:delete` | `tofu destroy` — tears everything down.                                   |
| `task infra:show`   | Print OpenTofu outputs.                                                   |

## Prerequisites

- **Proxmox VE 9.0+**, API reachable on port 8006.
- **DHCP** on the VM network (MAC addresses are deterministic, IPs come from your router).
- **OpenTofu** ≥ 1.11 on your workstation (`omnictl`/`talosctl` are only needed from [Layer 2](../cluster/README.md) on).
- **`terraform.tfvars`** with:

  ```hcl
  pve_cluster_token_id     = "…"
  pve_cluster_token_secret = "…"
  pve_cluster_password     = "…"  # optional, for console access
  pve_node_core_subscription_keys = {
    pve-1 = "…"
  }
  ```

  See [`terraform.tfvars.example`](terraform.tfvars.example) for the full shape.

## Swapping the hypervisor

The Proxmox-specific bits are confined to the `bpg/proxmox` provider and the `pve_*` module namespaces. Everything else (cloud-init generation, image catalog, manifest merging) is generic Terraform/OpenTofu. Swapping to another hypervisor means:

1. Replace `bpg/proxmox` in [`versions.tf`](versions.tf) with your provider of choice (libvirt, vsphere, …).
2. Rewrite the `10-pve-node-*`, `40-template-{vm,lxc}`, `50-fleet-{vm,lxc}` modules against the new provider's resources.
3. Keep `20-image`, `30-cloud-init`, `locals.tf`, and the manifest structure — they're portable.

Is it a weekend project? Yes. Is it doable? Also yes.

## Troubleshooting

**Talos nodes show up as `NotReady`.**
Check the [Omni dashboard](https://omni.siderolabs.com/). Probably machine classes aren't registered yet — run `task cluster:init`.

**`tofu taint` doesn't trigger a rebuild.**
`task infra:status` generates a plan file (`tfplan`). `task infra:create` applies that file. If you ran `taint` after generating the plan, rerun `task infra:status` first.

**A secret in cloud-init needs to change without rebuilding the VM.**
Cloud-init values are embedded at VM creation time. For post-boot secret rotation, use a real config-management path (Ansible, SSM, etc.) — this layer isn't the right tool.

## License

See [../LICENSE](../LICENSE).
