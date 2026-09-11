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

## Data pipeline

- **Sidecar** — a satellite repository of lares that builds one image or
  library lares deploys: the `*-nats-bridge` repos, `iot-mcp-bridge`,
  `iot-insights-engine`, `nats-archive-compactor`,
  `cnpg-postgres-timescaledb` and `nats-bridge-core`. Not a Kubernetes
  sidecar container. Avoid: side-car, split repo.
- **Sidecar bridge** (avoid: device bridge) — a sidecar that translates one
  device family's native protocol into NATS subjects and back: the KNX,
  Dyson, Miele, Midea and Bordbar bridges. Unqualified, "the bridge" always
  means the KNX-NATS bridge, which is also a software bus participant.
  `iot-mcp-bridge` is not one: it fronts the archive for MCP, no device.
- **Stream** — a JetStream stream: the retained subject space of one source
  (`KNX`, `DYSON`, `WARP`, …), declared as a `Stream` CRD. Never a
  redpanda-connect stream; that is a pipeline.
- **Pipeline** (avoid: connect stream, ingest stream) — one redpanda-connect
  configuration of input, processors and output, one file under
  `redpanda-connect/base/streams/`. Ingest pipelines write to TimescaleDB
  and the parquet archive; `*_from_knx` pipelines turn bus writes on
  consumed addresses into commands.
- **Command** — a message that tells a sidecar bridge or device to act, as
  opposed to the state and events it reports. From the KNX side a command
  starts as a bus write on a consumed address and leaves the bus through a
  `*_from_knx` pipeline.
- **Episode** (avoid: alert, incident, anomaly) —
  repeated observations of one fault on one subject, folded into a single
  situation with a start, an end and a severity trajectory. The unit that
  reports, notifications and verdicts address; the per-bucket observations
  stay underneath it as evidence.
- **Episode event** — one of the three notification events an episode
  emits: appeared, escalated, ended. Published by the engine as
  `episode.<kind>` and the house-side trigger for Explain.
- **Verdict** (avoid: feedback, rating) — a person's
  binary judgement on one episode: it was `real`, or it was `nonsense`.
  Given in conversation through `set_episode_verdict`, one row per episode,
  overwritten rather than duplicated on second thought. Nothing reads it to
  change behaviour — the counts per fault are what a threshold gets moved
  against, by hand.

## Agents

- **Agent** (avoid: bot, AI layer) — a model with tools and a
  standing assignment that runs without a person in the loop, started by an
  event or a schedule. A person chatting through the MCP bridge is not an
  agent: the person drives.
- **Harness** (avoid: runtime, platform, framework) — the program that runs
  an agent's loop: takes the assignment, calls the model, executes tools,
  stops. HolmesGPT, kagent, the Codex CLI and Hermes are harnesses. Which
  one runs is a decision on the map, not part of the term.
- **Model source** (avoid: provider, backend, gateway) — where an agent's
  model comes from and how it is paid for: a subscription, a metered API,
  or a machine in the house.
- **Subject** — what an explanation is about: one episode (house) or one
  firing alert group (cluster). Not the episode's own `subject` column,
  which names the channel a fault was measured on; say "channel" for that.
  Never a NATS subject; say "NATS subject".
- **Use case** — one declared entry of the agent platform: a trigger, an
  assignment, an allowed tool list, an output kind and a budget. Declared
  in a file in this repo; adding one is a pull request, never a rebuild.
- **Run** — one execution of a use case, from trigger to output, recorded
  as one row with its subject, model, cost, tool trace and verdict.
- **Explain** — the agent role that takes one
  episode or one firing alert, gathers the evidence around it and attaches a
  grounded reason. Never runs without a subject: explaining is not
  screening.
- **Explanation** — the stored result of one Explain run: a one-line
  cause, the evidence with the query behind each claim, what could not be
  verified, and the run's model and cost. Keyed by its subject and
  delivered on the subject's own channel; never pushed to KNX.
- **Propose** — the agent role that periodically
  reads episodes, verdicts and data and offers changes to the fault list as
  pull requests: a new fault sentence, a moved threshold, a dormant fault to
  activate. A person merges or discards; nothing is applied automatically.
- **Answer** — a person asking about house or
  cluster data in conversation through the MCP bridge. Not an agent role.
