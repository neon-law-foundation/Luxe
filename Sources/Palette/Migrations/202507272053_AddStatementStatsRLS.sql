-- Add Row Level Security policies for statement analysis tables
-- This migration enables RLS and creates policies for admin role access to PostgreSQL monitoring data

-- Enable RLS on statement_stats table (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class 
        WHERE relname = 'statement_stats' 
        AND relrowsecurity = true
    ) THEN
        ALTER TABLE statement_stats ENABLE ROW LEVEL SECURITY;
    END IF;
END
$$;

-- Create policy for admin role to have full access to statement_stats (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'statement_stats' 
        AND policyname = 'statement_stats_admin_policy'
    ) THEN
        CREATE POLICY statement_stats_admin_policy ON statement_stats
        FOR ALL TO admin
        USING (true)
        WITH CHECK (true);
    END IF;
END
$$;

COMMENT ON POLICY statement_stats_admin_policy ON statement_stats IS
'Admin role has full access to view and manage PostgreSQL statement statistics';

-- Enable RLS on statement_stats_hourly table (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class 
        WHERE relname = 'statement_stats_hourly' 
        AND relrowsecurity = true
    ) THEN
        ALTER TABLE statement_stats_hourly ENABLE ROW LEVEL SECURITY;
    END IF;
END
$$;

-- Create policy for admin role to have full access to statement_stats_hourly (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'statement_stats_hourly' 
        AND policyname = 'statement_stats_hourly_admin_policy'
    ) THEN
        CREATE POLICY statement_stats_hourly_admin_policy ON statement_stats_hourly
        FOR ALL TO admin
        USING (true)
        WITH CHECK (true);
    END IF;
END
$$;

COMMENT ON POLICY statement_stats_hourly_admin_policy ON statement_stats_hourly IS
'Admin role has full access to view and manage PostgreSQL hourly statement statistics';

-- Enable RLS on table_usage_stats table (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class 
        WHERE relname = 'table_usage_stats' 
        AND relrowsecurity = true
    ) THEN
        ALTER TABLE table_usage_stats ENABLE ROW LEVEL SECURITY;
    END IF;
END
$$;

-- Create policy for admin role to have full access to table_usage_stats (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'table_usage_stats' 
        AND policyname = 'table_usage_stats_admin_policy'
    ) THEN
        CREATE POLICY table_usage_stats_admin_policy ON table_usage_stats
        FOR ALL TO admin
        USING (true)
        WITH CHECK (true);
    END IF;
END
$$;

COMMENT ON POLICY table_usage_stats_admin_policy ON table_usage_stats IS
'Admin role has full access to view and manage PostgreSQL table usage statistics';
