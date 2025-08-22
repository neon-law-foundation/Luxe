-- Create notations table in the standards schema
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'standards'
        AND tablename = 'notations'
    ) THEN
        CREATE TABLE standards.notations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            uid TEXT NOT NULL,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            flow JSONB NOT NULL DEFAULT '{}'::JSONB,
            code CITEXT NOT NULL,
            document_url VARCHAR(255),
            document_mappings JSONB,
            alignment JSONB NOT NULL DEFAULT '{}'::JSONB,
            respondent_type VARCHAR(255),
            document_text TEXT,
            document_type VARCHAR(255),
            repository VARCHAR(255),
            commit_sha VARCHAR(255),
            published BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL
        );

        -- Add unique constraint on uid
        ALTER TABLE standards.notations
        ADD CONSTRAINT notations_uid_unique UNIQUE (uid);

        -- Add unique constraint on code
        ALTER TABLE standards.notations
        ADD CONSTRAINT notations_code_unique UNIQUE (code);

        -- Create index on code for faster lookups
        CREATE INDEX idx_notations_code ON standards.notations(code);

        -- Create index on published for filtering
        CREATE INDEX idx_notations_published ON standards.notations(published);

        -- Create index on document_type for filtering
        CREATE INDEX idx_notations_document_type ON standards.notations(document_type);

        -- Add check constraint for respondent_type
        ALTER TABLE standards.notations
        ADD CONSTRAINT notations_respondent_type_check 
        CHECK (respondent_type IN ('org', 'org_and_user'));
    END IF;
END $$;

-- Add updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_standards_notations_updated_at'
    ) THEN
        CREATE TRIGGER update_standards_notations_updated_at
        BEFORE UPDATE ON standards.notations
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE standards.notations ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Customer role: Can view published notations
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations'
        AND policyname = 'notations_customer_select_policy'
    ) THEN
        CREATE POLICY notations_customer_select_policy ON standards.notations
        FOR SELECT TO customer
        USING (published = TRUE);
    END IF;
END $$;

-- Staff role: Can view all notations and create/update unpublished ones
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations'
        AND policyname = 'notations_staff_select_policy'
    ) THEN
        CREATE POLICY notations_staff_select_policy ON standards.notations
        FOR SELECT TO staff
        USING (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations'
        AND policyname = 'notations_staff_insert_policy'
    ) THEN
        CREATE POLICY notations_staff_insert_policy ON standards.notations
        FOR INSERT TO staff
        WITH CHECK (published = FALSE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations'
        AND policyname = 'notations_staff_update_policy'
    ) THEN
        CREATE POLICY notations_staff_update_policy ON standards.notations
        FOR UPDATE TO staff
        USING (published = FALSE)
        WITH CHECK (published = FALSE);
    END IF;
END $$;

-- Admin role: Full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations'
        AND policyname = 'notations_admin_all_policy'
    ) THEN
        CREATE POLICY notations_admin_all_policy ON standards.notations
        FOR ALL TO admin
        USING (TRUE)
        WITH CHECK (TRUE);
    END IF;
END $$;

-- Grant permissions to roles
GRANT SELECT ON standards.notations TO customer;
GRANT SELECT, INSERT, UPDATE ON standards.notations TO staff;
GRANT ALL ON standards.notations TO admin;

-- Add comments for documentation
COMMENT ON TABLE standards.notations IS
'A Notation is a collection of documents, questionnaires, and workflows';
COMMENT ON COLUMN standards.notations.id IS 'Unique identifier for the notation';
COMMENT ON COLUMN standards.notations.uid IS 'User-defined unique identifier for the notation';
COMMENT ON COLUMN standards.notations.title IS 'Title of the notation';
COMMENT ON COLUMN standards.notations.description IS 'Detailed description of the notation';
COMMENT ON COLUMN standards.notations.flow IS
'How users are presented with questions. Must adhere to @question_map_schema. Empty if published=true';
COMMENT ON COLUMN standards.notations.code IS 'Case-insensitive unique code identifier for the notation';
COMMENT ON COLUMN standards.notations.document_url IS 'URL reference to the associated document';
COMMENT ON COLUMN standards.notations.document_mappings IS
'PDF field placement coordinates. Each mapping defines a rectangle with upper_left, lower_left, upper_right, '
'lower_right coordinates in PDF coordinate system (0,0 at top-left). For Markdown files, use Handlebars instead';
COMMENT ON COLUMN standards.notations.alignment IS
'How staff review questionnaires and provide answers. Must adhere to @question_map_schema. Empty if published=true';
COMMENT ON COLUMN standards.notations.respondent_type IS
'Must be "org" or "org_and_user". Determines if notation is for whole org (e.g., Secretary of State filing) '
'or org and user (e.g., 83(b) election). Organization filings may need completion by multiple members';
COMMENT ON COLUMN standards.notations.document_text IS 'Full text content of the associated document';
COMMENT ON COLUMN standards.notations.document_type IS 'Type classification of the associated document';
COMMENT ON COLUMN standards.notations.repository IS
'Neon Law GitHub repository where the notation is stored';
COMMENT ON COLUMN standards.notations.commit_sha IS 'Latest main branch commit SHA of most recent notation changes';
COMMENT ON COLUMN standards.notations.published IS
'If true, flow and alignment are empty. Used for public notations like privacy policies posted on websites';
COMMENT ON COLUMN standards.notations.created_at IS 'Timestamp when the notation was created';
COMMENT ON COLUMN standards.notations.updated_at IS 'Timestamp when the notation was last updated';
