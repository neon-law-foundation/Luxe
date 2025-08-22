-- Create directory.entities table
-- This table stores entity information with references to their legal entity type
CREATE TABLE IF NOT EXISTS directory.entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    legal_entity_type_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    CONSTRAINT fk_entities_entity_type FOREIGN KEY (legal_entity_type_id) REFERENCES legal.entity_types (id)
);

-- Add comments
COMMENT ON TABLE directory.entities IS 'Stores entity information including their name and legal entity type';
COMMENT ON COLUMN directory.entities.id IS 'Unique identifier for the entity';
COMMENT ON COLUMN directory.entities.name IS 'Name of the entity';
COMMENT ON COLUMN directory.entities.legal_entity_type_id IS 'Foreign key reference to the legal entity type';
COMMENT ON COLUMN directory.entities.created_at IS 'Timestamp when the entity was created';
COMMENT ON COLUMN directory.entities.updated_at IS 'Timestamp when the entity was last updated';

-- Create updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_directory_entities_updated_at'
    ) THEN
        CREATE TRIGGER update_directory_entities_updated_at 
        BEFORE UPDATE ON directory.entities
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create index on foreign key
CREATE INDEX IF NOT EXISTS idx_entities_legal_entity_type_id ON directory.entities (legal_entity_type_id);

-- Row-level security
ALTER TABLE directory.entities ENABLE ROW LEVEL SECURITY;

-- Policy for customer role: can only read entities
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'entities_customer_read' 
        AND polrelid = 'directory.entities'::regclass
    ) THEN
        CREATE POLICY entities_customer_read ON directory.entities
        FOR SELECT
        TO customer
        USING (true);
    END IF;
END $$;

-- Policy for staff role: can read all entities
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'entities_staff_read' 
        AND polrelid = 'directory.entities'::regclass
    ) THEN
        CREATE POLICY entities_staff_read ON directory.entities
        FOR SELECT
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for admin role: full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'entities_admin_all' 
        AND polrelid = 'directory.entities'::regclass
    ) THEN
        CREATE POLICY entities_admin_all ON directory.entities
        FOR ALL
        TO admin
        USING (true);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON directory.entities TO customer;
GRANT SELECT ON directory.entities TO staff;
GRANT ALL ON directory.entities TO admin;
