-- Create legal.entity_types table

-- Create legal.entity_types table with legal_jurisdiction_id foreign key and name constraint
CREATE TABLE IF NOT EXISTS legal.entity_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legal_jurisdiction_id UUID NOT NULL,
    name VARCHAR(10) NOT NULL CHECK (name IN ('LLC', 'PLLC', 'Non-Profit')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    CONSTRAINT fk_entity_types_jurisdiction FOREIGN KEY (legal_jurisdiction_id) REFERENCES legal.jurisdictions (id),
    CONSTRAINT unique_jurisdiction_entity_type UNIQUE (legal_jurisdiction_id, name)
);

-- Add table comment
COMMENT ON TABLE legal.entity_types IS 'Types of legal entities within specific jurisdictions';

-- Add column comments
COMMENT ON COLUMN legal.entity_types.id IS 'Unique identifier for the entity type (UUIDv4)';
COMMENT ON COLUMN legal.entity_types.legal_jurisdiction_id IS
'Reference to the legal jurisdiction where this entity type is valid';
COMMENT ON COLUMN legal.entity_types.name IS 'Type of legal entity (LLC, PLLC, or Non-Profit)';
COMMENT ON COLUMN legal.entity_types.created_at IS 'Timestamp when the entity type record was created';
COMMENT ON COLUMN legal.entity_types.updated_at IS 'Timestamp when the entity type record was last updated';

-- Create trigger to automatically update updated_at on row updates
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_entity_types_updated_at'
    ) THEN
        CREATE TRIGGER update_entity_types_updated_at
        BEFORE UPDATE ON legal.entity_types
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create index on legal_jurisdiction_id for efficient lookups
CREATE INDEX IF NOT EXISTS idx_entity_types_jurisdiction ON legal.entity_types (legal_jurisdiction_id);

-- Enable row-level security
ALTER TABLE legal.entity_types ENABLE ROW LEVEL SECURITY;

-- Create row-level security policies for customer role
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'entity_types_customer_select' 
        AND polrelid = 'legal.entity_types'::regclass
    ) THEN
        CREATE POLICY entity_types_customer_select ON legal.entity_types
        FOR SELECT
        TO customer
        USING (true);
    END IF;
END $$;

-- Create row-level security policies for staff role
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'entity_types_staff_select' 
        AND polrelid = 'legal.entity_types'::regclass
    ) THEN
        CREATE POLICY entity_types_staff_select ON legal.entity_types
        FOR SELECT
        TO staff
        USING (true);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'entity_types_staff_insert' 
        AND polrelid = 'legal.entity_types'::regclass
    ) THEN
        CREATE POLICY entity_types_staff_insert ON legal.entity_types
        FOR INSERT
        TO staff
        WITH CHECK (true);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'entity_types_staff_update' 
        AND polrelid = 'legal.entity_types'::regclass
    ) THEN
        CREATE POLICY entity_types_staff_update ON legal.entity_types
        FOR UPDATE
        TO staff
        USING (true)
        WITH CHECK (true);
    END IF;
END $$;

-- Create row-level security policies for admin role
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'entity_types_admin_all' 
        AND polrelid = 'legal.entity_types'::regclass
    ) THEN
        CREATE POLICY entity_types_admin_all ON legal.entity_types
        FOR ALL
        TO admin
        USING (true)
        WITH CHECK (true);
    END IF;
END $$;

-- Grant permissions for legal.entity_types table
GRANT SELECT ON legal.entity_types TO customer;
GRANT SELECT, INSERT, UPDATE ON legal.entity_types TO staff;
GRANT ALL ON legal.entity_types TO admin;
