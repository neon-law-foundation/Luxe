-- Create hourly aggregation function for statement statistics
-- This migration creates a function to aggregate statement_stats data into hourly summaries

CREATE OR REPLACE FUNCTION admin.aggregate_statement_stats_hourly()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rows_inserted INTEGER := 0;
    current_hour TIMESTAMP;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
BEGIN
    -- Calculate the current hour boundary (truncate to hour)
    current_hour := date_trunc('hour', NOW() - INTERVAL '1 hour');
    start_time := current_hour;
    end_time := current_hour + INTERVAL '1 hour';
    
    -- Delete existing aggregations for this hour to avoid duplicates
    DELETE FROM statement_stats_hourly 
    WHERE hour = current_hour;
    
    -- Insert aggregated hourly data from statement_stats
    INSERT INTO statement_stats_hourly (
        id,
        hour,
        query_id,
        query_text,
        total_calls,
        avg_exec_time,
        total_rows,
        created_at,
        updated_at
    )
    SELECT
        gen_random_uuid() AS id,
        current_hour AS hour,
        query_id,
        query_text,
        SUM(calls) AS total_calls,
        AVG(mean_exec_time) AS avg_exec_time,
        SUM(rows) AS total_rows,
        NOW() AS created_at,
        NOW() AS updated_at
    FROM statement_stats
    WHERE snapshot_at >= start_time
    AND snapshot_at < end_time
    AND query_id IS NOT NULL
    GROUP BY query_id, query_text
    HAVING SUM(calls) > 0;
    
    GET DIAGNOSTICS rows_inserted = ROW_COUNT;
    
    -- Log the aggregation operation
    RAISE NOTICE 'Aggregated % hourly statistics for hour %', rows_inserted, current_hour;
    
    RETURN rows_inserted;
END;
$$;

COMMENT ON FUNCTION admin.aggregate_statement_stats_hourly() IS
'Aggregates statement_stats data into hourly summaries in statement_stats_hourly table';

-- Grant execute permission to admin role
GRANT EXECUTE ON FUNCTION admin.aggregate_statement_stats_hourly() TO admin;
