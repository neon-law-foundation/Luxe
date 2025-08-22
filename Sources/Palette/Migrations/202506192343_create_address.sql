-- Create directory.address table
-- This table stores address information for entities and people
CREATE TABLE IF NOT EXISTS directory.address (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id UUID NOT NULL,
    street TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT,
    zip TEXT,
    country TEXT NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    CONSTRAINT fk_address_entity FOREIGN KEY (entity_id) REFERENCES directory.entities (id)
);

-- Add comments
COMMENT ON TABLE directory.address IS 'Stores physical addresses for entities and people';
COMMENT ON COLUMN directory.address.id IS 'Unique identifier for the address';
COMMENT ON COLUMN directory.address.entity_id IS 'Foreign key reference to the entity this address belongs to';
COMMENT ON COLUMN directory.address.street IS 'Street address including number and street name';
COMMENT ON COLUMN directory.address.city IS 'City name';
COMMENT ON COLUMN directory.address.state IS 'State or province (optional for international addresses)';
COMMENT ON COLUMN directory.address.zip IS 'Postal code (optional for some countries)';
COMMENT ON COLUMN directory.address.country IS 'Country name';
COMMENT ON COLUMN directory.address.is_verified IS 'Whether the address has been verified as valid';
COMMENT ON COLUMN directory.address.created_at IS 'Timestamp when the address was created';
COMMENT ON COLUMN directory.address.updated_at IS 'Timestamp when the address was last updated';

-- Create updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_directory_address_updated_at'
    ) THEN
        CREATE TRIGGER update_directory_address_updated_at 
        BEFORE UPDATE ON directory.address
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_address_entity_id ON directory.address (entity_id);
CREATE INDEX IF NOT EXISTS idx_address_is_verified ON directory.address (is_verified);

-- Row-level security
ALTER TABLE directory.address ENABLE ROW LEVEL SECURITY;

-- Policy for customer role: can only read addresses
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'address_customer_read'
    ) THEN
        CREATE POLICY address_customer_read ON directory.address
        FOR SELECT
        TO customer
        USING (true);
    END IF;
END $$;

-- Policy for staff role: can read all addresses
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'address_staff_read'
    ) THEN
        CREATE POLICY address_staff_read ON directory.address
        FOR SELECT
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for admin role: full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'address_admin_all'
    ) THEN
        CREATE POLICY address_admin_all ON directory.address
        FOR ALL
        TO admin
        USING (true);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON directory.address TO customer;
GRANT SELECT ON directory.address TO staff;
GRANT ALL ON directory.address TO admin;
