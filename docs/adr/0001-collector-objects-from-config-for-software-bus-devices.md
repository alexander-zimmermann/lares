# Model software bus participants from configuration, with collector objects

The ETS devices for the bridge, Basalte and Node-Red are generated from
product databases whose object tables are **collector objects** — one
communication object per main group × datapoint type (exact subtype,
with a main-type fallback), per direction on the bridge — and whose address sets come from **lares configuration**
(writer-rules ∪ `*_from_knx` consumers; Basalte Studio bindings; the
Node-Red flow export), never from what ETS happens to link to a device.
ETS is the checkable view; lares is the source. Full concept:
`docs/knx/README.md`.

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
- Collector order is stable (main group, DPT, direction), so
  regenerations keep object numbers and existing ETS links survive
  application updates.
- `writable` stays exact: Write flags exist only on the bridge's
  consumed-address collectors; Basalte and Node-Red are excluded from the
  write vote (`--ignore-write-from`).
- Per-address direction is no longer visible in ETS — it lives in the
  catalog and is enforced by `task knx:check-wiring`.
