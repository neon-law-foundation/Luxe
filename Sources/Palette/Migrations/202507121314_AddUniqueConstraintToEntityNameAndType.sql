-- Add unique constraint to ensure entity names are unique within each entity type
-- This prevents creating multiple entities with the same name and legal entity type

DO $$
BEGIN
    -- Add unique constraint on (name, legal_entity_type_id) combination
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_entities_name_type' 
        AND connamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'directory')
    ) THEN
        ALTER TABLE directory.entities 
        ADD CONSTRAINT uq_entities_name_type 
        UNIQUE (name, legal_entity_type_id);
        
        COMMENT ON CONSTRAINT uq_entities_name_type ON directory.entities IS 
        'Ensures entity names are unique within each legal entity type';
    END IF;
END $$;

COMMENT ON TABLE directory.entities IS 'Stores entity information with unique names per entity type';
