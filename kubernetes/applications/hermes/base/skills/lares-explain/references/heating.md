# Tracing a heating pause

For a heating fault whose question is why the burner or the mixed circuit
delivered no heat: `fbh_cold` once the room did its part, `heat_recovery_decay`
and the gas boiler faults. These queries are the Surroundings step; the cap of
ten tool calls still holds.

1. **Burner.** `query_heating_cycles` over the episode window says when the
   burner ran and when it stopped, with its peak and average modulation in
   percent.
2. **Mixed circuit.** One `query_timeseries` on `ems_esp` with
   `filters: {"topic": "mixer_data_hc1"}`, `columns: ["flowsettemp",
   "flowtemphc"]` (set and measured mixed flow), `bucket: "15 minutes"`. The
   flow the thermostat asks for is `targetflowtemp` under
   `filters: {"topic": "thermostat_data_hc1"}`. Each `ems_esp` row holds one
   topic: a column that comes back empty was asked under the wrong topic.
3. **Hot water.** `query_timeseries` on `ems_esp_dhw_1h` with
   `columns: ["charging_samples"]`: a charge running during the pause is a
   competing demand, and the boiler serves it first.
4. **Exact moment.** For a stop or a restart, `query_knx_events` narrowed to the
   datapoint and an hour around it. Its rows come newest first and stop at
   `limit` with `truncated: true`; narrow a truncated result until it is not,
   its oldest row is no start. The tools answer in UTC; report local time.

Reading it:

- A mixed-flow target that rises the moment the burner restarts is an observed
  change; call it a scheduled setback only when a mode or schedule signal shows
  one.
- A target above zero while the measured mixed flow cools means the target does
  not explain why the burner stayed off; that is the open point.
- A service code of 0 shows no reported fault, not the absence of a control
  lockout.
- A valve at 100 % shows what the room asked for, not that the boiler fired.
