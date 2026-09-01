-- GRANTs for non-owner roles. Idempotent — safe to re-run on every PostSync
-- of the timescaledb app. New roles + grants get appended here as they show up;
-- the role itself must exist (created via spec.managed.roles[] in database.yaml).

DO $$
DECLARE
    ro_role TEXT;
    cagg    RECORD;
BEGIN
    -- Ingest user — INSERT + SELECT on public schema.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'connect') THEN
        GRANT USAGE ON SCHEMA public TO connect;
        GRANT INSERT, SELECT ON ALL TABLES IN SCHEMA public TO connect;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public
            GRANT INSERT, SELECT ON TABLES TO connect;
    END IF;

    -- Read-only roles. Each gets SELECT on every public table plus SELECT on
    -- the materialisation table of every CAGG. A blanket grant on
    -- _timescaledb_internal would hit TS bookkeeping tables owned by the
    -- postgres superuser, so we enumerate CAGGs explicitly.
    -- iot_mcp_bridge_rw also gets the same SELECT surface; write privileges
    -- are added below for mcp_anomalies / mcp_forecasts only.
    FOREACH ro_role IN ARRAY ARRAY['iot_mcp_bridge_ro', 'grafana_ro', 'iot_mcp_bridge_rw']
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = ro_role) THEN
            CONTINUE;
        END IF;

        EXECUTE format('GRANT CONNECT ON DATABASE homelab TO %I', ro_role);
        EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', ro_role);
        EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA public TO %I', ro_role);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO %I', ro_role);
        EXECUTE format('GRANT USAGE ON SCHEMA _timescaledb_internal TO %I', ro_role);

        FOR cagg IN
            SELECT format('%I.%I',
                          materialization_hypertable_schema,
                          materialization_hypertable_name) AS qname
            FROM timescaledb_information.continuous_aggregates
        LOOP
            EXECUTE format('GRANT SELECT ON %s TO %I', cagg.qname, ro_role);
        END LOOP;
    END LOOP;

    -- Phase-2 writer — INSERT + UPDATE on mcp_anomalies / mcp_forecasts only.
    -- UPDATE is needed for `INSERT … ON CONFLICT DO UPDATE` idempotency.
    -- Production hypertables (knx, ems_esp, warp_*, solaredge_*) stay read-only.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'iot_mcp_bridge_rw')
       AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'mcp_anomalies') THEN
        GRANT INSERT, UPDATE ON mcp_anomalies TO iot_mcp_bridge_rw;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'iot_mcp_bridge_rw')
       AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'mcp_forecasts') THEN
        GRANT INSERT, UPDATE ON mcp_forecasts TO iot_mcp_bridge_rw;
    END IF;

    -- Episode writer — iot_mcp_bridge_rw keeps open episodes current
    -- (last_seen_at, severity, ended_at) and appends evidence and events.
    -- Sequence usage covers the identity column on INSERT.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'iot_mcp_bridge_rw')
       AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'episodes') THEN
        GRANT INSERT, UPDATE ON episodes, episode_observations, episode_events TO iot_mcp_bridge_rw;
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO iot_mcp_bridge_rw',
                       pg_get_serial_sequence('public.episodes', 'id'));
    END IF;
END$$;
