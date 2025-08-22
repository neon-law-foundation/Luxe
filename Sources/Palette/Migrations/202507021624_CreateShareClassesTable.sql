-- Create equity.share_classes table
-- This table stores share class information with references to directory entities
CREATE TABLE IF NOT EXISTS equity.share_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    entity_id UUID NOT NULL,
    priority INTEGER NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    CONSTRAINT fk_share_classes_entity FOREIGN KEY (entity_id) REFERENCES directory.entities (id)
);

-- Add comments
COMMENT ON TABLE equity.share_classes IS
'Stores share class information including name, priority, and entity reference';
COMMENT ON COLUMN equity.share_classes.id IS 'Unique identifier for the share class';
COMMENT ON COLUMN equity.share_classes.name IS 'Name of the share class';
COMMENT ON COLUMN equity.share_classes.entity_id IS 'Foreign key reference to the directory entity';
COMMENT ON COLUMN equity.share_classes.priority IS 'Priority level of the share class';
COMMENT ON COLUMN equity.share_classes.description IS 'Description of the share class';
COMMENT ON COLUMN equity.share_classes.created_at IS 'Timestamp when the share class was created';
COMMENT ON COLUMN equity.share_classes.updated_at IS 'Timestamp when the share class was last updated';

-- Create updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_equity_share_classes_updated_at'
    ) THEN
        CREATE TRIGGER update_equity_share_classes_updated_at
        BEFORE UPDATE ON equity.share_classes
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create unique compound index for entity_id and priority
CREATE UNIQUE INDEX IF NOT EXISTS idx_share_classes_entity_priority_unique
ON equity.share_classes (entity_id, priority);

-- Create index on foreign key
CREATE INDEX IF NOT EXISTS idx_share_classes_entity_id ON equity.share_classes (entity_id);

-- Row-level security
ALTER TABLE equity.share_classes ENABLE ROW LEVEL SECURITY;

-- Policy for customer role: can only read share classes
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'share_classes_customer_read'
    ) THEN
        CREATE POLICY share_classes_customer_read ON equity.share_classes
        FOR SELECT
        TO customer
        USING (true);
    END IF;
END $$;

-- Policy for staff role: can read all share classes
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'share_classes_staff_read'
    ) THEN
        CREATE POLICY share_classes_staff_read ON equity.share_classes
        FOR SELECT
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for admin role: full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'share_classes_admin_all'
    ) THEN
        CREATE POLICY share_classes_admin_all ON equity.share_classes
        FOR ALL
        TO admin
        USING (true);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON equity.share_classes TO customer;
GRANT SELECT ON equity.share_classes TO staff;
GRANT ALL ON equity.share_classes TO admin;
