-- Create the service schema for customer service ticket management
DO $$
BEGIN
    -- Create the service schema if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'service') THEN
        CREATE SCHEMA service;
        COMMENT ON SCHEMA service IS 'Schema for customer service ticket management and support';
    END IF;

    -- Grant usage permissions on the service schema
    GRANT USAGE ON SCHEMA service TO customer, staff, admin;
END $$;
