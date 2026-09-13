# ETS model of the software bus participants

Three bus participants exist as software, not hardware: the **KNX-NATS
bridge**, the **Basalte Core S4** visualisation and **Node-Red**. Each is
modelled in ETS as a real device whose product database is _generated_
from this repo — ETS is the checkable view, lares is the source. The
historical GIRA placeholders ("dummies") are being retired; see the
migration section. Decisions and their rejected alternatives:
[ADR-0001](../adr/0001-collector-objects-from-config-for-software-bus-devices.md),
[ADR-0002](../adr/0002-coupler-forwarding-carries-bus-visibility.md).
Migration tracker: issue #1557.

## Which command, when

Start from what happened. Every path ends in the same verification.

```mermaid
flowchart TD
    A["Something changed in lares<br/>(writer rule, consumer)"] --> G
    B["Something changed in Basalte Studio<br/>or in a Node-Red flow"] --> E["Export it into exports/"] --> G
    C["Something changed in ETS<br/>(addresses, links, devices)"] --> X
    G["<b>task knx:ets-devices</b>"] --> D{"What does it say<br/>per device?"}
    D -- "same objects —<br/>no publish needed" --> L["ETS: link the new addresses<br/>per <i>device</i>-wiring.md"]
    D -- "N new, M renumbered —<br/>publish" --> K["Kaenx-Creator: open .ae-manu<br/>→ Veröffentlichen"]
    D -- "links on dropped objects —<br/>nothing written" --> S["STOP. Unlink them in ETS<br/>(check-wiring: 'unclaimed')."]
    K --> I["ETS: import .knxprod → add the new version<br/>as a 2nd device → drag the links over<br/>per worksheet ('war N') → delete the old device"] --> L
    L --> X["ETS: export → exports/ets/"]
    X --> V["<b>task knx:catalog</b><br/>(runs check-wiring)"]
    V --> R{"all devices OK?"}
    R -- no --> T["work through<br/><i>device</i>-wiring-todo.md"] --> X
    R -- yes --> Z["commit catalog + versions.yaml"]
```

| Task                    | Run it when                                                                                 | Reads                                                                             | Writes                                                                 |
| ----------------------- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `task knx:ets-devices`  | a footprint changed (lares config, Studio export, flows) — or you are unsure whether it did | the three footprints, the ETS export, the template, `scripts/kaenx/versions.yaml` | `~/Downloads/<device>.ae-manu` + `-wiring.md`; updates `versions.yaml` |
| `task knx:catalog`      | after **every** ETS export                                                                  | the ETS export                                                                    | `ga-catalog.yaml`, then runs `check-wiring`                            |
| `task knx:check-wiring` | on demand, to see what is still open                                                        | the ETS export, the three footprints                                              | `~/Downloads/<device>-wiring-todo.md` per device with findings         |

All three need `KNXPROJ_PASSWORD=…` in the environment; without it they
stop with one sentence saying so.

## The chain at a glance

```
1  SOURCES — each system states its own footprint, where it is configured
     bridge:   writer-rules.yaml + *_from_knx consumers  (kubernetes/, deployed)
     Basalte:  exports/basalte/Steinroth.bcfg            (Studio export)
     Node-Red: exports/node-red/flows.json               (flow export)

2  ONE COMMAND:  task knx:ets-devices
     reads the three sources
     + exports/ets/Steinroth.knxproj    (names, DPTs, and what is installed)
     + scripts/kaenx/template.ae-manu   (Kaenx version specifics)
     + scripts/kaenx/versions.yaml      (version last handed out — see below)
     writes per device to ~/Downloads:
       <device>.ae-manu       Kaenx-Creator project, collector objects
       <device>-wiring.md     checklist: which addresses on which object,
                              per object "NEU" or "war N" (old number)
     and tells you per device: "only links" or "publish"

3  ON THE ETS VM (only when step 2 said "publish")
     Kaenx-Creator: open the .ae-manu → publish → .knxprod
     ETS: import the product → add the new version as a second device
          → drag the links over per worksheet: object "war N" gets
            the links of the old device's object N
          → delete the old device, give the new one its address
     then, always: link the new addresses per worksheet

4  BACK (verification)
     fresh ETS export into exports/ets/ → task knx:catalog
     check-wiring runs with it and leaves a todo worksheet per open device
     all green ⇒ commit ga-catalog.yaml and versions.yaml
```

## Why every change is a new device — and numbers are positional

ETS's own "Aktualisieren" keeps a device's parameters but **not its
group links** — tested twice on these products on 2026-09-13, with
unchanged numbers as much as with shifted ones. A new application
version therefore goes in as a **second device** next to the installed
one, and the links are dragged over object by object; then the old
device is deleted and the new one takes its address. Under five minutes
for a hundred objects.

Since the links move by hand anyway, stable numbers buy nothing. The
object numbers are **positional** — main group, datapoint type, sending
before receiving — so every object sits where it belongs and the
object list reads like the group-address tree. When the object set
changes, numbers shift; the worksheet says per object `NEU` or `war N`
(its number on the old device), which is all the drag-over needs.

The generator compares against the device in the ETS export (objects
matched by name) and says per device: "same objects — only links", or
"N new, M renumbered — publish". It refuses to write when an installed
object that still carries links has disappeared — no source claims those
addresses any more; unlink them in ETS (check-wiring lists them as
"unclaimed"), or pass `--accept-loss` if dropping them is intended.

