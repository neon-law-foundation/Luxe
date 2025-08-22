-- Change assigned_notations project foreign key constraint from ON DELETE CASCADE to ON DELETE SET NULL
-- This allows projects to be deleted without deleting the assigned notations

DO $$ BEGIN
    -- First check if the constraint exists
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_schema = 'matters' 
        AND table_name = 'assigned_notations' 
        AND constraint_name = 'fk_assigned_notations_project'
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        -- Drop the existing foreign key constraint
        ALTER TABLE matters.assigned_notations 
        DROP CONSTRAINT fk_assigned_notations_project;
        
        -- Make the project_id column nullable since we're changing to SET NULL
        ALTER TABLE matters.assigned_notations 
        ALTER COLUMN project_id DROP NOT NULL;
        
        -- Recreate the foreign key constraint with ON DELETE SET NULL
        ALTER TABLE matters.assigned_notations 
        ADD CONSTRAINT fk_assigned_notations_project
            FOREIGN KEY (project_id)
            REFERENCES matters.projects(id)
            ON DELETE SET NULL;
    END IF;
END $$;

-- Update the column comment to reflect the new behavior
COMMENT ON COLUMN matters.assigned_notations.project_id IS
'Foreign key reference to the project this notation assignment belongs to. Set to NULL when project is deleted.';
