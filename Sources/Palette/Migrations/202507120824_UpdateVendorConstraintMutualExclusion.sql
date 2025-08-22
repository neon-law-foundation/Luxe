-- Update accounting.vendors table constraint to enforce mutual exclusion
-- Exactly one of entity_id or person_id must be set, not both and not neither

-- Drop the existing constraint that allows both to be NULL
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'chk_vendors_entity_or_person'
        AND table_name = 'vendors'
        AND table_schema = 'accounting'
    ) THEN
        ALTER TABLE accounting.vendors DROP CONSTRAINT chk_vendors_entity_or_person;
    END IF;
END $$;

-- Add new constraint that enforces exactly one must be set
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'chk_vendors_exactly_one_reference'
        AND table_name = 'vendors'
        AND table_schema = 'accounting'
    ) THEN
        ALTER TABLE accounting.vendors ADD CONSTRAINT chk_vendors_exactly_one_reference CHECK (
            (entity_id IS NOT NULL AND person_id IS NULL)
            OR (entity_id IS NULL AND person_id IS NOT NULL)
        );
    END IF;
END $$;

-- Update comments to reflect the new constraint
COMMENT ON CONSTRAINT chk_vendors_exactly_one_reference ON accounting.vendors IS
'Ensures exactly one of entity_id or person_id is set, enforcing mutual exclusion';
