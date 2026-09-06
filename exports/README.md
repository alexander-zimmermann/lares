# Exports

Exports from the systems around lares, one directory per system. Each
file here is that system's own configuration — the source of truth for
what it does on the KNX bus — consumed by the generation and check
pipelines (`task knx:*`, `task basalte:*`).

The dividing line: **`exports/` holds truths of foreign systems and is
never deployed; `kubernetes/` holds lares' own truths, which the cluster
executes** (writer rules, consumer manifests). Both feed the pipelines;
nothing lives twice.

| File | Produced by | In git? |
| --- | --- | --- |
| `ets/Steinroth.knxproj` | ETS: project export (password-protected) | no — 12 MB binary |
| `basalte/Steinroth.bcfg` | Basalte Studio: project export | no — 14 MB binary, carries token-like values |
| `node-red/flows.json` | Node-Red: menu → Export → all flows | no — carries server details |
| `kaenx/template.ae-manu` | Kaenx-Creator on the ETS VM: empty project, saved once | yes |

Re-export and overwrite in place whenever the system's configuration
changed; the tasks' preconditions fail with the expected path when a
file is missing. Concept: `docs/knx/README.md`.
