-- CreateRelationshipLogsTable Migration
-- This migration creates the matters.relationship_logs table to track relationship logs
-- for legal matters with foreign keys to projects and legal credentials.

DO $$ BEGIN
    -- Create the matters.relationship_logs table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'matters'
        AND table_name = 'relationship_logs'
    ) THEN
        CREATE TABLE matters.relationship_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            project_id UUID NOT NULL,
            credential_id UUID NOT NULL,
            body TEXT NOT NULL,
            relationships JSONB NOT NULL DEFAULT '{}',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,

            CONSTRAINT fk_relationship_logs_project
                FOREIGN KEY (project_id) REFERENCES matters.projects(id) ON DELETE CASCADE,

            CONSTRAINT fk_relationship_logs_credential
                FOREIGN KEY (credential_id) REFERENCES legal.credentials(id) ON DELETE CASCADE
        );

        -- Add updated_at trigger
        CREATE TRIGGER trigger_update_relationship_logs_updated_at
            BEFORE UPDATE ON matters.relationship_logs
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();

        -- Enable Row Level Security
        ALTER TABLE matters.relationship_logs ENABLE ROW LEVEL SECURITY;

        -- Create basic RLS policies
        CREATE POLICY admin_full_access ON matters.relationship_logs
            FOR ALL TO admin USING (true) WITH CHECK (true);

        CREATE POLICY staff_full_access ON matters.relationship_logs
            FOR ALL TO staff USING (true) WITH CHECK (true);

        CREATE POLICY customer_read_policy ON matters.relationship_logs
            FOR SELECT TO customer USING (true);

        -- Grant permissions
        GRANT SELECT ON matters.relationship_logs TO customer;
        GRANT SELECT, INSERT, UPDATE, DELETE ON matters.relationship_logs TO staff;
        GRANT SELECT, INSERT, UPDATE, DELETE ON matters.relationship_logs TO admin;
    END IF;
END $$;
