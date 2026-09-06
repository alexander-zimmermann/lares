# ETS model of the software bus participants

Three bus participants exist as software, not hardware: the **KNX-NATS
bridge**, the **Basalte Core S4** visualisation and **Node-Red**. Each is
modelled in ETS as a real device whose product database is *generated*
from this repo — ETS is the checkable view, lares is the source. The
historical GIRA placeholders ("dummies") are being retired; see the
migration section. Decisions and their rejected alternatives:
[ADR-0001](../adr/0001-collector-objects-from-config-for-software-bus-devices.md),
[ADR-0002](../adr/0002-coupler-forwarding-carries-bus-visibility.md).
Migration tracker: issue #1557.

## Target picture

| Device | Address source (the footprint) | Objects | Flags |
| --- | --- | --- | --- |
| KNX-NATS-Bridge | `writer-rules.yaml` targets (Transmit+Read) ∪ consumed addresses from the `*_from_knx` consumer manifests (Write) | ~35 | per direction |
| Basalte Core S4 | Studio-export bindings (`scripts/basalte_gas.py` on `exports/basalte/*.bcfg`) | ~65 | Write+Transmit |
| Node-Red | flow-export addresses (`scripts/node_red_gas.py` on `exports/node-red/flows.json`) | a handful | Write+Transmit |

Objects are **collectors**: one per main group × DPT main type (per
direction on the bridge), named after the ETS group-range names and
grouped per main group in the object tree. Every address of a kind is
linked to its collector — which is why wiring is a multi-select per
object, not per address.

`writable` in the GA catalog stays exact: the only software Write flags
are on the bridge's consumed-address collectors, so "a NATS consumer acts
on this address" is visible in ETS. Basalte and Node-Red are excluded
from the write vote (`--ignore-write-from` in `task knx:catalog`),
because a visualisation receiving an address to display it is
indistinguishable from acting on it.

## Bus visibility (why the couplers forward)

The bridge mirrors the whole bus to NATS, far beyond its own footprint.
That visibility is provided by the couplers, not by objects: `1.2.0`
forwards group telegrams upstream, `1.1.0` forwards downstream; the
opposite directions stay filtered. Do not "optimise" this back to
filtering — every address missing from the filter tables disappears from
TSDB silently. Details: ADR-0002.

## Regenerating the devices

```
KNXPROJ_PASSWORD=… task knx:ets-devices [output-dir]   # default ~/Downloads
```

Inputs: the in-repo ETS export (names, DPTs, group-range names), the
writer rules, the consumer manifests, the Basalte Studio export and the
Node-Red flow export. Foreign-system exports live in `exports/` (see its
README); lares' own deployed truths stay under `kubernetes/`. Template:
`exports/kaenx/template.ae-manu` — an empty
project saved by the ETS VM's Kaenx-Creator installation; it supplies
everything version-specific (mask, load procedures, language).

Output per device: `<slug>.ae-manu` (the Kaenx-Creator project) and
`<slug>-wiring.md` (the wiring worksheet: per collector, exactly the
addresses to link). Addresses without a DPT, with a DPT unknown to
Kaenx-Creator, or listed in a footprint but absent from ETS are reported;
the last case fails the run — configuration pointing at nothing is the
wiring error this model exists to expose.

On the ETS VM: open the `.ae-manu` in Kaenx-Creator → Veröffentlichen →
import the `.knxprod` into ETS → link the addresses per worksheet
(sort the GA list, multi-select a block, drag onto the collector).

## Growth and maintenance

- **New address of an existing kind** (new switch, new fault address):
  link it to its collector in ETS. No product update. `task
  knx:check-wiring` nags until the link exists.
- **New (main group × DPT) combination, or a footprint change** (new
  writer rule kind, new consumer, new Basalte datapoint or flow kind):
  re-export the changed system into `exports/` first, then
  regenerate, publish a new application version in Kaenx-Creator, update
  the device in ETS. Collector order is stable, so existing links
  survive the update.
- **Identity, do not touch**: per-device GUID (deterministic), serial and
  order number (name slug), application number (100/101/102 by task
  order). `Application.Number` is the version byte (0x10 = V 1.0) and is
  bumped at publish time only.

## Verification

- `task knx:catalog` after every ETS export — the `writable` diff is the
  acceptance test for flag correctness.
- `task knx:check-wiring` (issue #1557 step 3) compares the ETS export
  against the footprints: rule without link, link without rule, consumed
  address not delivered. Runs after every `knx:catalog` and on demand; it
  is deliberately not a CI gate, because the in-repo ETS export
  legitimately lags lares changes.

## Migration (one-time)

Order matters: generate → publish → import → wire per worksheet → set the
coupler forwarding → fresh ETS export into the repo → `task knx:catalog`
green → `task knx:check-wiring` green → **only then** delete the
placeholders. Until then the placeholders stay as the safety net that
keeps every address crossing the couplers. Pilot device: Node-Red,
end to end, before the two big ones. Status lives in issue #1557.
