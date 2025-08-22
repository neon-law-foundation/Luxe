-- Enable pg_stat_statements extension for query performance monitoring
-- This extension tracks execution statistics of all SQL statements executed by a server
-- Provides query-level statistics including execution time, calls, and resource usage
-- NOTE: pg_stat_statements must be loaded via shared_preload_libraries in postgresql.conf

-- Enable the pg_stat_statements extension
DO $$ BEGIN
    -- Check if the extension is already installed
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'
    ) THEN
        CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
        COMMENT ON EXTENSION pg_stat_statements IS 'Track execution statistics of SQL statements';
    END IF;
END $$;

-- Optionally reset pg_stat_statements to start with clean data (only if extension is loaded)
DO $$ BEGIN
    -- Check if the function exists and is available (extension properly loaded)
    IF EXISTS (
        SELECT 1 FROM pg_proc WHERE proname = 'pg_stat_statements_reset'
    ) AND EXISTS (
        SELECT 1 FROM pg_stat_statements LIMIT 1
    ) THEN
        PERFORM pg_stat_statements_reset();
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- If pg_stat_statements is not properly loaded via shared_preload_libraries,
        -- the extension will exist but functions won't work. This is expected in development.
        NULL;
END $$;
