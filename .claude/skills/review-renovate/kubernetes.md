# Layer 3 — `kubernetes/` · Argo CD + Manifests

## Context

- Argo CD syncs `kubernetes/` from `main`. Each app is `<group>/<app>/base` plus overlays, and only `overlays/prod` runs.
- Helm charts come in through kustomize `helmCharts` in `base/kustomization.yaml`, with our overrides in `base/values.yaml`; overlays patch the rendered resources.
- Some directories name the role instead of the product: `ingress-controller` is traefik, `admission-controller` is kyverno, `gitops-controller` is argo-cd, `csi-block-storage-controller` is longhorn. Find the consumers of a component by grepping its chart or image name.
- Lares is GitOps with pruning: everything that runs comes from `kubernetes/`. The one state outside the repo is data on an app's volume (Node-RED flows, Open WebUI and Wiki.js settings, Hermes sessions, databases).
- Charts under `oci://ghcr.io/alexander-zimmermann/charts/*-chart` are mirrors of Docker Hardened Images charts (`dhi.io`), each wrapping an upstream chart. DHI publishes neither notes nor source: review the upstream chart, and the upstream app at the image tag the rendered diff shows.
- Images under `ghcr.io/alexander-zimmermann/` are built by this project in the repo of the same name (`lares-*`, `*-nats-bridge`, `nats-archive-compactor`, `cnpg-postgres-timescaledb`, `hermes-agent-patched`). Their dependency bumps went through that repo's own PRs and CI and are no finding here: review the compare's commits and source files outside the lockfiles against what lares sets (env vars, config, NATS subjects, tool names).
- `hermes-agent-patched` is upstream Hermes (`NousResearch/hermes-agent`, the inner component) plus `patches/*.patch`. Its build fails when a patch no longer applies or is already upstream, so a release that exists proves every patch holds. Hermes patch releases are roll-ups without itemised notes.
- A CNPG `imageName` (`ghcr.io/cloudnative-pg/postgresql`, `cnpg-postgres-timescaledb`) has PostgreSQL as its inner component, with notes at `https://www.postgresql.org/docs/release/<version>/` (WebFetch). Check every key under `postgresql.parameters` against them. For a major, the operator runs `pg_upgrade`: check the operator version the rendered cnpg Deployment runs against `https://cloudnative-pg.io/docs/<minor>/supported_releases/`.
- High blast radius, research these deepest: cilium, traefik, longhorn, cnpg, kyverno, cert-manager, sealed-secrets, argo-cd, nats, rustfs.

## Step 5: compare what lares sets

**A Helm chart.** Diff its `values.yaml` in the chart's source repo between the old and the new tag (compare filter `.filename | endswith("values.yaml")`) and check every key in our `base/values.yaml` against it: renamed, moved, removed, changed default, new required key. A chart's source repo is the source link in the PR body, or else the `sources` entry of its version in `<chart repo URL>/index.yaml`. The repo behind a `github.io` chart URL often holds only the packaged charts, and a monorepo keeps the chart in a subfolder such as `helm/<chart>/`.

Then name every default image that moves and that lares leaves unpinned, old → new: an image tag in that diff, or for an operator the default image of the workloads it manages, read from its source at both tags. Renovate opens no PR for these images, so this review is the only place they show. Read each one's notes from old to new, in the repo that builds it, which need not carry the image's name (step 1).

**An image**, whether the PR bumps it or a chart default moves it. Its notes carry the review when they list their changes and no change reaches what lares sets. When they do not list their changes, or a note reaches an item without settling it, look the items up in the source:

- Where upstream defines an env var, config key, argument or path: `gh api -X GET search/code -f q='"<name>" repo:<owner>/<repo>' --jq '.items[].path'`, several names in one turn. The search covers the default branch only, so it finds paths and proves nothing about a tag: a name counts as removed only when its file at the old tag has it and the file at the new tag does not.
- What changed there in the range: the per-file calls of step 5. Compare the lines that name the item at both tags. When they differ, or the commits that touched the file change how it reads its settings, read the patch of every such commit: a title need not name the item it changes.
- What an image holds: its Dockerfile at the new tag shows which folders it copies and which versions it pins. In a monorepo, a change under a copied folder ships in the image even when the release notes name only the app.

Done when every values key lares sets is accounted for, every moved default image is named, and for an image without itemised notes every item of the list has the same lines at both tags or its change is read.

## Step 6: checks

- A label value or resource name can change under an unchanged key, so grep for what selects on or refers to the value: monitor and network-policy selectors, PodDisruptionBudgets, PromQL in rules, dashboards and Gatus endpoints, `<name>.<namespace>.svc` addresses.
- Check a new minimum version of Talos, Kubernetes or the kernel against what the nodes run, at `https://kromgo.zimmermann.sh/talos_version` and `https://kromgo.zimmermann.sh/kubernetes_version`. `cluster/homelab-cluster-prod.yaml` holds the target, and the nodes run behind it until the next template sync.
- An MCP server's tools are allowed by name in its route in `agentgateway/base/config/routes.values.yaml`, in `lares-agent-trigger/base/config/use-cases.yaml` and in `hermes/base/profiles/*/config.yaml`. The agent takes the arguments from the server's schema, so check renamed and removed tools against these lists; arguments are set nowhere in lares.
- Data on an app's volume is out of reach of a repo search. When a note names a change to it (a schema or storage migration, a rewritten setting), say under After merge what to look at; when the migration cannot be undone, the backup goes under Before merge.
- A sealed value hides its content, not its length. When a release adds a minimum length for a secret, read each key's length in bytes from the app's `sealed-secret.yaml` with this command as given (awk and interpreters are denied in CI): `gh api 'repos/<repo>/contents/<path>/sealed-secret.yaml?ref=<head sha>' --jq '.content | @base64d | split("\n")[] | capture("^\\s+(?<k>[A-Za-z0-9_.-]+): (?<v>Ag[A-Za-z0-9+/=]+)$")? | "\(.k) \((.v|length)*3/4 - (if (.v|endswith("==")) then 2 elif (.v|endswith("=")) then 1 else 0 end) - 530)"'` (530 bytes of sealing overhead with our 4096-bit key).
- The rendered diff shows what the bump changes in the cluster: check each changed resource there against the findings. When the one in `pr-context.md` is cut off, read `rendered.diff`.
- CRDs a chart renders (its `crds/` folder with `includeCRDs: true`, or CRD templates) show in the rendered diff like any other resource. A CRD update the notes announce but the rendered diff lacks is one old already shipped: Not applicable, not After merge.

Done when every changed resource of the whole rendered diff is checked.

## After merge

Argo CD syncs on merge: read After merge off the rendered diff. A cnpg operator bump also rolls every CNPG Cluster, one primary switchover each; `authentik-server` restarts once during its switchover, so Authentik is down for about a minute.
