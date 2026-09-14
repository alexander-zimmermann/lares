---
name: lares-explain
description: Explains an episode of the house Lares from its observations, the catalog and the neighbouring channels; use it when the owner asks why an episode happened.
---

# Explaining an episode

An episode is a folded incident of one fault on one channel: it has a start,
a severity curve and its observations as evidence. The fault sentence says
*what* was measured. Your job is the *why*.

## Procedure

Four steps, each with one tool call, each with one line in the answer. An
answer missing a step is not an explanation but an episode listing. The cap
of ten tool calls is a ceiling, not a target; four to six is the usual case.

1. **Subject.** `list_episodes` with the given `episode_id`. Note fault,
   channel, start, severity, observations.
2. **Channel.** `get_current_knx` with `room` and `name` (part of the channel
   name): current value, age, room, device, datapoint, unit, and the sibling
   channels of the same device. No number in the answer without its unit.
3. **History.** `query_timeseries` on `knx_1h` for the channel, from the day
   before the start until now, one-hour buckets. When was the last value,
   where is the break?
4. **Surroundings.** At least one, at most three queries, depending on the
   fault (see below). A result with zero rows is not a finding: drop the
   filter and ask again. `functions` are ETS function names such as
   `Sensorik`, `Raumklima`, `Heizung`, not datapoints such as `Temperatur`;
   when in doubt, query without the filter.

Then the cause. If the four steps yield none, "no cause in the data" is the
right first line, but only after the four steps.

## Answer format

The four proof lines start with `-# `; Discord renders them small and grey
below the cause. Tool names do not appear in the answer; the channel and the
time range are the source. Write the answer, including the labels, in the
language of the question.

```
<Cause in one sentence, or: No cause in the data.>

-# Subject: <fault, channel, since when, severity>
-# Channel: <value, age, device, room, unit, siblings>
-# History: <last value and time, break, time range>
-# Surroundings: <finding with number and unit, channel or time range>

Open: <only what the tools could not check, and why>
```

The "Open:" line is dropped when nothing was left open.

## Per fault

- **channel_silence on a switching channel** (DPT 1.x, name ends in
  Ein/Aus): the channel only sends when something is switched. Silence means
  "nobody switched" first, not "sensor dead". Check the last value and time
  with `get_current_knx`, and through it the feedback or status channel of
  the same device. Say whether the device is off or whether the feedback is
  missing too; only the second is a defect.
- **channel_silence on a status or diagnostic channel** (name ends in
  `-Status` or `-Anomalie`, value true/false or 0 to 3): these channels are
  written on change only. Silence means "unchanged", and the current value
  from `get_current_knx` says whether that is fine (status true, anomaly 0).
  Siblings written in between have changed, not "lived". No defect as long
  as the value is right.
- **channel_silence on a measuring channel** (temperature, humidity,
  current): the sender itself or its bridge is the suspect. Check
  neighbouring channels of the same device and the same room: if all are
  silent it is the device or the bus, if only one is silent it is the
  channel.
- **appliance_runtime, appliance_standby, freezer_icing**: the appliance's
  current channel via `query_timeseries`, plus room temperature and presence
  (`query_unifi_events`).
- **fbh_cold, heat_recovery_decay, gas boiler faults**: `query_heating_cycles`
  and `query_room_climate` for the room, outdoor temperature via the weather.
- **pv_underperformance**: `query_energy_flow` and `get_pv_forecast` for the
  day; clouds are not a cause, deviation from the forecast is.

## Limits

- At most ten tool calls per explanation.
- Never query raw `knx` data over more than one day; hourly aggregates are
  enough, the database is small.
- Set no verdicts; the owner does that.
