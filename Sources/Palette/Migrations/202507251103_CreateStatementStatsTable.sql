-- Create statement_stats table to store historical pg_stat_statements data
-- This table captures snapshots of query execution statistics for analysis and monitoring
-- Data is collected from pg_stat_statements extension at regular intervals

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'statement_stats') THEN
        CREATE TABLE statement_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_id BIGINT NOT NULL,
    query_text TEXT NOT NULL,
    calls BIGINT NOT NULL DEFAULT 0,
    total_exec_time DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    mean_exec_time DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    rows BIGINT NOT NULL DEFAULT 0,
    shared_blks_hit BIGINT NOT NULL DEFAULT 0,
    shared_blks_read BIGINT NOT NULL DEFAULT 0,
    temp_blks_read BIGINT NOT NULL DEFAULT 0,
    temp_blks_written BIGINT NOT NULL DEFAULT 0,
    snapshot_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
        );

        -- Add comments to explain the purpose of each column
COMMENT ON TABLE statement_stats IS 'Historical snapshots of pg_stat_statements query execution statistics';
COMMENT ON COLUMN statement_stats.id IS 'Unique identifier for each statement statistics record';
COMMENT ON COLUMN statement_stats.query_id IS 'Internal hash code computed from the statement normalized text';
COMMENT ON COLUMN statement_stats.query_text IS 'Text of the representative statement (normalized)';
COMMENT ON COLUMN statement_stats.calls IS 'Number of times the statement was executed';
COMMENT ON COLUMN statement_stats.total_exec_time IS 'Total time spent executing this statement in milliseconds';
COMMENT ON COLUMN statement_stats.mean_exec_time IS 'Mean time spent executing this statement in milliseconds';
COMMENT ON COLUMN statement_stats.rows IS 'Total number of rows retrieved or affected by the statement';
COMMENT ON COLUMN statement_stats.shared_blks_hit IS 'Total number of shared block cache hits by the statement';
COMMENT ON COLUMN statement_stats.shared_blks_read IS 'Total number of shared blocks read by the statement';
COMMENT ON COLUMN statement_stats.temp_blks_read IS 'Total number of temp blocks read by the statement';
COMMENT ON COLUMN statement_stats.temp_blks_written IS 'Total number of temp blocks written by the statement';
COMMENT ON COLUMN statement_stats.snapshot_at IS 'Timestamp when this statistics snapshot was taken';
COMMENT ON COLUMN statement_stats.created_at IS 'Timestamp when this record was created';
COMMENT ON COLUMN statement_stats.updated_at IS 'Timestamp when this record was last updated';

        -- Add index on query_id and snapshot_at for efficient queries
        CREATE INDEX idx_statement_stats_query_id_snapshot
        ON statement_stats (query_id, snapshot_at DESC);

        -- Add index on snapshot_at for time-based queries
        CREATE INDEX idx_statement_stats_snapshot_at
        ON statement_stats (snapshot_at DESC);

        -- Add index on total_exec_time for finding slow queries
        CREATE INDEX idx_statement_stats_total_exec_time
        ON statement_stats (total_exec_time DESC);
    END IF;
END $$;

-- Create updated_at trigger function if it doesn't exist
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column'
    ) THEN
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS '
        BEGIN
            NEW.updated_at = now();
            RETURN NEW;
        END;
        ' LANGUAGE plpgsql;
    END IF;
END $$;

-- Add updated_at trigger to statement_stats table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_statement_stats_updated_at'
    ) THEN
        CREATE TRIGGER update_statement_stats_updated_at
            BEFORE UPDATE ON statement_stats
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create row-level security policies for admin role access
ALTER TABLE statement_stats ENABLE ROW LEVEL SECURITY;

-- Policy: Admin users can access all statement statistics
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'statement_stats'
        AND policyname = 'admin_all_statement_stats'
    ) THEN
        CREATE POLICY admin_all_statement_stats ON statement_stats
            FOR ALL TO admin USING (true);
    END IF;
END $$;

-- Grant permissions to admin role
DO $$ BEGIN
    -- Grant table permissions to admin role
    GRANT SELECT, INSERT, UPDATE, DELETE ON statement_stats TO admin;
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO admin;
EXCEPTION
    WHEN undefined_object THEN
        -- Roles might not exist in test environment
        NULL;
END $$;
