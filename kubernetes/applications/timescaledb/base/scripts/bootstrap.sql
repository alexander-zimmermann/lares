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

CREATE MATERIALIZED VIEW solaredge_powerflow_1h
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 hour', time) AS bucket, inverter_id,
       avg(pv_production) AS pv_production_avg,
       max(pv_production) AS pv_production_max,
       avg(grid_power) AS grid_power_avg,
       avg(grid_consumption) AS grid_consumption_avg,
       avg(grid_delivery) AS grid_delivery_avg,
       avg(consumer_total) AS consumer_total_avg,
       avg(battery_charge - battery_discharge) AS battery_net_avg,
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

SELECT add_compression_policy('knx',                 INTERVAL '2 days');
SELECT add_compression_policy('solaredge_inverter',  INTERVAL '2 days');
SELECT add_compression_policy('solaredge_powerflow', INTERVAL '2 days');
SELECT add_compression_policy('ems_esp',             INTERVAL '2 days');
SELECT add_compression_policy('warp_system',         INTERVAL '2 days');
SELECT add_compression_policy('warp_evse',           INTERVAL '2 days');
SELECT add_compression_policy('warp_charge_manager', INTERVAL '2 days');
SELECT add_compression_policy('warp_charge_tracker', INTERVAL '2 days');
SELECT add_compression_policy('warp_meter',          INTERVAL '2 days');

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
END$$;
