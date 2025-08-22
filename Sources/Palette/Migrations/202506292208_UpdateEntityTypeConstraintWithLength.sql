-- Update entity_types name constraint to allow all entity types from seeds file

-- First, expand the varchar length to accommodate longer names
ALTER TABLE legal.entity_types ALTER COLUMN name TYPE VARCHAR(50);

-- Drop the existing constraint
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'entity_types_name_check'
        AND constraint_schema = 'legal'
        AND table_name = 'entity_types'
    ) THEN
        ALTER TABLE legal.entity_types DROP CONSTRAINT entity_types_name_check;
    END IF;
END $$;

-- Add the new constraint with expanded allowed values
ALTER TABLE legal.entity_types
ADD CONSTRAINT entity_types_name_check
CHECK (name IN (
    'LLC',
    'PLLC',
    'Non-Profit',
    'C-Corp',
    'Single Member LLC',
    'Multi Member LLC',
    '501(c)(3) Non-Profit',
    'Family Trust',
    'Human',
    'Foreign Company'
));

-- Update the column comment to reflect the new allowed values
COMMENT ON COLUMN legal.entity_types.name IS
'Type of legal entity (LLC, PLLC, Non-Profit, C-Corp, Single Member LLC, Multi Member LLC, 501(c)(3) Non-Profit,
Family Trust, Human, Foreign Company)';
