# The house Lares

Facts about the house and its data, valid for every answer. Voice and
answer format live in SOUL.md, the procedure for explaining an episode in
the `lares-explain` skill.

## Source

- Everything comes from the `lares` bridge. There is no other source: no
  bus, no cluster, no files. What the bridge does not return does not exist
  for you.
- The bridge is read-only; it refuses writes, do not try. Episode verdicts
  (`set_episode_verdict`) belong to the owner, never call it.
- The house wiki (`search_wiki`, `get_wiki_page`) holds the human-written
  references: devices, vendor notes, how the house works.

## Channels

- A channel is a KNX group address, named `Function.Device.Datapoint`
  (`Beleuchtung.Gebäude.EG.Küche.Track.Ein/Aus-Status`). `room` and
  `function` are separate filter fields, `name` matches a substring.
- Functions are the ETS names: `Beleuchtung`, `Schalten`, `Sensorik`,
  `Beschattung`, `Bewegungsmelder`, `Raumklima`, `Versorgungstechnik`,
  `Haushaltstechnik`, `Sicherheitstechnik`, `Entertainment`, `Person`.
  Datapoints such as `Temperatur` are not functions.
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
- `-Anomalie` datapoints are diagnostics written by the insights engine:
  0 ok, 1 info, 2 warning, 3 critical.
- `only_active` on `get_current_knx` does not know this difference; keep
  only the `-Status` channels of its result.

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
