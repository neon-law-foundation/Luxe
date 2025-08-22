-- Create table usage extraction function for analyzing query patterns
-- This migration creates a function to parse queries and update table_usage_stats

CREATE OR REPLACE FUNCTION admin.extract_table_usage_stats()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rows_processed INTEGER := 0;
    current_snapshot TIMESTAMP := NOW();
    query_record RECORD;
    table_pattern TEXT;
    matched_table TEXT;
    matched_schema TEXT;
BEGIN
    -- Clear existing stats for this snapshot to avoid duplicates
    DELETE FROM table_usage_stats 
    WHERE snapshot_at = date_trunc('hour', current_snapshot);
    
    -- Process each unique query from recent statement stats
    FOR query_record IN 
        SELECT DISTINCT query_text 
        FROM statement_stats 
        WHERE snapshot_at >= current_snapshot - INTERVAL '1 hour'
        AND query_text IS NOT NULL
        AND LENGTH(query_text) > 10
    LOOP
        -- Extract table references using regex patterns
        -- Pattern for schema.table format
        FOR matched_schema, matched_table IN
            SELECT 
                (regexp_matches(query_record.query_text, '(?:FROM|JOIN|UPDATE|INSERT INTO|DELETE FROM)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\.\s*([a-zA-Z_][a-zA-Z0-9_]*)', 'gi'))[1] AS schema_name,
                (regexp_matches(query_record.query_text, '(?:FROM|JOIN|UPDATE|INSERT INTO|DELETE FROM)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\.\s*([a-zA-Z_][a-zA-Z0-9_]*)', 'gi'))[2] AS table_name
        LOOP
            -- Update or insert table usage stats
            INSERT INTO table_usage_stats (
                id,
                table_name,
                schema_name,
                select_count,
                insert_count,
                update_count,
                delete_count,
                snapshot_at,
                created_at,
                updated_at
            )
            VALUES (
                gen_random_uuid(),
                matched_table,
                matched_schema,
                CASE WHEN query_record.query_text ~* '^\s*SELECT' THEN 1 ELSE 0 END,
                CASE WHEN query_record.query_text ~* '^\s*INSERT' THEN 1 ELSE 0 END,
                CASE WHEN query_record.query_text ~* '^\s*UPDATE' THEN 1 ELSE 0 END,
                CASE WHEN query_record.query_text ~* '^\s*DELETE' THEN 1 ELSE 0 END,
                date_trunc('hour', current_snapshot),
                current_snapshot,
                current_snapshot
            )
            ON CONFLICT (schema_name, table_name, snapshot_at) DO UPDATE
            SET 
                select_count = table_usage_stats.select_count + EXCLUDED.select_count,
                insert_count = table_usage_stats.insert_count + EXCLUDED.insert_count,
                update_count = table_usage_stats.update_count + EXCLUDED.update_count,
                delete_count = table_usage_stats.delete_count + EXCLUDED.delete_count,
                updated_at = current_snapshot;
        END LOOP;
        
        -- Pattern for table without schema (assumes public schema)
        FOR matched_table IN
            SELECT DISTINCT
                (regexp_matches(query_record.query_text, '(?:FROM|JOIN|UPDATE|INSERT INTO|DELETE FROM)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:WHERE|SET|VALUES|ORDER|GROUP|LIMIT|;|$)', 'gi'))[1] AS table_name
        LOOP
            -- Skip if this looks like a schema name (followed by a dot)
            IF query_record.query_text !~* (matched_table || '\s*\.') THEN
                -- Update or insert table usage stats for public schema
                INSERT INTO table_usage_stats (
                    id,
                    table_name,
                    schema_name,
                    select_count,
                    insert_count,
                    update_count,
                    delete_count,
                    snapshot_at,
                    created_at,
                    updated_at
                )
                VALUES (
                    gen_random_uuid(),
                    matched_table,
                    'public',
                    CASE WHEN query_record.query_text ~* '^\s*SELECT' THEN 1 ELSE 0 END,
                    CASE WHEN query_record.query_text ~* '^\s*INSERT' THEN 1 ELSE 0 END,
                    CASE WHEN query_record.query_text ~* '^\s*UPDATE' THEN 1 ELSE 0 END,
                    CASE WHEN query_record.query_text ~* '^\s*DELETE' THEN 1 ELSE 0 END,
                    date_trunc('hour', current_snapshot),
                    current_snapshot,
                    current_snapshot
                )
                ON CONFLICT (schema_name, table_name, snapshot_at) DO UPDATE
                SET 
                    select_count = table_usage_stats.select_count + EXCLUDED.select_count,
                    insert_count = table_usage_stats.insert_count + EXCLUDED.insert_count,
                    update_count = table_usage_stats.update_count + EXCLUDED.update_count,
                    delete_count = table_usage_stats.delete_count + EXCLUDED.delete_count,
                    updated_at = current_snapshot;
            END IF;
        END LOOP;
        
        rows_processed := rows_processed + 1;
    END LOOP;
    
    -- Log the extraction operation
    RAISE NOTICE 'Processed % queries and extracted table usage statistics at %', rows_processed, current_snapshot;
    
    RETURN rows_processed;
END;
$$;

COMMENT ON FUNCTION admin.extract_table_usage_stats() IS
'Parses queries from statement_stats and extracts table usage patterns into table_usage_stats';

-- Grant execute permission to admin role
GRANT EXECUTE ON FUNCTION admin.extract_table_usage_stats() TO admin;

-- Add unique constraint to prevent duplicate entries (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uk_table_usage_stats_unique'
        AND conrelid = 'table_usage_stats'::regclass
    ) THEN
        ALTER TABLE table_usage_stats ADD CONSTRAINT uk_table_usage_stats_unique
        UNIQUE (schema_name, table_name, snapshot_at);
    END IF;
END
$$;
