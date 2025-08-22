-- Create legal.credentials table
-- This table stores professional licenses and credentials for people

-- Create the credentials table
CREATE TABLE IF NOT EXISTS legal.credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID NOT NULL,
    jurisdiction_id UUID NOT NULL,
    license_number VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,

    -- Foreign key constraints
    CONSTRAINT fk_credentials_person
    FOREIGN KEY (person_id) REFERENCES directory.people (id) ON DELETE CASCADE,
    CONSTRAINT fk_credentials_jurisdiction
    FOREIGN KEY (jurisdiction_id) REFERENCES legal.jurisdictions (id) ON DELETE CASCADE,

    -- Ensure unique license per person per jurisdiction
    CONSTRAINT uk_credentials_person_jurisdiction_license
    UNIQUE (person_id, jurisdiction_id, license_number)
);

-- Add comments to explain the table and columns
COMMENT ON TABLE legal.credentials IS 'Professional licenses and credentials held by people in various jurisdictions';
COMMENT ON COLUMN legal.credentials.id IS 'Unique identifier for the credential';
COMMENT ON COLUMN legal.credentials.person_id IS 'Reference to the person who holds this credential';
COMMENT ON COLUMN legal.credentials.jurisdiction_id IS 'Reference to the jurisdiction where this credential is valid';
COMMENT ON COLUMN legal.credentials.license_number IS 'The license or credential number';
COMMENT ON COLUMN legal.credentials.created_at IS 'When this credential record was created';
COMMENT ON COLUMN legal.credentials.updated_at IS 'When this credential record was last updated';

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_credentials_person_id ON legal.credentials (person_id);
CREATE INDEX IF NOT EXISTS idx_credentials_jurisdiction_id ON legal.credentials (jurisdiction_id);
CREATE INDEX IF NOT EXISTS idx_credentials_license_number ON legal.credentials (license_number);

-- Create trigger to automatically update updated_at on row updates
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_credentials_updated_at'
    ) THEN
        CREATE TRIGGER update_credentials_updated_at
        BEFORE UPDATE ON legal.credentials
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Grant permissions for legal.credentials table
GRANT USAGE ON SCHEMA legal TO customer;
GRANT USAGE ON SCHEMA legal TO staff;
GRANT USAGE ON SCHEMA legal TO admin;

GRANT SELECT ON legal.credentials TO customer;
GRANT SELECT ON legal.credentials TO staff;
GRANT SELECT ON legal.credentials TO admin;

GRANT INSERT, UPDATE ON legal.credentials TO staff;
GRANT INSERT, UPDATE, DELETE ON legal.credentials TO admin;
