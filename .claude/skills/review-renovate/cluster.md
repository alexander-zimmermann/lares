# Layer 2 — `cluster/` · Omni + Talos

## Context

- `cluster/homelab-cluster-prod.yaml` is the Omni cluster template. It pins the Talos version (`talos.version`, release notes in siderolabs/talos) and the Kubernetes version (`kubernetes.version`, tracked through the `ghcr.io/siderolabs/kubelet` image; release notes in kubernetes/kubernetes, `CHANGELOG/CHANGELOG-<major.minor>.md`).
- Machine config patches sit in `cluster/patches/*.yaml`, the machine classes in `cluster/homelab-machine-classes.yaml`.
- Nothing applies on merge: `task cluster:create` (`omnictl cluster template sync`) runs by hand, and Omni then upgrades the nodes one at a time. Until then the nodes run what `https://kromgo.zimmermann.sh/talos_version` and `https://kromgo.zimmermann.sh/kubernetes_version` show.
- Renovate bounds the Kubernetes version before each run: at most the newest one the pinned Talos supports, and at most one minor above the current one, which is all Omni accepts per sync.
- A Talos minor also needs an Omni that supports it; Omni's version sits in `infrastructure/templates/30-cloud-init/cluster-mgmt/omni-bootstrap.conf.tftpl`.
- High blast radius: every bump here reaches every node.

## Step 3: diff the machine config and the APIs

- Talos: check every field our patches set against the config changes in each release's upgrade notes: renamed, removed, changed default.
- Kubernetes: list the APIs the new minor removes or deprecates (the changelog's deprecation and API change notes) and grep `apiVersion:` under `kubernetes/` for each.

Done when every field our patches set and every removed or deprecated API is accounted for.

## Step 4: checks

- For a Kubernetes minor, check that each high-blast-radius component in `kubernetes.md` supports the new minor at the version lares pins, from its docs' compatibility matrix.

## After merge

Nothing changes until the next template sync. After merge says what that sync will do: a Talos bump reboots every node in turn, a Kubernetes bump rolls the control plane components and the kubelets.
