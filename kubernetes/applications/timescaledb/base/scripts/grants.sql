-- GRANTs for non-owner roles. Idempotent — safe to re-run on every PostSync
-- of the timescaledb app. New roles + grants get appended here as they show up;
-- the role itself must exist (created via spec.managed.roles[] in database.yaml).

DO $$
DECLARE
    ro_role      TEXT;
    ingest_table TEXT;
    cagg         RECORD;
BEGIN
    -- Ingest user — INSERT + SELECT on the tables Redpanda Connect writes,
    -- and on nothing else. SELECT is not optional: every stream inserts with
    -- a named conflict target (`ON CONFLICT (time, ga) DO NOTHING`), and
    -- inferring that target reads the table, so INSERT alone fails with
    -- "permission denied". The revokes run first and in the same transaction
    -- as the grants, so this list is the whole truth: a table taken out
    -- loses the privilege on the next sync, and a table added to the schema
    -- later gets nothing until it is named here.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'connect') THEN
        GRANT CONNECT ON DATABASE homelab TO connect;
        GRANT USAGE ON SCHEMA public TO connect;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public
            REVOKE INSERT, SELECT ON TABLES FROM connect;
        REVOKE ALL ON ALL TABLES IN SCHEMA public FROM connect;

        FOREACH ingest_table IN ARRAY ARRAY[
            'knx', 'ems_esp',
            'solaredge_inverter', 'solaredge_powerflow', 'solaredge_battery',
            'warp_system', 'warp_evse', 'warp_charge_manager',
            'warp_charge_tracker', 'warp_meter',
            'dyson_environment', 'dyson_state',
            'midea_environment', 'midea_state',
            'miele_state', 'miele_eco',
            'unifi_events']
        LOOP
            IF EXISTS (SELECT 1 FROM pg_tables
                        WHERE schemaname = 'public' AND tablename = ingest_table) THEN
                EXECUTE format('GRANT INSERT, SELECT ON public.%I TO connect', ingest_table);
            END IF;
        END LOOP;
    END IF;

    -- Read-only roles. Each gets SELECT on every public table plus SELECT on
    -- the materialisation table of every CAGG. A blanket grant on
    -- _timescaledb_internal would hit TS bookkeeping tables owned by the
    -- postgres superuser, so we enumerate CAGGs explicitly.
    -- lares_diagnostics_engine_rw also gets the same SELECT surface; write privileges
    -- are added below for mcp_forecasts and the episode tables only.
    -- lares_mcp_bridge_verdict is deliberately absent — see the verdict block.
    FOREACH ro_role IN ARRAY ARRAY['lares_mcp_bridge_ro', 'grafana_ro', 'lares_diagnostics_engine_rw']
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

    -- Forecast writer — INSERT + UPDATE on mcp_forecasts.
    -- UPDATE is needed for `INSERT … ON CONFLICT DO UPDATE` idempotency.
    -- Production hypertables (knx, ems_esp, warp_*, solaredge_*) stay read-only.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lares_diagnostics_engine_rw')
       AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'mcp_forecasts') THEN
        GRANT INSERT, UPDATE ON mcp_forecasts TO lares_diagnostics_engine_rw;
    END IF;

    -- Episode writer — lares_diagnostics_engine_rw keeps open episodes current
    -- (last_seen_at, severity, ended_at) and appends evidence and events.
    -- Sequence usage covers the identity column on INSERT.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lares_diagnostics_engine_rw')
       AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'episodes') THEN
        GRANT INSERT, UPDATE ON episodes, episode_observations, episode_events TO lares_diagnostics_engine_rw;
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO lares_diagnostics_engine_rw',
                       pg_get_serial_sequence('public.episodes', 'id'));
    END IF;

    -- Verdict writer — its own role, because it is the one credential an
    -- LLM-facing server holds: it may write exactly one table, and reads
    -- `episodes` only to name the episode it is judging. Deliberately outside
    -- the read-only loop above, so it never gains the blanket SELECT surface.
    -- UPDATE is what the upsert needs so a second verdict overwrites the first;
    -- SELECT on the table covers the RETURNING clause.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lares_mcp_bridge_verdict')
       AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'episode_verdicts') THEN
        GRANT CONNECT ON DATABASE homelab TO lares_mcp_bridge_verdict;
        GRANT USAGE ON SCHEMA public TO lares_mcp_bridge_verdict;
        GRANT SELECT ON episodes TO lares_mcp_bridge_verdict;
        GRANT SELECT, INSERT, UPDATE ON episode_verdicts TO lares_mcp_bridge_verdict;
    END IF;

    -- Ledger writer — the trigger service is the only writer of the ledger
    -- and the memory: it inserts the row before the run starts and updates
    -- it as the run ends. SELECT comes with them, not on top of them:
    -- UPDATE ... WHERE reads the key columns, and the dedupe INSERT reads
    -- back the id it conflicted on. Sequence usage covers the identity
    -- column on INSERT.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lares_agent_trigger')
       AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'agent_runs') THEN
        GRANT CONNECT ON DATABASE homelab TO lares_agent_trigger;
        GRANT USAGE ON SCHEMA public TO lares_agent_trigger;
        GRANT SELECT, INSERT, UPDATE ON agent_runs, agent_memory TO lares_agent_trigger;
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO lares_agent_trigger',
                       pg_get_serial_sequence('public.agent_runs', 'id'));
    END IF;

    -- Verdict on a run — the same role that judges episodes, and the same
    -- shape: SELECT to name the run it is judging, column-level UPDATE so
    -- the judgement can never rewrite the output it judges. CONNECT and
    -- schema usage come from the block above.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lares_mcp_bridge_verdict')
       AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'agent_runs') THEN
        GRANT SELECT ON agent_runs TO lares_mcp_bridge_verdict;
        GRANT UPDATE (verdict, verdict_at) ON agent_runs TO lares_mcp_bridge_verdict;
    END IF;
END$$;
