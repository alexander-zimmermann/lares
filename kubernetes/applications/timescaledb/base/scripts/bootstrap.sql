-- Runs once via spec.bootstrap.initdb.postInitApplicationSQLRefs at cluster init.
-- Schema evolution after this point requires a migration Job (or manual psql) AND
-- mirroring the change back into this file so a fresh cluster lands at the
-- same schema.

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- =========================================================
-- KNX (xknx-bridge → knx.<main>.<middle>.<sub>)
-- Own bridge, schema is under our control.
-- =========================================================
CREATE TABLE knx (
    time        TIMESTAMPTZ      NOT NULL,
    ga          TEXT             NOT NULL,
    knx_main    SMALLINT         NOT NULL,
    knx_middle  SMALLINT         NOT NULL,
    knx_sub     SMALLINT         NOT NULL,
    knx_name    TEXT             NOT NULL,
    dpt         TEXT             NOT NULL,
    value       DOUBLE PRECISION NOT NULL,
    PRIMARY KEY (time, ga)
);
SELECT create_hypertable('knx', 'time', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX ON knx (knx_name, time DESC);
CREATE INDEX ON knx (knx_main, knx_middle, knx_sub, time DESC);

CREATE MATERIALIZED VIEW knx_1h
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 hour', time) AS bucket, ga, knx_name,
       first(value, time) AS first_value, last(value, time) AS last_value,
       avg(value) AS avg_value, min(value) AS min_value, max(value) AS max_value,
       count(*) AS sample_count
FROM knx GROUP BY bucket, ga, knx_name WITH NO DATA;

-- =========================================================
-- SolarEdge Inverter (solaredge-{1,2}.modbus.inverter)
-- Hot-path columns from energy-inverter dashboard.
-- =========================================================
CREATE TABLE solaredge_inverter (
    time               TIMESTAMPTZ      NOT NULL,
    inverter_id        SMALLINT         NOT NULL,
    ac_power_actual    DOUBLE PRECISION,
    ac_current_actual  DOUBLE PRECISION,
    ac_voltage_l1      DOUBLE PRECISION,
    ac_frequency       DOUBLE PRECISION,
    dc_power           DOUBLE PRECISION,
    dc_current         DOUBLE PRECISION,
    dc_voltage         DOUBLE PRECISION,
    energytotal        DOUBLE PRECISION,
    temperature        DOUBLE PRECISION,
    status             SMALLINT,
    ac_current_l1      DOUBLE PRECISION,
    ac_current_l2      DOUBLE PRECISION,
    ac_current_l3      DOUBLE PRECISION,
    ac_voltage_l2      DOUBLE PRECISION,
    ac_voltage_l3      DOUBLE PRECISION,
    ac_power_apparent  DOUBLE PRECISION,
    ac_power_factor    DOUBLE PRECISION,
    ac_power_reactive  DOUBLE PRECISION,
    PRIMARY KEY (time, inverter_id)
);
SELECT create_hypertable('solaredge_inverter', 'time', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX ON solaredge_inverter (inverter_id, time DESC);

CREATE MATERIALIZED VIEW solaredge_inverter_1h
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 hour', time) AS bucket, inverter_id,
       avg(ac_power_actual) AS ac_power_avg,
       max(ac_power_actual) AS ac_power_max,
       last(energytotal, time) AS energytotal_last,
       avg(temperature) AS temperature_avg,
       max(temperature) AS temperature_max,
       count(*) AS sample_count
FROM solaredge_inverter GROUP BY bucket, inverter_id WITH NO DATA;

-- =========================================================
-- SolarEdge Powerflow (solaredge-{1,2}.powerflow)
-- =========================================================
CREATE TABLE solaredge_powerflow (
    time                             TIMESTAMPTZ      NOT NULL,
    inverter_id                      SMALLINT         NOT NULL,
    pv_production                    DOUBLE PRECISION,
    grid_power                       DOUBLE PRECISION,
    grid_consumption                 DOUBLE PRECISION,
    grid_delivery                    DOUBLE PRECISION,
    battery_charge                   DOUBLE PRECISION,
    battery_discharge                DOUBLE PRECISION,
    consumer_total                   DOUBLE PRECISION,
    consumer_house                   DOUBLE PRECISION,
    consumer_evcharger               DOUBLE PRECISION,
    inverter_power                   DOUBLE PRECISION,
    inverter_dc_power                DOUBLE PRECISION,
    battery_power                    DOUBLE PRECISION,
    consumer_inverter                DOUBLE PRECISION,
    consumer_used_battery_production DOUBLE PRECISION,
    consumer_used_pv_production      DOUBLE PRECISION,
    consumer_used_production         DOUBLE PRECISION,
    inverter_battery_production      DOUBLE PRECISION,
    inverter_pv_production           DOUBLE PRECISION,
    inverter_consumption             DOUBLE PRECISION,
    inverter_production              DOUBLE PRECISION,
    PRIMARY KEY (time, inverter_id)
);
SELECT create_hypertable('solaredge_powerflow', 'time', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX ON solaredge_powerflow (inverter_id, time DESC);

-- No battery installed → battery_charge/discharge are always 0; the original
-- battery_net_avg column was dropped from the live CAGG. consumer_total_max/sum
-- were added directly on the live cluster for peak-load / daily-cumulative
-- dashboards; mirroring here so a fresh initdb lands at the same schema.
CREATE MATERIALIZED VIEW solaredge_powerflow_1h
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 hour', time) AS bucket, inverter_id,
       avg(pv_production) AS pv_production_avg,
       max(pv_production) AS pv_production_max,
       avg(grid_power) AS grid_power_avg,
       avg(grid_consumption) AS grid_consumption_avg,
       avg(grid_delivery) AS grid_delivery_avg,
       avg(consumer_total) AS consumer_total_avg,
       max(consumer_total) AS consumer_total_max,
       sum(consumer_total) AS consumer_total_sum,
       count(*) AS sample_count
FROM solaredge_powerflow GROUP BY bucket, inverter_id WITH NO DATA;

-- =========================================================
-- EMS-ESP (6 topics: boiler_data, boiler_data_dhw, thermostat_data,
-- thermostat_data_hc1, thermostat_data_dhw, mixer_data_hc1)
-- Typed columns = 17 fields used in hvac-heating-unit dashboard.
-- Per row only one topic is populated → most columns are NULL (cheap in column store).
-- =========================================================
CREATE TABLE ems_esp (
    time              TIMESTAMPTZ      NOT NULL,
    topic             TEXT             NOT NULL,
    -- Temperatures / pressures / flows
    curflowtemp       DOUBLE PRECISION,
    rettemp           DOUBLE PRECISION,
    outdoortemp       DOUBLE PRECISION,
    switchtemp        DOUBLE PRECISION,
    syspress          DOUBLE PRECISION,
    curtemp           DOUBLE PRECISION,
    curflow           DOUBLE PRECISION,
    setflowtemp       DOUBLE PRECISION,
    flowsettemp       DOUBLE PRECISION,
    flowtemphc        DOUBLE PRECISION,
    settemp           DOUBLE PRECISION,
    -- Burner power
    curburnpow        DOUBLE PRECISION,
    -- 0/1 flags as SMALLINT (cheap, simpler than BOOL for CAGG arithmetic)
    charging          SMALLINT,
    heatingactive     SMALLINT,
    heatingpump       SMALLINT,
    valvestatus       SMALLINT,
    pumpstatus        SMALLINT,
    -- Setpoints / modes
    seltemp           DOUBLE PRECISION,
    comforttemp       DOUBLE PRECISION,
    ecotemp           DOUBLE PRECISION,
    manualtemp        DOUBLE PRECISION,
    reducetemp        DOUBLE PRECISION,
    noreducetemp      DOUBLE PRECISION,
    tempautotemp      DOUBLE PRECISION,
    targetflowtemp    DOUBLE PRECISION,
    selflowtemp       DOUBLE PRECISION,
    selburnpow        DOUBLE PRECISION,
    flowtempoffset    DOUBLE PRECISION,
    -- Energy / counters
    nompower          DOUBLE PRECISION,
    nrg               DOUBLE PRECISION,
    nrgheat           DOUBLE PRECISION,
    nrgtotal          DOUBLE PRECISION,
    ubauptime         DOUBLE PRECISION,
    -- Burner / heating
    burngas           SMALLINT,
    burngas2          SMALLINT,
    ignwork           DOUBLE PRECISION,
    fanwork           DOUBLE PRECISION,
    oilpreheat        SMALLINT,
    threewayvalve     SMALLINT,
    circ              SMALLINT,
    -- DHW / sanitary
    disinfecting      SMALLINT,
    activated         SMALLINT,
    tapwateractive    SMALLINT,
    storagetemp1      DOUBLE PRECISION,
    -- Service
    servicecodenumber DOUBLE PRECISION
);
SELECT create_hypertable('ems_esp', 'time', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX ON ems_esp (topic, time DESC);

CREATE MATERIALIZED VIEW ems_esp_boiler_1h
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 hour', time) AS bucket,
       avg(curflowtemp) AS curflowtemp_avg, max(curflowtemp) AS curflowtemp_max,
       avg(rettemp)     AS rettemp_avg,
       avg(outdoortemp) AS outdoortemp_avg,
       avg(syspress)    AS syspress_avg,
       avg(curburnpow)  AS curburnpow_avg,
       sum(heatingactive) AS heatingactive_samples,
       count(*)         AS sample_count
FROM ems_esp WHERE topic = 'boiler_data'
GROUP BY bucket WITH NO DATA;

CREATE MATERIALIZED VIEW ems_esp_dhw_1h
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 hour', time) AS bucket,
       avg(curtemp)  AS curtemp_avg,
       avg(curflow)  AS curflow_avg,
       avg(settemp)  AS settemp_avg,
       sum(charging) AS charging_samples,
       count(*)      AS sample_count
FROM ems_esp WHERE topic = 'boiler_data_dhw'
GROUP BY bucket WITH NO DATA;

-- =========================================================
-- WARP — split along the WARP-API topic hierarchy.
-- =========================================================

-- warp.rtc.time, warp.esp32.temperature, warp.ntp.state
CREATE TABLE warp_system (
    time       TIMESTAMPTZ NOT NULL,
    sub_topic  TEXT        NOT NULL
);
SELECT create_hypertable('warp_system', 'time', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX ON warp_system (sub_topic, time DESC);

-- warp.evse.state, warp.evse.low_level_state
-- Typed: 4 state/error fields used in energy-wallbox dashboard.
CREATE TABLE warp_evse (
    time                     TIMESTAMPTZ NOT NULL,
    sub_topic                TEXT        NOT NULL,
    charger_state            SMALLINT,
    error_state              SMALLINT,
    contactor_error          SMALLINT,
    dc_fault_current_state   SMALLINT,
    allowed_charging_current DOUBLE PRECISION,
    iec61851_state           SMALLINT,
    lock_state               SMALLINT,
    contactor_state          SMALLINT
);
SELECT create_hypertable('warp_evse', 'time', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX ON warp_evse (sub_topic, time DESC);

-- warp.charge_manager.{state, low_level_state, config, available_current, ...}
CREATE TABLE warp_charge_manager (
    time       TIMESTAMPTZ NOT NULL,
    sub_topic  TEXT        NOT NULL
);
SELECT create_hypertable('warp_charge_manager', 'time', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX ON warp_charge_manager (sub_topic, time DESC);

-- warp.charge_tracker.{state, current_charge, last_charges}
-- Typed: 4 fields from energy-wallbox dashboard.
CREATE TABLE warp_charge_tracker (
    time                   TIMESTAMPTZ      NOT NULL,
    sub_topic              TEXT             NOT NULL,
    user_id                TEXT,
    charge_duration        DOUBLE PRECISION,   -- minutes
    energy_charged         DOUBLE PRECISION,   -- kWh
    tracked_charges        INTEGER,
    authorization_type     DOUBLE PRECISION,
    meter_start            DOUBLE PRECISION,
    timestamp_minutes      DOUBLE PRECISION,
    evse_uptime_start      DOUBLE PRECISION,
    first_charge_timestamp DOUBLE PRECISION,
    generator_state        SMALLINT
);
SELECT create_hypertable('warp_charge_tracker', 'time', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX ON warp_charge_tracker (sub_topic, time DESC);
CREATE INDEX ON warp_charge_tracker (user_id, time DESC) WHERE user_id IS NOT NULL;
-- WARP republishes warp.charge_tracker.last_charges periodically with the same
-- historical charges. After the array-unarchive in redpanda-connect, the stream
-- uses to_timestamp(timestamp_minutes * 60) as the row's `time`, so
-- (time, timestamp_minutes) uniquely identifies a completed charge — the
-- partial unique index lets INSERT ... ON CONFLICT DO NOTHING drop repeats.
CREATE UNIQUE INDEX IF NOT EXISTS warp_charge_tracker_last_charges_unique
    ON warp_charge_tracker (time, timestamp_minutes)
    WHERE sub_topic = 'charge_tracker.last_charges';

-- warp.meter.all_values (86 floats), warp.meters.<N>.values (39 floats), warp.meters.<N>.update
-- Typed: phase V/A/W (positions 0-8 confirmed via Telegraf XPath).
CREATE TABLE warp_meter (
    time        TIMESTAMPTZ      NOT NULL,
    sub_topic   TEXT             NOT NULL,
    meter_id    SMALLINT,                        -- 0, 1, ... from `warp.meters.<N>.values`; NULL for `warp.meter.all_values`
    voltage_l1  DOUBLE PRECISION,
    voltage_l2  DOUBLE PRECISION,
    voltage_l3  DOUBLE PRECISION,
    current_l1  DOUBLE PRECISION,
    current_l2  DOUBLE PRECISION,
    current_l3  DOUBLE PRECISION,
    power_l1    DOUBLE PRECISION,
    power_l2    DOUBLE PRECISION,
    power_l3    DOUBLE PRECISION
);
SELECT create_hypertable('warp_meter', 'time', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX ON warp_meter (sub_topic, time DESC);
CREATE INDEX ON warp_meter (meter_id, time DESC) WHERE meter_id IS NOT NULL;

CREATE MATERIALIZED VIEW warp_meter_1h
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 hour', time) AS bucket, meter_id,
       avg(power_l1 + power_l2 + power_l3) AS power_total_avg,
       max(power_l1 + power_l2 + power_l3) AS power_total_max,
       avg(voltage_l1) AS voltage_l1_avg,
       avg(voltage_l2) AS voltage_l2_avg,
       avg(voltage_l3) AS voltage_l3_avg,
       avg(current_l1) AS current_l1_avg,
       avg(current_l2) AS current_l2_avg,
       avg(current_l3) AS current_l3_avg,
       count(*) AS sample_count
FROM warp_meter WHERE meter_id IS NOT NULL
GROUP BY bucket, meter_id WITH NO DATA;

-- =========================================================
-- UniFi Protect Alarm Manager events
-- (node-RED HTTP webhook /unifi-protect enriches each trigger in
--  payload.alarm.triggers[] with alarm-level context, splits, and
--  publishes one NATS message per trigger to
--  unifi.events.<camera>.<detection_type>, where <camera> is the
--  human-readable name resolved from the device MAC.)
-- Typed columns for fields used in queries; everything else lives in raw.
-- Only own property recorded → no retention policy.
-- =========================================================
CREATE TABLE IF NOT EXISTS unifi_events (
    time            TIMESTAMPTZ NOT NULL,
    camera          TEXT        NOT NULL,    -- resolved name (fassade, eingang, terrasse_wohnzimmer, terrasse_esszimmer)
    detection_type  TEXT        NOT NULL,    -- trigger.key: person, motion, line_crossed, face_known, vehicle, license_plate_*, audio_alarm_*, admin_geolocation
    score           SMALLINT,                -- sourceEvent.score 0..100 (0 for plain motion)
    event_type      TEXT,                    -- sourceEvent.type: motion, smartDetectZone, smartDetectLine, ...
    value           TEXT,                    -- face name / license plate / geofence phrase; NULL for plain person/motion
    event_id        TEXT,                    -- trigger.eventId (UUID, also sourceEvent.id)
    event_link      TEXT,                    -- alarm.eventLocalLink (enriched onto trigger in node-RED before split)
    raw             JSONB
);
SELECT create_hypertable('unifi_events', 'time', chunk_time_interval => INTERVAL '7 days');
CREATE INDEX ON unifi_events (camera, time DESC);
CREATE INDEX ON unifi_events (detection_type, time DESC);
CREATE INDEX ON unifi_events (event_id, time DESC) WHERE event_id IS NOT NULL;

-- =========================================================
-- Continuous Aggregate Refresh Policies
-- =========================================================
SELECT add_continuous_aggregate_policy('knx_1h',
    start_offset => INTERVAL '2 days', end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');
SELECT add_continuous_aggregate_policy('solaredge_inverter_1h',
    start_offset => INTERVAL '2 days', end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');
SELECT add_continuous_aggregate_policy('solaredge_powerflow_1h',
    start_offset => INTERVAL '2 days', end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');
SELECT add_continuous_aggregate_policy('ems_esp_boiler_1h',
    start_offset => INTERVAL '2 days', end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');
SELECT add_continuous_aggregate_policy('ems_esp_dhw_1h',
    start_offset => INTERVAL '2 days', end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');
SELECT add_continuous_aggregate_policy('warp_meter_1h',
    start_offset => INTERVAL '2 days', end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

-- =========================================================
-- Native compression — segment_by chosen for the column the queries
-- usually filter on; order_by time DESC matches "most recent first".
-- compress_after = 2 days aligns with the CAGG refresh window
-- (start_offset => 2 days) so the materialization always reads from
-- heap, while still leaving today + yesterday in the live-write window
-- for cheap point lookups and late-arriving rows.
-- =========================================================
ALTER TABLE knx SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'ga',
    timescaledb.compress_orderby = 'time DESC');
ALTER TABLE solaredge_inverter SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'inverter_id',
    timescaledb.compress_orderby = 'time DESC');
ALTER TABLE solaredge_powerflow SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'inverter_id',
    timescaledb.compress_orderby = 'time DESC');
ALTER TABLE ems_esp SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'topic',
    timescaledb.compress_orderby = 'time DESC');
ALTER TABLE warp_system SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'sub_topic',
    timescaledb.compress_orderby = 'time DESC');
ALTER TABLE warp_evse SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'sub_topic',
    timescaledb.compress_orderby = 'time DESC');
ALTER TABLE warp_charge_manager SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'sub_topic',
    timescaledb.compress_orderby = 'time DESC');
ALTER TABLE warp_charge_tracker SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'sub_topic',
    timescaledb.compress_orderby = 'time DESC');
ALTER TABLE warp_meter SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'meter_id',
    timescaledb.compress_orderby = 'time DESC');
ALTER TABLE unifi_events SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'camera',
    timescaledb.compress_orderby = 'time DESC');

SELECT add_compression_policy('knx',                 INTERVAL '2 days');
SELECT add_compression_policy('solaredge_inverter',  INTERVAL '2 days');
SELECT add_compression_policy('solaredge_powerflow', INTERVAL '2 days');
SELECT add_compression_policy('ems_esp',             INTERVAL '2 days');
SELECT add_compression_policy('warp_system',         INTERVAL '2 days');
SELECT add_compression_policy('warp_evse',           INTERVAL '2 days');
SELECT add_compression_policy('warp_charge_manager', INTERVAL '2 days');
SELECT add_compression_policy('warp_charge_tracker', INTERVAL '2 days');
SELECT add_compression_policy('warp_meter',          INTERVAL '2 days');
SELECT add_compression_policy('unifi_events',        INTERVAL '7 days');

-- =========================================================
-- Retention policies — 365d on every hot hypertable. Raw chunks past
-- this age are dropped; CAGGs continue to serve aggregated history
-- because of materialized_only = true (set inline above).
-- =========================================================
SELECT add_retention_policy('knx',                 INTERVAL '365 days');
SELECT add_retention_policy('solaredge_inverter',  INTERVAL '365 days');
SELECT add_retention_policy('solaredge_powerflow', INTERVAL '365 days');
SELECT add_retention_policy('ems_esp',             INTERVAL '365 days');
SELECT add_retention_policy('warp_system',         INTERVAL '365 days');
SELECT add_retention_policy('warp_evse',           INTERVAL '365 days');
SELECT add_retention_policy('warp_charge_manager', INTERVAL '365 days');
SELECT add_retention_policy('warp_charge_tracker', INTERVAL '365 days');
SELECT add_retention_policy('warp_meter',          INTERVAL '365 days');

-- =========================================================
-- GA catalog — GA → name/room/function/description lookup,
-- populated by the iot-mcp-bridge import-ga-catalog Job from
-- the knx-nats-bridge ConfigMap. The `ga_catalog_view` view
-- joins `knx` against the catalog so MCP tools can filter / group by
-- room or function in plain SQL.
-- =========================================================
CREATE TABLE IF NOT EXISTS ga_catalog (
    ga          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    room        TEXT,
    function    TEXT,
    description TEXT,
    dpt         TEXT NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ga_catalog_room_idx     ON ga_catalog (room) WHERE room IS NOT NULL;
CREATE INDEX IF NOT EXISTS ga_catalog_function_idx ON ga_catalog (function);

CREATE OR REPLACE VIEW ga_catalog_view AS
SELECT k.time, k.ga, k.knx_main, k.knx_middle, k.knx_sub, k.dpt, k.value,
       n.name AS ga_name, n.room, n.function, n.description
FROM knx k LEFT JOIN ga_catalog n USING (ga);

-- =========================================================
-- TimescaleDB Toolkit — adds stats_agg / percentile_agg / rollup
-- for Phase-2 anomaly-baseline aggregates.
-- =========================================================
CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit;

-- =========================================================
-- Baseline CAGGs (Phase 2 anomaly detection)
-- One row per (day, hour_of_day, weekday) tuple, holding stats_agg
-- and percentile_agg sketches. Detectors `rollup(...)` across the
-- last N days at query time to derive the typical hour×weekday profile.
-- Hierarchical CAGGs (built on top of the *_1h CAGGs) — both layers
-- run with materialized_only = true.
-- =========================================================
CREATE MATERIALIZED VIEW ems_esp_boiler_baseline_30d
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 day', bucket) AS day,
       EXTRACT(hour   FROM bucket)::smallint AS hour_of_day,
       EXTRACT(isodow FROM bucket)::smallint AS weekday,
       stats_agg(curflowtemp_avg)                          AS curflowtemp_stats,
       percentile_agg(curflowtemp_avg)                     AS curflowtemp_pct,
       stats_agg(rettemp_avg)                              AS rettemp_stats,
       percentile_agg(rettemp_avg)                         AS rettemp_pct,
       stats_agg(outdoortemp_avg)                          AS outdoortemp_stats,
       percentile_agg(outdoortemp_avg)                     AS outdoortemp_pct,
       stats_agg(curburnpow_avg)                           AS curburnpow_stats,
       percentile_agg(curburnpow_avg)                      AS curburnpow_pct,
       stats_agg(heatingactive_samples::DOUBLE PRECISION)  AS heatingactive_stats,
       percentile_agg(heatingactive_samples::DOUBLE PRECISION) AS heatingactive_pct
FROM ems_esp_boiler_1h
GROUP BY day, hour_of_day, weekday WITH NO DATA;

CREATE MATERIALIZED VIEW ems_esp_dhw_baseline_30d
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 day', bucket) AS day,
       EXTRACT(hour   FROM bucket)::smallint AS hour_of_day,
       EXTRACT(isodow FROM bucket)::smallint AS weekday,
       stats_agg(curtemp_avg) AS curtemp_stats,
       percentile_agg(curtemp_avg) AS curtemp_pct,
       stats_agg(curflow_avg) AS curflow_stats,
       percentile_agg(curflow_avg) AS curflow_pct,
       stats_agg(settemp_avg) AS settemp_stats,
       percentile_agg(settemp_avg) AS settemp_pct
FROM ems_esp_dhw_1h
GROUP BY day, hour_of_day, weekday WITH NO DATA;

CREATE MATERIALIZED VIEW solaredge_inverter_baseline_30d
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 day', bucket) AS day,
       inverter_id,
       EXTRACT(hour   FROM bucket)::smallint AS hour_of_day,
       EXTRACT(isodow FROM bucket)::smallint AS weekday,
       stats_agg(ac_power_avg)    AS ac_power_stats,
       percentile_agg(ac_power_avg) AS ac_power_pct,
       stats_agg(temperature_avg) AS temperature_stats,
       percentile_agg(temperature_avg) AS temperature_pct
FROM solaredge_inverter_1h
GROUP BY day, inverter_id, hour_of_day, weekday WITH NO DATA;

CREATE MATERIALIZED VIEW solaredge_powerflow_baseline_30d
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 day', bucket) AS day,
       inverter_id,
       EXTRACT(hour   FROM bucket)::smallint AS hour_of_day,
       EXTRACT(isodow FROM bucket)::smallint AS weekday,
       stats_agg(pv_production_avg)  AS pv_production_stats,
       percentile_agg(pv_production_avg) AS pv_production_pct,
       stats_agg(consumer_total_avg) AS consumer_total_stats,
       percentile_agg(consumer_total_avg) AS consumer_total_pct,
       stats_agg(grid_power_avg)     AS grid_power_stats,
       percentile_agg(grid_power_avg) AS grid_power_pct,
       stats_agg(battery_net_avg)    AS battery_net_stats,
       percentile_agg(battery_net_avg) AS battery_net_pct
FROM solaredge_powerflow_1h
GROUP BY day, inverter_id, hour_of_day, weekday WITH NO DATA;

-- knx_1h has one row per (bucket, ga) → baseline is per (day, ga, hour, weekday).
-- Many GAs are binary; detectors filter via ga_catalog (function/room) at query time.
CREATE MATERIALIZED VIEW knx_baseline_30d
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 day', bucket) AS day,
       ga,
       knx_name,
       EXTRACT(hour   FROM bucket)::smallint AS hour_of_day,
       EXTRACT(isodow FROM bucket)::smallint AS weekday,
       stats_agg(avg_value) AS value_stats,
       percentile_agg(avg_value) AS value_pct
FROM knx_1h
GROUP BY day, ga, knx_name, hour_of_day, weekday WITH NO DATA;

CREATE MATERIALIZED VIEW warp_meter_baseline_30d
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 day', bucket) AS day,
       meter_id,
       EXTRACT(hour   FROM bucket)::smallint AS hour_of_day,
       EXTRACT(isodow FROM bucket)::smallint AS weekday,
       stats_agg(power_total_avg) AS power_total_stats,
       percentile_agg(power_total_avg) AS power_total_pct,
       stats_agg(voltage_l1_avg)  AS voltage_l1_stats,
       stats_agg(voltage_l2_avg)  AS voltage_l2_stats,
       stats_agg(voltage_l3_avg)  AS voltage_l3_stats,
       stats_agg(current_l1_avg)  AS current_l1_stats,
       stats_agg(current_l2_avg)  AS current_l2_stats,
       stats_agg(current_l3_avg)  AS current_l3_stats
FROM warp_meter_1h
GROUP BY day, meter_id, hour_of_day, weekday WITH NO DATA;

SELECT add_continuous_aggregate_policy('ems_esp_boiler_baseline_30d',
    start_offset => INTERVAL '60 days', end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '6 hours');
SELECT add_continuous_aggregate_policy('ems_esp_dhw_baseline_30d',
    start_offset => INTERVAL '60 days', end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '6 hours');
SELECT add_continuous_aggregate_policy('solaredge_inverter_baseline_30d',
    start_offset => INTERVAL '60 days', end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '6 hours');
SELECT add_continuous_aggregate_policy('solaredge_powerflow_baseline_30d',
    start_offset => INTERVAL '60 days', end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '6 hours');
SELECT add_continuous_aggregate_policy('knx_baseline_30d',
    start_offset => INTERVAL '60 days', end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '6 hours');
SELECT add_continuous_aggregate_policy('warp_meter_baseline_30d',
    start_offset => INTERVAL '60 days', end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '6 hours');

-- =========================================================
-- mcp_anomalies — every detected anomaly (zscore, iforest, mstl, forecast_solar)
-- Written by iot_mcp_bridge_rw, read by iot_mcp_bridge_ro / grafana_ro.
-- =========================================================
CREATE TABLE IF NOT EXISTS mcp_anomalies (
    time        TIMESTAMPTZ      NOT NULL,
    created_at  TIMESTAMPTZ      NOT NULL DEFAULT now(),
    source      TEXT             NOT NULL,
    metric      TEXT             NOT NULL,
    detector    TEXT             NOT NULL,
    severity    TEXT             NOT NULL CHECK (severity IN ('info','warning','critical')),
    uc          TEXT,
    actual      DOUBLE PRECISION,
    expected    DOUBLE PRECISION,
    score       DOUBLE PRECISION,
    payload     JSONB,
    PRIMARY KEY (time, source, metric, detector)
);
SELECT create_hypertable('mcp_anomalies', 'time', chunk_time_interval => INTERVAL '7 days');
CREATE INDEX ON mcp_anomalies (severity, time DESC);
CREATE INDEX ON mcp_anomalies (source, metric, time DESC);
CREATE INDEX ON mcp_anomalies (uc, time DESC) WHERE uc IS NOT NULL;
SELECT add_retention_policy('mcp_anomalies', INTERVAL '90 days');

-- =========================================================
-- mcp_forecasts — model predictions (statsforecast + Forecast.Solar)
-- =========================================================
CREATE TABLE IF NOT EXISTS mcp_forecasts (
    forecast_for    TIMESTAMPTZ      NOT NULL,
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT now(),
    source          TEXT             NOT NULL,
    metric          TEXT             NOT NULL,
    model           TEXT             NOT NULL,
    forecast_value  DOUBLE PRECISION,
    forecast_lower  DOUBLE PRECISION,
    forecast_upper  DOUBLE PRECISION,
    PRIMARY KEY (forecast_for, source, metric, model)
);
SELECT create_hypertable('mcp_forecasts', 'forecast_for', chunk_time_interval => INTERVAL '7 days');
CREATE INDEX ON mcp_forecasts (model, forecast_for DESC);
SELECT add_retention_policy('mcp_forecasts', INTERVAL '90 days');

-- =========================================================
-- Transfer ownership from `postgres` (CNPG runs initdb as superuser)
-- to the application user `homelab`, so it can issue table-level GRANTs.
-- =========================================================
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('ALTER TABLE public.%I OWNER TO homelab', r.tablename);
    END LOOP;
    FOR r IN SELECT view_name FROM timescaledb_information.continuous_aggregates LOOP
        EXECUTE format('ALTER MATERIALIZED VIEW public.%I OWNER TO homelab', r.view_name);
    END LOOP;
    -- Plain views only — pg_views also lists continuous aggregates, but
    -- ALTER VIEW errors on CAGGs (hint: "Use ALTER MATERIALIZED VIEW"), and
    -- the unhandled error rolls back the entire DO block.
    FOR r IN
        SELECT viewname FROM pg_views WHERE schemaname = 'public'
        AND viewname NOT IN (
            SELECT view_name FROM timescaledb_information.continuous_aggregates
        )
    LOOP
        EXECUTE format('ALTER VIEW public.%I OWNER TO homelab', r.viewname);
    END LOOP;
END$$;
