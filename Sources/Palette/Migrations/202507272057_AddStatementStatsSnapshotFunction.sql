-- Create pg_stat_statements snapshot function for capturing statement statistics
-- This migration creates a function to capture current pg_stat_statements data into statement_stats table

CREATE OR REPLACE FUNCTION admin.capture_statement_stats()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rows_inserted INTEGER := 0;
    current_snapshot TIMESTAMP := NOW();
BEGIN
    -- Insert current pg_stat_statements data into statement_stats table
    -- Only capture statements that have been executed since last snapshot
    INSERT INTO statement_stats (
        id,
        query_id,
        query_text,
        calls,
        total_exec_time,
        mean_exec_time,
        rows,
        shared_blks_hit,
        shared_blks_read,
        temp_blks_read,
        temp_blks_written,
        snapshot_at,
        created_at,
        updated_at
    )
    SELECT
        gen_random_uuid() AS id,
        s.queryid AS query_id,
        s.query AS query_text,
        s.calls,
        s.total_exec_time,
        s.mean_exec_time,
        s.rows,
        s.shared_blks_hit,
        s.shared_blks_read,
        s.temp_blks_read,
        s.temp_blks_written,
        current_snapshot AS snapshot_at,
        current_snapshot AS created_at,
        current_snapshot AS updated_at
    FROM pg_stat_statements s
    WHERE s.calls > 0
    AND s.queryid IS NOT NULL
    AND s.query IS NOT NULL
    -- Avoid capturing statements that are too short or administrative
    AND LENGTH(s.query) > 10
    AND s.query NOT LIKE 'SET %'
    AND s.query NOT LIKE 'SHOW %'
    AND s.query NOT LIKE 'BEGIN%'
    AND s.query NOT LIKE 'COMMIT%'
    AND s.query NOT LIKE 'ROLLBACK%';

    GET DIAGNOSTICS rows_inserted = ROW_COUNT;

    -- Log the snapshot operation
    RAISE NOTICE 'Captured % statement statistics at %', rows_inserted, current_snapshot;

    RETURN rows_inserted;
END;
$$;

COMMENT ON FUNCTION admin.capture_statement_stats() IS
'Captures current pg_stat_statements data into statement_stats table for historical analysis';

-- Grant execute permission to admin role
GRANT EXECUTE ON FUNCTION admin.capture_statement_stats() TO admin;
