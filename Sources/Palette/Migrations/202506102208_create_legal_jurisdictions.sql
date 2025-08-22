-- Create legal.jurisdictions table

-- Create legal.jurisdictions table with name, code, and timestamps
CREATE TABLE IF NOT EXISTS legal.jurisdictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    code CITEXT NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp
);

-- Add table comment
COMMENT ON TABLE legal.jurisdictions IS 'Legal jurisdictions with their names and unique codes';

-- Add column comments
COMMENT ON COLUMN legal.jurisdictions.id IS 'Unique identifier for the jurisdiction (UUIDv4)';
COMMENT ON COLUMN legal.jurisdictions.name IS 'Full name of the jurisdiction';
COMMENT ON COLUMN legal.jurisdictions.code IS 'Unique code for the jurisdiction (case insensitive)';
COMMENT ON COLUMN legal.jurisdictions.created_at IS 'Timestamp when the jurisdiction record was created';
COMMENT ON COLUMN legal.jurisdictions.updated_at IS 'Timestamp when the jurisdiction record was last updated';

-- Create trigger to automatically update updated_at on row updates
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_jurisdictions_updated_at'
    ) THEN
        CREATE TRIGGER update_jurisdictions_updated_at
        BEFORE UPDATE ON legal.jurisdictions
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Grant permissions for legal.jurisdictions table
GRANT USAGE ON SCHEMA legal TO customer;
GRANT USAGE ON SCHEMA legal TO staff;
GRANT USAGE ON SCHEMA legal TO admin;

GRANT SELECT ON legal.jurisdictions TO customer;
GRANT SELECT ON legal.jurisdictions TO staff;
GRANT SELECT ON legal.jurisdictions TO admin;

GRANT INSERT, UPDATE ON legal.jurisdictions TO staff;
GRANT INSERT, UPDATE, DELETE ON legal.jurisdictions TO admin;
