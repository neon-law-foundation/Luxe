-- Add person_id column to directory.address table and enforce XOR constraint
-- This migration ensures addresses are tied to either an entity OR a person, but not both and not neither

-- Add person_id column
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'directory'
        AND table_name = 'address'
        AND column_name = 'person_id'
    ) THEN
        ALTER TABLE directory.address ADD COLUMN person_id UUID NULL;
    END IF;
END $$;

-- Add foreign key constraint to directory.people
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_address_person'
    ) THEN
        ALTER TABLE directory.address
        ADD CONSTRAINT fk_address_person
        FOREIGN KEY (person_id) REFERENCES directory.people (id);
    END IF;
END $$;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_address_person_id ON directory.address (person_id);

-- Drop the old NOT NULL constraint on entity_id
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'directory'
        AND table_name = 'address'
        AND column_name = 'entity_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE directory.address ALTER COLUMN entity_id DROP NOT NULL;
    END IF;
END $$;

-- Add XOR constraint: exactly one of entity_id or person_id must be set
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_address_entity_or_person_exclusive'
    ) THEN
        ALTER TABLE directory.address
        ADD CONSTRAINT chk_address_entity_or_person_exclusive CHECK (
            (entity_id IS NOT NULL AND person_id IS NULL)
            OR (entity_id IS NULL AND person_id IS NOT NULL)
        );
    END IF;
END $$;

-- Add comments for the new column
COMMENT ON COLUMN directory.address.person_id IS
'Foreign key reference to the person this address belongs to (mutually exclusive with entity_id)';

-- Update table comment to reflect the new constraint
COMMENT ON TABLE directory.address IS
'Stores physical addresses for entities and people (each address must belong to exactly one entity or person)';

-- Update existing entity_id comment for clarity
COMMENT ON COLUMN directory.address.entity_id IS
'Foreign key reference to the entity this address belongs to (mutually exclusive with person_id)';
