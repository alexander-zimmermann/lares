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
    FOREACH ro_role IN ARRAY ARRAY['iot_mcp_bridge_ro', 'grafana_ro']
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
END$$;
