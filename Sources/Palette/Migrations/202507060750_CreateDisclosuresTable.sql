-- Create matters.disclosures table
-- This table is a join table between legal.credentials and matters.projects
-- It tracks disclosure periods for legal credentials on specific projects

-- Create the disclosures table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'matters'
        AND table_name = 'disclosures'
    ) THEN
        CREATE TABLE matters.disclosures (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            credential_id UUID NOT NULL,
            project_id UUID NOT NULL,
            disclosed_at DATE NOT NULL,
            end_disclosed_at DATE,
            active BOOLEAN DEFAULT TRUE NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,

            -- Foreign key constraints
            CONSTRAINT fk_disclosures_credential
                FOREIGN KEY (credential_id)
                REFERENCES legal.credentials(id)
                ON DELETE CASCADE,
            CONSTRAINT fk_disclosures_project
                FOREIGN KEY (project_id)
                REFERENCES matters.projects(id)
                ON DELETE CASCADE,

            -- Ensure disclosed_at is before end_disclosed_at when both are present
            CONSTRAINT chk_disclosures_date_order
                CHECK (end_disclosed_at IS NULL OR disclosed_at <= end_disclosed_at)
        );

        -- Create indexes for performance
        CREATE INDEX idx_disclosures_credential_id ON matters.disclosures(credential_id);
        CREATE INDEX idx_disclosures_project_id ON matters.disclosures(project_id);
        CREATE INDEX idx_disclosures_disclosed_at ON matters.disclosures(disclosed_at);
        CREATE INDEX idx_disclosures_end_disclosed_at ON matters.disclosures(end_disclosed_at);
        CREATE INDEX idx_disclosures_active ON matters.disclosures(active);
        
        -- Composite index for common queries
        CREATE INDEX idx_disclosures_credential_project ON matters.disclosures(credential_id, project_id);
    END IF;
END $$;

-- Add updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_matters_disclosures_updated_at'
    ) THEN
        CREATE TRIGGER update_matters_disclosures_updated_at
        BEFORE UPDATE ON matters.disclosures
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE matters.disclosures ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Customer role: Can view disclosures (will be filtered by their access to projects)
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'disclosures'
        AND policyname = 'disclosures_customer_select_policy'
    ) THEN
        CREATE POLICY disclosures_customer_select_policy ON matters.disclosures
        FOR SELECT TO customer
        USING (TRUE);
    END IF;
END $$;

-- Staff role: Can view and manage all disclosures
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'disclosures'
        AND policyname = 'disclosures_staff_select_policy'
    ) THEN
        CREATE POLICY disclosures_staff_select_policy ON matters.disclosures
        FOR SELECT TO staff
        USING (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'disclosures'
        AND policyname = 'disclosures_staff_insert_policy'
    ) THEN
        CREATE POLICY disclosures_staff_insert_policy ON matters.disclosures
        FOR INSERT TO staff
        WITH CHECK (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'disclosures'
        AND policyname = 'disclosures_staff_update_policy'
    ) THEN
        CREATE POLICY disclosures_staff_update_policy ON matters.disclosures
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
        AND tablename = 'disclosures'
        AND policyname = 'disclosures_admin_all_policy'
    ) THEN
        CREATE POLICY disclosures_admin_all_policy ON matters.disclosures
        FOR ALL TO admin
        USING (TRUE)
        WITH CHECK (TRUE);
    END IF;
END $$;

-- Grant permissions to roles
GRANT SELECT ON matters.disclosures TO customer;
GRANT SELECT, INSERT, UPDATE ON matters.disclosures TO staff;
GRANT ALL ON matters.disclosures TO admin;

-- Add comments for documentation
COMMENT ON TABLE matters.disclosures IS 'Join table between legal credentials and projects tracking disclosure periods';
COMMENT ON COLUMN matters.disclosures.id IS 'Unique identifier for the disclosure record';
COMMENT ON COLUMN matters.disclosures.credential_id IS 'Foreign key reference to the legal credential being disclosed';
COMMENT ON COLUMN matters.disclosures.project_id IS 'Foreign key reference to the project where the disclosure applies';
COMMENT ON COLUMN matters.disclosures.disclosed_at IS 'Date when the disclosure period begins';
COMMENT ON COLUMN matters.disclosures.end_disclosed_at IS 'Date when the disclosure period ends (optional)';
COMMENT ON COLUMN matters.disclosures.active IS 'Boolean flag indicating if the disclosure is currently active';
COMMENT ON COLUMN matters.disclosures.created_at IS 'Timestamp when the disclosure record was created';
COMMENT ON COLUMN matters.disclosures.updated_at IS 'Timestamp when the disclosure record was last updated';
