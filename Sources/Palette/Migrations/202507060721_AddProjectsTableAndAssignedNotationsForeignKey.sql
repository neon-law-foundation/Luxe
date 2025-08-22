-- Create matters.projects table and add foreign key to assigned_notations

-- Create matters.projects table with codename and timestamps
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'matters'
        AND tablename = 'projects'
    ) THEN
        CREATE TABLE matters.projects (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            codename VARCHAR(255) NOT NULL UNIQUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL
        );

        -- Create index on codename for performance
        CREATE INDEX idx_projects_codename ON matters.projects(codename);
    END IF;
END $$;

-- Add updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_matters_projects_updated_at'
    ) THEN
        CREATE TRIGGER update_matters_projects_updated_at
        BEFORE UPDATE ON matters.projects
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE matters.projects ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Customer role: Can view projects (will be filtered by their assigned notations)
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'projects'
        AND policyname = 'projects_customer_select_policy'
    ) THEN
        CREATE POLICY projects_customer_select_policy ON matters.projects
        FOR SELECT TO customer
        USING (TRUE);
    END IF;
END $$;

-- Staff role: Can view and manage all projects
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'projects'
        AND policyname = 'projects_staff_select_policy'
    ) THEN
        CREATE POLICY projects_staff_select_policy ON matters.projects
        FOR SELECT TO staff
        USING (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'projects'
        AND policyname = 'projects_staff_insert_policy'
    ) THEN
        CREATE POLICY projects_staff_insert_policy ON matters.projects
        FOR INSERT TO staff
        WITH CHECK (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'projects'
        AND policyname = 'projects_staff_update_policy'
    ) THEN
        CREATE POLICY projects_staff_update_policy ON matters.projects
        FOR UPDATE TO staff
        USING (TRUE)
        WITH CHECK (TRUE);
    END IF;
END $$;

-- Admin role: Full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'projects'
        AND policyname = 'projects_admin_all_policy'
    ) THEN
        CREATE POLICY projects_admin_all_policy ON matters.projects
        FOR ALL TO admin
        USING (TRUE)
        WITH CHECK (TRUE);
    END IF;
END $$;

-- Grant permissions to roles
GRANT SELECT ON matters.projects TO customer;
GRANT SELECT, INSERT, UPDATE ON matters.projects TO staff;
GRANT ALL ON matters.projects TO admin;

-- Add comments for documentation
COMMENT ON TABLE matters.projects IS 'Projects that group assigned notations together';
COMMENT ON COLUMN matters.projects.id IS 'Unique identifier for the project';
COMMENT ON COLUMN matters.projects.codename IS 'Unique codename for the project';
COMMENT ON COLUMN matters.projects.created_at IS 'Timestamp when the project was created';
COMMENT ON COLUMN matters.projects.updated_at IS 'Timestamp when the project was last updated';

-- Add project_id column to matters.assigned_notations
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'matters' 
        AND table_name = 'assigned_notations' 
        AND column_name = 'project_id'
    ) THEN
        -- First, add the column as nullable
        ALTER TABLE matters.assigned_notations 
        ADD COLUMN project_id UUID;
        
        -- Create a default project for existing records if they exist
        INSERT INTO matters.projects (id, codename, created_at, updated_at)
        SELECT gen_random_uuid(), 'DEFAULT-PROJECT', current_timestamp, current_timestamp
        WHERE EXISTS (SELECT 1 FROM matters.assigned_notations WHERE project_id IS NULL)
        ON CONFLICT DO NOTHING;
        
        -- Update all NULL project_id values to reference the default project
        UPDATE matters.assigned_notations 
        SET project_id = (SELECT id FROM matters.projects WHERE codename = 'DEFAULT-PROJECT' LIMIT 1)
        WHERE project_id IS NULL;

        -- Now make the column NOT NULL and add the foreign key constraint
        ALTER TABLE matters.assigned_notations 
        ALTER COLUMN project_id SET NOT NULL,
        ADD CONSTRAINT fk_assigned_notations_project
            FOREIGN KEY (project_id)
            REFERENCES matters.projects(id)
            ON DELETE CASCADE;

        -- Create index for foreign key
        CREATE INDEX idx_assigned_notations_project_id
            ON matters.assigned_notations(project_id);
    END IF;
END $$;

-- Add comment for the new column
COMMENT ON COLUMN matters.assigned_notations.project_id IS
'Foreign key reference to the project this notation assignment belongs to';
