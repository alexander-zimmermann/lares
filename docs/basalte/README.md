# Basalte

## Where the Studio export goes

`docs/basalte/Steinroth.bcfg` — export it there and leave it there.

The file is **not** in the repo (`*.bcfg` is in `.gitignore`), the same way the
ETS export `Steinroth.knxproj` is not. Two reasons: it is 14 MB of binary, and
it carries at least one value that looks like an access token — unverified, but
reason enough not to publish it.

## Regenerating the inventory

```
task basalte:inventory                        # uses docs/basalte/Steinroth.bcfg
task basalte:inventory -- /path/to/export.bcfg
```

Writes `logic-inventory.md`. Regenerate after every change in Basalte Studio and
read the diff — that shows what changed without opening Studio.

## Does Basalte still agree with ETS?

```
task basalte:sync                             # uses docs/basalte/Steinroth.bcfg
```

Basalte holds the bus twice: the imported ETS project, and a copy of the address
name inside every device and logic block that was wired with it. Rename or
renumber in ETS afterwards and the copies stay behind — harmless where only the
name moved, wrong where the address did.

The check reports both, plus whatever the catalog does not know at all, and
exits non-zero only on a moved address. Run it after every ETS change and after
every re-import.

It compares against `ga-catalog.yaml`, which is a snapshot: rebuild it with
`task knx:catalog` before believing a finding. When the export's own import layer
is behind, the check says so and stops listing the name drift — everything is
stale by construction until Studio has re-imported.

## What else lives here

`logic-blocks-reference.md` — the reference for Basalte's logic blocks (what
`chrono`, `multiplexer` and `changedetector` do, with inputs and outputs).

It describes the **product**, not this house, so it belongs in the wiki. It sits
here only until the wiki can be read by an agent; without that it would not be
reachable at all. Delete it on the move rather than keeping two copies.
