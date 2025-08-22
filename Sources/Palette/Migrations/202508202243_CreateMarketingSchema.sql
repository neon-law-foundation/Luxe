-- Create the marketing schema for newsletter management
DO $$
BEGIN
    -- Create the marketing schema if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'marketing') THEN
        CREATE SCHEMA marketing;
        COMMENT ON SCHEMA marketing IS 'Schema for newsletter management and marketing communications';
    END IF;

    -- Grant usage permissions on the marketing schema
    GRANT USAGE ON SCHEMA marketing TO customer, staff, admin;
END $$;
