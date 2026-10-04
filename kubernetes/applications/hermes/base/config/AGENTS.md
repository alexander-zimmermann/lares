# The house Lares

Facts about the house and its data, valid for every answer. Voice and
answer format live in SOUL.md, the procedure for explaining an episode in
the `lares-explain` skill.

## Source

- Everything about the house comes from the `lares` bridge. There is no
  other source for it: no bus, no cluster, no files. What the bridge does
  not return does not exist for you.
- The bridge is read-only; it refuses writes, do not try. Verdicts
  (`set_verdict`, on an episode or on a run) belong to the owner, never
  call it.
- The house wiki (`search_wiki`, `get_wiki_page`) holds the human-written
  references: devices, vendor notes, how the house works.
- The backup server (`list_pbs_datastores`, `list_pbs_snapshots`,
  `list_pbs_tasks`) says what the PBS holds and whether it was verified; a
  job state `null` means it never ran, not that it passed.
- The object store (`list_s3_buckets`, `list_s3_objects`) holds the
  database and volume backups and the archive; `nats-archive` and
  `influxdb-archive` are the history older than a year and exist nowhere
  else. Its newest objects say whether the backups still arrive.
- Where they are offered, the `github` tools read GitHub as a read-only
  App: the owner's repositories under `alexander-zimmermann`.
  Every issue lives in `lares`, the cluster's GitOps repository; one about
  another repository carries its name as title prefix (`lares-mcp-bridge:
  …`). They read only; never offer to open, comment on or label anything.

## Channels

- A channel is a KNX group address, named `Function.Device.Datapoint`
  (`Beleuchtung.Gebäude.EG.Küche.Track.Ein/Aus-Status`). `room` and
  `function` are separate filter fields, `name` matches a substring.
- Functions are the ETS names, all sixteen of them: `Allgemein`,
  `Bedienelement`, `Beleuchtung`, `Beschattung`, `Bewegungsmelder`,
  `Diagnose`, `Entertainment`, `Haushaltstechnik`, `Person`, `Raumklima`,
  `Schalten`, `Sensorik`, `Sicherheit`, `Sicherheitstechnik`,
  `Versorgungstechnik`, `Zutritt`. Datapoints such as `Temperatur` are not
  functions.
- A room carries the ETS space id: `Büro (E3)`, `Flur (K1)`, `Küche (E6)`.
  Pass it whole. The id is what tells rooms of the same name apart — there
  are three `Flur`, one per storey, and a `Garten` building part beside the
  `Garten (G5)` room inside it. `query_room_climate` names every valid room
  when it does not know the one you passed.
- Names, rooms and datapoints are German; keep them verbatim.

## Command and state

- On actuators (lights, blinds, switches) the datapoint without suffix is
  the command: `Ein/Aus`, `Dimmen-Absolut`, `Dimmen-Relativ`, `Farbwert`,
  `Farbtemperatur`, `Sperren`. Its retained value is the last order sent,
  however old, and says nothing about the device now.
- The datapoint ending in `-Status` is the state: `Ein/Aus-Status`,
  `Dimmen-Status`, `Farbwert-Status`. "Is it on?", "what is on?", "how
  bright?" are answered from these only. A dimmer with a command value of
  100 % and a status of off is off.
- Measurements (temperature, humidity, current, power) are state by
  nature; a value is as old as its timestamp.
- `-Anomalie` datapoints are diagnostics written by the diagnostics engine:
  0 ok, 1 info, 2 warning, 3 critical.
- `get_current_knx` marks every value with its `role`: `status`, `command`
  or `reading`, and `only_active` drops commands. Answer state questions
  from `status` and `reading` rows.

## Silence

- Commands, status and diagnostic channels send on change only. A channel
  silent for days is usually one nobody touched; "unchanged" is the
  reading, not "dead".
- Measuring channels send on their own; silence there points at the sender
  or its bridge, and the siblings of the same device tell which.

## History

- `knx` holds raw telegrams, `knx_1h` hourly aggregates. Never read raw
  data over more than one day; the database is small.
- An episode is one fault on one channel over time: start, severity curve,
  observations. The fault says what was measured; the cause is your job.
