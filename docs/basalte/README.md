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

## Which address a room's thermostat reads

```
task basalte:thermostats                      # uses docs/basalte/Steinroth.bcfg
```

Prints, per room, the temperature and setpoint addresses its thermostat is bound
to, resolves them through the GA catalog, and checks the `fbh_cold` entry of the
fault list against them — the fault measures the room against the same value the
app shows, so the mapping is read from the export instead of transcribed. Exits
non-zero when a thermostat reads an address belonging to another room or one the
catalog does not know.

## What else lives here

`logic-blocks-reference.md` — the reference for Basalte's logic blocks (what
`chrono`, `multiplexer` and `changedetector` do, with inputs and outputs).

It describes the **product**, not this house, so it belongs in the wiki. It sits
here only until the wiki can be read by an agent; without that it would not be
reachable at all. Delete it on the move rather than keeping two copies.
