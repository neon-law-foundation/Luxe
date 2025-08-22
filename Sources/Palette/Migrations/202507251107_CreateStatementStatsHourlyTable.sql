-- Create statement_stats_hourly table for aggregated hourly metrics
-- This table stores hourly aggregations of statement statistics for efficient time-series analysis
-- Data is aggregated from statement_stats table by background jobs

-- Create the statement_stats_hourly table
CREATE TABLE IF NOT EXISTS statement_stats_hourly (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hour TIMESTAMP WITH TIME ZONE NOT NULL,
    query_id BIGINT NOT NULL,
    query_text TEXT NOT NULL,
    total_calls BIGINT NOT NULL DEFAULT 0,
    avg_exec_time DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    total_rows BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Add comments to explain the purpose of each column
COMMENT ON TABLE statement_stats_hourly IS
'Hourly aggregated PostgreSQL query execution statistics for time-series analysis';
COMMENT ON COLUMN statement_stats_hourly.id IS 'Unique identifier for each hourly statistics record';
COMMENT ON COLUMN statement_stats_hourly.hour IS 'Hour timestamp (truncated to hour boundary) for this aggregation';
COMMENT ON COLUMN statement_stats_hourly.query_id IS 'Internal hash code computed from the statement normalized text';
COMMENT ON COLUMN statement_stats_hourly.query_text IS 'Text of the representative statement (normalized)';
COMMENT ON COLUMN statement_stats_hourly.total_calls IS
'Total number of times the statement was executed in this hour';
COMMENT ON COLUMN statement_stats_hourly.avg_exec_time IS
'Average execution time for this statement in this hour (milliseconds)';
COMMENT ON COLUMN statement_stats_hourly.total_rows IS
'Total number of rows retrieved or affected by the statement in this hour';
COMMENT ON COLUMN statement_stats_hourly.created_at IS 'Timestamp when this record was created';
COMMENT ON COLUMN statement_stats_hourly.updated_at IS 'Timestamp when this record was last updated';

-- Add unique constraint on hour and query_id combination
CREATE UNIQUE INDEX IF NOT EXISTS idx_statement_stats_hourly_hour_query_unique
ON statement_stats_hourly (hour, query_id);

-- Add index on hour for time-based queries
CREATE INDEX IF NOT EXISTS idx_statement_stats_hourly_hour
ON statement_stats_hourly (hour DESC);

-- Add index on query_id for query-specific lookups
CREATE INDEX IF NOT EXISTS idx_statement_stats_hourly_query_id
ON statement_stats_hourly (query_id);

-- Add index on avg_exec_time for performance analysis
CREATE INDEX IF NOT EXISTS idx_statement_stats_hourly_avg_exec_time
ON statement_stats_hourly (avg_exec_time DESC);

-- Add updated_at trigger to statement_stats_hourly table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_statement_stats_hourly_updated_at'
    ) THEN
        CREATE TRIGGER update_statement_stats_hourly_updated_at
            BEFORE UPDATE ON statement_stats_hourly
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create row-level security policies for admin role access
ALTER TABLE statement_stats_hourly ENABLE ROW LEVEL SECURITY;

-- Policy: Admin users can access all hourly statement statistics
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'statement_stats_hourly' 
        AND policyname = 'admin_all_statement_stats_hourly'
    ) THEN
        CREATE POLICY admin_all_statement_stats_hourly ON statement_stats_hourly
            FOR ALL TO admin USING (true);
    END IF;
END $$;

-- Grant permissions to admin role
DO $$ BEGIN
    -- Grant table permissions to admin role
    GRANT SELECT, INSERT, UPDATE, DELETE ON statement_stats_hourly TO admin;
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO admin;
EXCEPTION
    WHEN undefined_object THEN
        -- Roles might not exist in test environment
        NULL;
END $$;