`scripts/kaenx/versions.yaml` records the application version last
handed to Kaenx-Creator per device; the generator maintains it and you
commit it. It exists because ETS remembers every version it ever
imported — also ones deleted from the catalog — and silently ignores a
re-import, so the next publish must go above what was handed out, not
just above what the export shows installed.

## Target picture

| Device          | Address source (the footprint)                                                                                    | Objects   | Flags          |
| --------------- | ----------------------------------------------------------------------------------------------------------------- | --------- | -------------- |
| KNX-NATS-Bridge | `writer-rules.yaml` targets (Transmit+Read) ∪ consumed addresses from the `*_from_knx` consumer manifests (Write) | ~55       | per direction  |
| Basalte Core S4 | Studio-export bindings (`scripts/basalte_gas.py` on `exports/basalte/*.bcfg`)                                     | ~95       | Write+Transmit |
| Node-Red        | flow-export addresses (`scripts/node_red_gas.py` on `exports/node-red/flows.json`)                                | a handful | Write+Transmit |

Objects are **collectors**: one per main group × datapoint type — the
exact subtype (5.001, 9.001, …), with a main-type fallback for
addresses ETS types loosely — per direction on the bridge, named after
the ETS group-range names and grouped per main group in the object
tree. Every address of a kind is linked to its collector — which is why
wiring is a multi-select per object, not per address.

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

Inputs: the in-repo ETS export (names, DPTs, group-range names, and the
installed applications), the writer rules, the consumer manifests, the
Basalte Studio export, the Node-Red flow export and the versions file.
Foreign-system exports live in `exports/` (see its README);
lares' own deployed truths stay under `kubernetes/`. Template:
`scripts/kaenx/template.ae-manu` — an empty project saved once by the
ETS VM's Kaenx-Creator installation; it supplies everything
version-specific (mask, load procedures, language).

Output per device: `<slug>.ae-manu` (the Kaenx-Creator project) and
`<slug>-wiring.md` (the wiring worksheet: per collector, exactly the
addresses to link; against the installed device each object is marked
`NEU` or `war N`, and dropped objects are listed). Addresses without a DPT,
with a DPT unknown to Kaenx-Creator, or listed in a footprint but absent
from ETS are reported; the last case fails the run — configuration
pointing at nothing is the wiring error this model exists to expose.

On the ETS VM, when the run said "publish": open the `.ae-manu` in
Kaenx-Creator → Veröffentlichen → import the `.knxprod` into ETS → add
the new version as a **second device** next to the installed one → per
worksheet, drag the links of the old device's object N onto the new
object marked `war N` → delete the old device → give the new one the
old individual address. Do **not** use "Aktualisieren"
on the existing device: it keeps parameters and drops every link. Then
link the new addresses per worksheet (sort the GA list, multi-select a
block, drag onto the collector).

## Growth and maintenance

- **New address of an existing kind** — same main group, datapoint
  type and direction as an existing collector: the generator says "only
  links"; link it in ETS, no Kaenx round trip. `task knx:check-wiring`
  nags until the link exists.
- **New kind, or a footprint change** (first address of a subtype in a
  main group, new consumer, new Basalte datapoint or flow kind):
  re-export the changed system into `exports/` first, then regenerate;
  the generator says "N new, M renumbered — publish". The worksheet maps
  every object to its number on the old device, so the drag-over onto
  the new device instance is one look-up per object.
- **Identity, do not touch**: per-device GUID (deterministic), serial and
  order number (name slug), application number (100/101/102 by task
  order).
- **Versions take care of themselves**: the generator takes the highest
  of the installed version and `versions.yaml`'s last-published one and
  bumps it — only when the objects changed. The version is a single byte
  shown by ETS as high.low nibble: 16 = 1.0, 17 = 1.1, 32 = 2.0. No
  hand-bumping in the Kaenx publish tab.

## Verification

- `task knx:catalog` after every ETS export — the `writable` diff is the
  acceptance test for flag correctness.
- `task knx:check-wiring` compares the ETS export against the
  footprints: rule without link, link without rule, wrong or additional
  direction, link on the wrong object, and leaves a rest worksheet per
  device with findings — under the object numbers of the device in the
  project, also while that is still an older version. Runs
  after every `knx:catalog` and on demand; it is deliberately not a CI
  gate, because the in-repo ETS export legitimately lags lares changes.

## Before you touch a device in ETS

Export the project into `exports/ets/` first. The export is the backup:
it holds every link, and `task knx:catalog` on it tells you the link
count per device before and after. Keep the previous export under
`exports/ets/backups/` (git ignores `*.knxproj`) until the new state is
verified. Writing links into an export from outside ETS was tried and
ETS refuses to import the result — the export is for reading only.

## Migration (one-time)

Order matters: generate → publish → import → wire per worksheet → set the
coupler forwarding → fresh ETS export into the repo → `task knx:catalog`
green → `task knx:check-wiring` green → **only then** delete the
placeholders. Until then the placeholders stay as the safety net that
keeps every address crossing the couplers. Node-Red is done. The bridge
is wired, but the wallbox trigger addresses (1.017) gave it and Basalte
a new object each, so both go through a V 1.3 rebuild; Basalte is
installed at V 1.1 and being linked per worksheet — `task knx:catalog`
leaves the rest list in `~/Downloads/basalte-core-s4-wiring-todo.md`
after every export. Status lives in issue #1557.
