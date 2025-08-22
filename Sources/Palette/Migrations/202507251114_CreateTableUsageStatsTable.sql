-- Create table_usage_stats table to track table access patterns
-- This table stores aggregated table usage statistics extracted from statement analysis
-- Helps identify which tables are heavily accessed and their operation patterns

-- Create the table_usage_stats table
CREATE TABLE IF NOT EXISTS table_usage_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name TEXT NOT NULL,
    schema_name TEXT NOT NULL DEFAULT 'public',
    select_count BIGINT NOT NULL DEFAULT 0,
    insert_count BIGINT NOT NULL DEFAULT 0,
    update_count BIGINT NOT NULL DEFAULT 0,
    delete_count BIGINT NOT NULL DEFAULT 0,
    snapshot_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Add comments to explain the purpose of each column
COMMENT ON TABLE table_usage_stats IS 'Table usage statistics tracking access patterns for database optimization';
COMMENT ON COLUMN table_usage_stats.id IS 'Unique identifier for each table usage statistics record';
COMMENT ON COLUMN table_usage_stats.table_name IS 'Name of the database table being tracked';
COMMENT ON COLUMN table_usage_stats.schema_name IS 'Schema name containing the table (default: public)';
COMMENT ON COLUMN table_usage_stats.select_count IS 'Number of SELECT operations performed on this table';
COMMENT ON COLUMN table_usage_stats.insert_count IS 'Number of INSERT operations performed on this table';
COMMENT ON COLUMN table_usage_stats.update_count IS 'Number of UPDATE operations performed on this table';
COMMENT ON COLUMN table_usage_stats.delete_count IS 'Number of DELETE operations performed on this table';
COMMENT ON COLUMN table_usage_stats.snapshot_at IS 'Timestamp when this usage snapshot was taken';
COMMENT ON COLUMN table_usage_stats.created_at IS 'Timestamp when this record was created';
COMMENT ON COLUMN table_usage_stats.updated_at IS 'Timestamp when this record was last updated';

-- Add unique constraint on table_name, schema_name, and snapshot_at combination
CREATE UNIQUE INDEX IF NOT EXISTS idx_table_usage_stats_table_schema_snapshot_unique
ON table_usage_stats (table_name, schema_name, snapshot_at);

-- Add index on snapshot_at for time-based queries
CREATE INDEX IF NOT EXISTS idx_table_usage_stats_snapshot_at
ON table_usage_stats (snapshot_at DESC);

-- Add index on table_name for table-specific lookups
CREATE INDEX IF NOT EXISTS idx_table_usage_stats_table_name
ON table_usage_stats (table_name);

-- Add index on schema_name for schema-specific analysis
CREATE INDEX IF NOT EXISTS idx_table_usage_stats_schema_name
ON table_usage_stats (schema_name);

-- Add composite index on total operations for finding most active tables
CREATE INDEX IF NOT EXISTS idx_table_usage_stats_total_operations
ON table_usage_stats ((select_count + insert_count + update_count + delete_count) DESC);

-- Add updated_at trigger to table_usage_stats table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_table_usage_stats_updated_at'
    ) THEN
        CREATE TRIGGER update_table_usage_stats_updated_at
            BEFORE UPDATE ON table_usage_stats
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create row-level security policies for admin role access
ALTER TABLE table_usage_stats ENABLE ROW LEVEL SECURITY;

-- Policy: Admin users can access all table usage statistics
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'table_usage_stats' 
        AND policyname = 'admin_all_table_usage_stats'
    ) THEN
        CREATE POLICY admin_all_table_usage_stats ON table_usage_stats
            FOR ALL TO admin USING (true);
    END IF;
END $$;

-- Grant permissions to admin role
DO $$ BEGIN
    -- Grant table permissions to admin role
    GRANT SELECT, INSERT, UPDATE, DELETE ON table_usage_stats TO admin;
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO admin;
EXCEPTION
    WHEN undefined_object THEN
        -- Roles might not exist in test environment
        NULL;
END $$;
