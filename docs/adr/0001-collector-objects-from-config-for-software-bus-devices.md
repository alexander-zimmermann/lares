# Model generated devices from configuration, with collector objects

The ETS devices for the bridge, Basalte, Node-Red and the Telenot panel
are generated from product databases whose object tables are **collector
objects** — one communication object per main group × datapoint type
(exact subtype, with a main-type fallback) × direction — and whose
address sets, each address with its direction, come from **lares
configuration** (writer-rules ∪ `*_from_knx` consumers; Basalte Studio
bindings; the Node-Red flow export; the compasX export), never from what
ETS happens to link to a device.
ETS is the checkable view; lares is the source. The terms are in
`CONTEXT.md`, the workflow is the header comment of `tasks/knx.tasks.yaml`.

## Considered options

- **One named object per group address** (first iteration, discarded):
  gives per-address naming in ETS but required ~2300 manual links to wire
  and a product update for every new address. Unmaintainable.
- **Mirroring the placeholder's links as the address source** (also
  discarded): the first real run showed the bridge placeholder carried 18
  of its 308 addresses — placeholders reflect accumulation, not behaviour.
  Deriving the model from them enshrines the accident.

## Consequences

- Wiring is one multi-select per collector (~100 operations total),
  driven by generated worksheets.
- A new address of an existing kind is one ETS link, no product update;
  only a new (main group × DPT) combination regenerates a product.
- ~~Collector order is stable (main group, DPT, direction), so
  regenerations keep object numbers and existing ETS links survive
  application updates.~~ Superseded by ADR-0003: numbers are positional
  and shift with the object set, and ETS keeps no link across an
  application update — a changed set goes in as a second device.
- `writable` stays exact: Write flags exist only on write-direction
  collectors — the bridge's consumed addresses, the Telenot's switch
  addresses; Basalte and Node-Red are excluded from the write vote
  (`--ignore-write-from`).
- Per-address direction lives in the footprint and is enforced by
  `task knx:validate-ets-devices`.
