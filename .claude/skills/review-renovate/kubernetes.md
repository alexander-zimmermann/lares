# Layer 3 — `kubernetes/` · Argo CD + Manifests

## Context

- Argo CD syncs `kubernetes/` from `main`. Each app is `<group>/<app>/base` plus overlays, and only `overlays/prod` runs.
- Helm charts come in through kustomize `helmCharts` in `base/kustomization.yaml`, with our overrides in `base/values.yaml`; overlays patch the rendered resources.
- Some directories name the role instead of the product: `ingress-controller` is traefik, `admission-controller` is kyverno, `gitops-controller` is argo-cd, `csi-block-storage-controller` is longhorn. Find the consumers of a component by grepping its chart or image name.
- Charts under `oci://ghcr.io/alexander-zimmermann/charts/*-chart` are mirrors of Docker Hardened Images charts (`dhi.io`), each wrapping an upstream chart.
- High blast radius, research these deepest: cilium, traefik, longhorn, cnpg, kyverno, cert-manager, sealed-secrets, argo-cd, nats, rustfs.

## Step 4: diff the chart values

For a Helm chart, diff its `values.yaml` in the chart's source repo between the old and the new tag (compare filter `.filename | endswith("values.yaml")`) and check every key in our `base/values.yaml` against it: renamed, moved, removed, changed default, new required key. A chart's source repo is the source link in the PR body, or else the `sources` entry of its version in `<chart repo URL>/index.yaml`. The repo behind a `github.io` chart URL often holds only the packaged charts, and a monorepo keeps the chart in a subfolder such as `helm/<chart>/`.

Then name every default image that moves and that lares leaves unpinned, old → new: an image tag in that diff, or for an operator the default image of the workloads it manages, read from its source at both tags. Renovate opens no PR for these images, so this review is the only place they show. Read each one's notes from old to new, in the repo that builds it, which need not carry the image's name (Tools: An image's source repo).

Done when every key we set is accounted for and every moved default image is named.

## Step 5: checks

- A label value or resource name can change under an unchanged key, so grep for what selects on or refers to the value: monitor and network-policy selectors, PodDisruptionBudgets, PromQL in rules, dashboards and Gatus endpoints, `<name>.<namespace>.svc` addresses.
- Check a new minimum version of Talos, Kubernetes or the kernel against what the nodes run, at `https://kromgo.zimmermann.sh/talos_version` and `https://kromgo.zimmermann.sh/kubernetes_version`. `cluster/homelab-cluster-prod.yaml` holds the target, and the nodes run behind it until the next template sync.
- An MCP server's tools are allowed by name in its route in `agentgateway/base/config/routes.values.yaml`, in `lares-agent-trigger/base/config/use-cases.yaml` and in `hermes/base/profiles/*/config.yaml`. The agent takes the arguments from the server's schema, so check renamed and removed tools against these lists; arguments are set nowhere in lares.
- Config kept on an app's volume (Node-RED flows, Open WebUI and Wiki.js settings) is out of reach of a repo search: a change that could hit it goes under Unknowns.
- A sealed value hides its content, not its length. When a release adds a minimum length for a secret, read each key's length in bytes from the app's `sealed-secret.yaml` with this command as given (awk and interpreters are denied in CI): `gh api 'repos/<repo>/contents/<path>/sealed-secret.yaml?ref=<head sha>' --jq '.content | @base64d | split("\n")[] | capture("^\\s+(?<k>[A-Za-z0-9_.-]+): (?<v>Ag[A-Za-z0-9+/=]+)$")? | "\(.k) \((.v|length)*3/4 - (if (.v|endswith("==")) then 2 elif (.v|endswith("=")) then 1 else 0 end) - 530)"'` (530 bytes of sealing overhead with our 4096-bit key).
- The rendered diff shows what the bump changes in the cluster: check each changed resource there against the findings. When the one in `pr-context.md` is cut off, read `rendered.diff`.
- CRDs a chart renders (its `crds/` folder with `includeCRDs: true`, or CRD templates) show in the rendered diff like any other resource. A CRD update the notes announce but the rendered diff lacks is one old already shipped: Not applicable, not After merge.

Done when every changed resource of the whole rendered diff is checked.

## After merge

Argo CD syncs on merge: read After merge off the rendered diff. A cnpg operator bump also rolls every CNPG Cluster, one primary switchover each; `authentik-server` restarts once during its switchover, so Authentik is down for about a minute.
