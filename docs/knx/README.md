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

## The chain at a glance

```
1  SOURCES — each system states its own footprint, where it is configured
     bridge:   writer-rules.yaml + *_from_knx consumers  (kubernetes/, deployed)
     Basalte:  exports/basalte/Steinroth.bcfg            (Studio export)
     Node-Red: exports/node-red/flows.json               (flow export)

2  ONE COMMAND:  task knx:ets-devices
     reads the three sources
     + exports/ets/Steinroth.knxproj    (only for names and DPTs)
     + exports/kaenx/template.ae-manu   (Kaenx version specifics)
     writes per device to ~/Downloads:
       <device>.ae-manu       Kaenx-Creator project, collector objects
       <device>-wiring.md     checklist: which addresses on which object

3  ON THE ETS VM (once per device version)
     Kaenx-Creator: open the .ae-manu → publish → .knxprod
     ETS: import → link addresses per worksheet, one multi-select per object
     couplers: 1.2.0 upstream and 1.1.0 downstream forward group telegrams

4  BACK (verification)
     fresh ETS export into exports/ets/ → task knx:catalog   (writable diff)
     task knx:check-wiring: ETS held against the three sources
     both green ⇒ the placeholders can go
```

Day to day there are only two cases: a **new address of an existing
kind** is one ETS link onto its collector (no generator run), and a
**changed system** means re-export, regenerate, publish a new version.
Forget either and `check-wiring` reports it.

## Target picture

| Device | Address source (the footprint) | Objects | Flags |
| --- | --- | --- | --- |
| KNX-NATS-Bridge | `writer-rules.yaml` targets (Transmit+Read) ∪ consumed addresses from the `*_from_knx` consumer manifests (Write) | ~35 | per direction |
| Basalte Core S4 | Studio-export bindings (`scripts/basalte_gas.py` on `exports/basalte/*.bcfg`) | ~65 | Write+Transmit |
| Node-Red | flow-export addresses (`scripts/node_red_gas.py` on `exports/node-red/flows.json`) | a handful | Write+Transmit |

Objects are **collectors**: one per main group × datapoint type — the
exact subtype (5.001, 9.001, …), with a main-type fallback for
addresses ETS types loosely — per direction on the bridge, named after
the ETS group-range names and grouped per main group in the object
tree. Every address of a kind is
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

- **New address of an existing kind** — same main group, datapoint
  type and direction as an existing collector: link it there in ETS.
  No product update. A first-of-its-subtype address is a new kind. `task
  knx:check-wiring` nags until the link exists.
- **New (main group × DPT) combination, or a footprint change** (new
  writer rule kind, new consumer, new Basalte datapoint or flow kind):
  re-export the changed system into `exports/` first, then
  regenerate, publish a new application version in Kaenx-Creator, update
  the device in ETS. Collector order is stable, so existing links
  survive the update.
- **Identity, do not touch**: per-device GUID (deterministic), serial and
  order number (name slug), application number (100/101/102 by task
  order).
- **Versions take care of themselves**: ETS silently refuses to
  re-import an application version it already knows, so the generator
  reads the imported version from the ETS export and writes one above
  it (a never-imported device starts at V 1.0). The version is a single
  byte shown by ETS as high.low nibble: 16 = 1.0, 17 = 1.1, 32 = 2.0.
  No hand-bumping in the Kaenx publish tab.

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
