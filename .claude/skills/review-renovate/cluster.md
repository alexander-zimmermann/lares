# Layer 2 — `cluster/` · Omni + Talos

## Context

- `cluster/homelab-cluster-prod.yaml` is the Omni cluster template. It pins the Talos version (`talos.version`, release notes in siderolabs/talos) and the Kubernetes version (`kubernetes.version`, tracked through the `ghcr.io/siderolabs/kubelet` image; release notes in kubernetes/kubernetes, `CHANGELOG/CHANGELOG-<major.minor>.md`).
- Machine config patches sit in `cluster/patches/*.yaml`, the machine classes in `cluster/homelab-machine-classes.yaml`.
- Nothing applies on merge: `task cluster:create` (`omnictl cluster template sync`) runs by hand, and Omni then upgrades the nodes one at a time. Until then the nodes run what `https://kromgo.zimmermann.sh/talos_version` and `https://kromgo.zimmermann.sh/kubernetes_version` show.
- Renovate bounds the Kubernetes version before each run: at most the newest one the pinned Talos supports, and at most one minor above the current one, which is all Omni accepts per sync.
- A Talos minor also needs an Omni that supports it; Omni's version sits in `infrastructure/templates/30-cloud-init/cluster-mgmt/omni-bootstrap.conf.tftpl`.
- High blast radius: every bump here reaches every node.

## Step 4: diff the machine config and the APIs

- Talos: check every field our patches set against the config changes in each release's upgrade notes: renamed, removed, changed default.
- Kubernetes: list the APIs the new minor removes or deprecates (the changelog's deprecation and API change notes) and grep `apiVersion:` under `kubernetes/` for each.
- A minor's changelog holds every release from alpha on, about 400,000 characters. Read it only down to the first `# v<minor>.0-rc` heading, without the download tables, in one call (a pipe into `sed` with a pattern is denied): `gh api "repos/kubernetes/kubernetes/contents/CHANGELOG/CHANGELOG-<minor>.md" --jq '.content | @base64d | split("\n# v<minor>.0-rc")[0] | split("\n") | map(select(test("^(\\[|filename |-------- )") | not)) | join("\n")'`. The `.0` section ("Changelog since v<previous minor>.0") already holds every alpha, beta and rc note; its Urgent Upgrade Notes, Deprecation and API Change sections carry what the minor removes or changes.

Done when every field our patches set and every removed or deprecated API is accounted for.

## Step 5: checks

- For a Kubernetes minor, check that each high-blast-radius component in `kubernetes.md` supports the new minor at the version lares pins. Fetch these pages with WebFetch, all in one turn. `<minor>` is the component's own version, for a wrapper chart its `appVersion`:
  - cilium: `https://docs.cilium.io/en/v<minor>/network/kubernetes/compatibility/`
  - kyverno: `https://kyverno.io/docs/releases/`
  - cert-manager: `https://cert-manager.io/docs/releases/`
  - cnpg: `https://cloudnative-pg.io/docs/<minor>/supported_releases/`
  - argo-cd: `https://argo-cd.readthedocs.io/en/stable/operator-manual/tested-kubernetes-versions/`
  - longhorn: `https://longhorn.io/docs/<version>/important-notes/`, a minimum only
  - traefik, sealed-secrets, nats, rustfs publish no range; their chart's `kubeVersion` sets a minimum at most.
- A component whose range ends below the new minor is a breaking change. Otherwise record all ten in one Not applicable line: each range, and which publish none.

Done when each of the ten has its range from these pages or is named as publishing none.

## After merge

Nothing changes until the next template sync. After merge says what that sync will do: a Talos bump reboots every node in turn, a Kubernetes bump rolls the control plane components and the kubelets. Only prod has nodes: the dev template runs nowhere.
