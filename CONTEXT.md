# Glossary

Terms this repo uses with a specific meaning. Use these words, not synonyms.

## KNX / ETS modelling

- **Software bus participant** — a bus participant that exists as software,
  not hardware: the KNX-NATS bridge, the Basalte visualisation, Node-Red.
  Each is modelled in ETS as a real device generated from a product database
  (see `docs/knx/README.md`), never hand-maintained.
- **Placeholder** (historically: dummy) — a GIRA dummy device that carried
  group addresses only to get them into coupler filter tables. Being
  replaced by generated devices; a placeholder's link set reflects what
  accumulated, not what a system does.
- **Footprint** — the set of group addresses a software bus participant
  actually touches, as defined by its configuration (not by what ETS
  happens to link to it). The bridge's footprint is writer-rule targets
  plus consumed addresses; Basalte's is its Studio-export bindings;
  Node-Red's is the addresses its flow export touches.
- **Collector object** — one ETS communication object carrying every group
  address of one kind (main group × datapoint type, per direction on the
  bridge). The opposite of one-object-per-address.
- **Consumed address** — a group address whose bus writes a NATS consumer
  acts on (the `*_from_knx` manifests). These make `writable` true via the
  bridge's Write-flagged collectors.
- **Writer target** — a group address the bridge writes onto the bus, as
  declared in `writer-rules.yaml`.
- **writable** (catalog flag) — "writing this group address has an effect":
  some device acts on writes to it. Only real actuators and the bridge's
  consumed-address collectors may vote; visualisation-style devices are
  excluded because displaying is indistinguishable from acting.
- **Wiring** — linking group addresses to a device's objects in ETS. Done
  per collector from a generated wiring worksheet, one multi-select each.
