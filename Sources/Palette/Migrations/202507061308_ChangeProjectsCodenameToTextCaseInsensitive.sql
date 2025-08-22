-- Change matters.projects.codename from VARCHAR(255) to CITEXT for case-insensitive text handling

-- Enable citext extension if not already enabled
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'citext'
    ) THEN
        CREATE EXTENSION citext;
    END IF;
END $$;

-- Change the codename column to CITEXT
DO $$ BEGIN
    -- Check if the column is not already CITEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'matters' 
        AND table_name = 'projects' 
        AND column_name = 'codename'
        AND data_type = 'character varying'
    ) THEN
        -- Drop the existing index
        DROP INDEX IF EXISTS idx_projects_codename;
        
        -- Change the column type to CITEXT
        ALTER TABLE matters.projects 
        ALTER COLUMN codename TYPE CITEXT USING codename::CITEXT;
        
        -- Recreate the index on the CITEXT column
        CREATE INDEX IF NOT EXISTS idx_projects_codename ON matters.projects(codename);
    END IF;
END $$;

-- Add comment explaining the change
COMMENT ON COLUMN matters.projects.codename IS
'Case-insensitive unique codename for the project using CITEXT type';
