# Exports

Exports from the systems around lares, one directory per system. Each
file here is that system's own configuration — the source of truth for
what it does on the KNX bus — consumed by the generation and check
pipelines (`task knx:*`, `task basalte:*`).

The dividing line: **`exports/` holds truths of foreign systems and is
never deployed; `kubernetes/` holds lares' own truths, which the cluster
executes** (writer rules, consumer manifests). Both feed the pipelines;
nothing lives twice.

The whole directory is git-ignored: the files are large binaries or
carry token-like values and server details.

| File | Produced by |
| --- | --- |
| `ets/Steinroth.knxproj` | ETS: project export (password-protected), 12 MB |
| `basalte/Steinroth.bcfg` | Basalte Studio: project export, 14 MB |
| `node-red/flows.json` | Node-Red: menu → Export → all flows |

Re-export and overwrite in place whenever the system's configuration
changed; the tasks' preconditions fail with the expected path when a
file is missing. Concept: `docs/knx/README.md`.
