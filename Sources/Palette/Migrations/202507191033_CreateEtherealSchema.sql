-- Create ethereal schema for astrocartography and astrological data
-- This schema contains all tables related to birth charts, astrocartography calculations,
-- and other mystical/astrological features

-- Create the ethereal schema
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.schemata
        WHERE schema_name = 'ethereal'
    ) THEN
        CREATE SCHEMA ethereal;
        COMMENT ON SCHEMA ethereal IS 'Schema for astrocartography, birth charts, and astrological data';
    END IF;
END $$;

-- Grant usage on ethereal schema to roles
DO $$ BEGIN
    -- Grant usage to customer role
    GRANT USAGE ON SCHEMA ethereal TO customer;
    
    -- Grant usage to staff role
    GRANT USAGE ON SCHEMA ethereal TO staff;
    
    -- Grant usage to admin role
    GRANT USAGE ON SCHEMA ethereal TO admin;
EXCEPTION
    WHEN undefined_object THEN
        -- Roles might not exist in test environment
        NULL;
END $$;
