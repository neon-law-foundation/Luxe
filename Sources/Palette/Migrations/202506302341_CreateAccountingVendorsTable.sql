-- Create accounting.vendors table
-- This table stores vendor information with optional references to entities or people
CREATE TABLE IF NOT EXISTS accounting.vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    entity_id UUID NULL,
    person_id UUID NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    CONSTRAINT fk_vendors_entity FOREIGN KEY (entity_id) REFERENCES directory.entities (id),
    CONSTRAINT fk_vendors_person FOREIGN KEY (person_id) REFERENCES directory.people (id),
    CONSTRAINT chk_vendors_entity_or_person CHECK (
        (entity_id IS NOT NULL AND person_id IS NULL)
        OR (entity_id IS NULL AND person_id IS NOT NULL)
        OR (entity_id IS NULL AND person_id IS NULL)
    )
);

-- Add comments
COMMENT ON TABLE accounting.vendors IS 'Stores vendor information with optional references to entities or people';
COMMENT ON COLUMN accounting.vendors.id IS 'Unique identifier for the vendor';
COMMENT ON COLUMN accounting.vendors.name IS 'Name of the vendor';
COMMENT ON COLUMN accounting.vendors.entity_id IS 'Optional foreign key reference to directory.entities';
COMMENT ON COLUMN accounting.vendors.person_id IS 'Optional foreign key reference to directory.people';
COMMENT ON COLUMN accounting.vendors.created_at IS 'Timestamp when the vendor was created';
COMMENT ON COLUMN accounting.vendors.updated_at IS 'Timestamp when the vendor was last updated';

-- Create updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_accounting_vendors_updated_at'
    ) THEN
        CREATE TRIGGER update_accounting_vendors_updated_at 
        BEFORE UPDATE ON accounting.vendors
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create indexes on foreign keys
CREATE INDEX IF NOT EXISTS idx_vendors_entity_id ON accounting.vendors (entity_id);
CREATE INDEX IF NOT EXISTS idx_vendors_person_id ON accounting.vendors (person_id);

-- Row-level security
ALTER TABLE accounting.vendors ENABLE ROW LEVEL SECURITY;

-- Policy for customer role: can only read vendors
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'vendors_customer_read'
    ) THEN
        CREATE POLICY vendors_customer_read ON accounting.vendors
        FOR SELECT
        TO customer
        USING (TRUE);
    END IF;
END $$;

-- Policy for staff role: can read all vendors
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'vendors_staff_read'
    ) THEN
        CREATE POLICY vendors_staff_read ON accounting.vendors
        FOR SELECT
        TO staff
        USING (TRUE);
    END IF;
END $$;

-- Policy for staff role: can insert and update vendors
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'vendors_staff_write'
    ) THEN
        CREATE POLICY vendors_staff_write ON accounting.vendors
        FOR INSERT
        TO staff
        WITH CHECK (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'vendors_staff_update'
    ) THEN
        CREATE POLICY vendors_staff_update ON accounting.vendors
        FOR UPDATE
        TO staff
        USING (TRUE);
    END IF;
END $$;

-- Policy for admin role: full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'vendors_admin_all'
    ) THEN
        CREATE POLICY vendors_admin_all ON accounting.vendors
        FOR ALL
        TO admin
        USING (TRUE);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON accounting.vendors TO customer;
GRANT SELECT, INSERT, UPDATE ON accounting.vendors TO staff;
GRANT ALL ON accounting.vendors TO admin;
