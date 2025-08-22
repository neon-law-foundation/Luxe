-- Add performance indexes for statement_stats and statement_stats_hourly tables
-- This migration creates indexes to optimize query performance for the Postgres monitoring dashboard

-- Add composite index on statement_stats for query_id and snapshot_at lookups
-- This supports filtering by query_id and time-based range queries
CREATE INDEX IF NOT EXISTS idx_statement_stats_query_id_snapshot
ON statement_stats (query_id, snapshot_at);

COMMENT ON INDEX idx_statement_stats_query_id_snapshot IS
'Composite index for efficient query_id and time-based filtering on statement_stats';

-- Add composite index on statement_stats_hourly for hour and query_id lookups  
-- This supports hourly aggregation queries and query-specific time series data
CREATE INDEX IF NOT EXISTS idx_statement_stats_hourly_hour_query
ON statement_stats_hourly (hour, query_id);

COMMENT ON INDEX idx_statement_stats_hourly_hour_query IS
'Composite index for efficient time series and query-specific filtering on statement_stats_hourly';

-- Add index on snapshot_at for time-based queries on statement_stats
-- This supports dashboard queries filtering by time ranges
CREATE INDEX IF NOT EXISTS idx_statement_stats_snapshot_at
ON statement_stats (snapshot_at DESC);

COMMENT ON INDEX idx_statement_stats_snapshot_at IS
'Index for time-based filtering and ordering on statement_stats';

-- Add index on hour for time-based queries on statement_stats_hourly
-- This supports time series visualizations in the admin dashboard
CREATE INDEX IF NOT EXISTS idx_statement_stats_hourly_hour
ON statement_stats_hourly (hour DESC);

COMMENT ON INDEX idx_statement_stats_hourly_hour IS
'Index for time-based filtering and ordering on statement_stats_hourly';
