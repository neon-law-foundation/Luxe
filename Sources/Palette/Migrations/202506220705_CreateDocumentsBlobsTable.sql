-- Create documents.blobs table
-- This table stores references to files stored in object storage (AWS S3)
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'documents' AND table_name = 'blobs'
    ) THEN
        CREATE TABLE documents.blobs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            object_storage_url TEXT NOT NULL,
            referenced_by TEXT NOT NULL CHECK (referenced_by IN ('letters')),
            referenced_by_id UUID NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
            CONSTRAINT unique_blob_reference UNIQUE (referenced_by, referenced_by_id)
        );
    END IF;
END $$;

-- Add comments
COMMENT ON TABLE documents.blobs IS 'Stores references to files in object storage (AWS S3)';
COMMENT ON COLUMN documents.blobs.id IS 'Unique identifier for the blob reference';
COMMENT ON COLUMN documents.blobs.object_storage_url IS 'URL or URI to the file in AWS S3';
COMMENT ON COLUMN documents.blobs.referenced_by IS 'Type of entity referencing this blob (currently only letters)';
COMMENT ON COLUMN documents.blobs.referenced_by_id IS 'UUID of the entity referencing this blob';
COMMENT ON COLUMN documents.blobs.created_at IS 'Timestamp when the blob reference was created';
COMMENT ON COLUMN documents.blobs.updated_at IS 'Timestamp when the blob reference was last updated';

-- Create updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_documents_blobs_updated_at'
    ) THEN
        CREATE TRIGGER update_documents_blobs_updated_at 
        BEFORE UPDATE ON documents.blobs
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_blobs_referenced ON documents.blobs (referenced_by, referenced_by_id);
CREATE INDEX IF NOT EXISTS idx_blobs_created_at ON documents.blobs (created_at);

-- Row-level security
ALTER TABLE documents.blobs ENABLE ROW LEVEL SECURITY;

-- Policy for customer role: can only read blobs they have access to
-- This will need to be refined once we have the mail.letters table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'blobs_customer_read' AND polrelid = 'documents.blobs'::regclass
    ) THEN
        CREATE POLICY blobs_customer_read ON documents.blobs
        FOR SELECT
        TO customer
        USING (true); -- Will be updated to check ownership through referenced tables
    END IF;
END $$;

-- Policy for staff role: can read all blobs
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'blobs_staff_read' AND polrelid = 'documents.blobs'::regclass
    ) THEN
        CREATE POLICY blobs_staff_read ON documents.blobs
        FOR SELECT
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for staff role: can insert new blobs
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'blobs_staff_insert' AND polrelid = 'documents.blobs'::regclass
    ) THEN
        CREATE POLICY blobs_staff_insert ON documents.blobs
        FOR INSERT
        TO staff
        WITH CHECK (true);
    END IF;
END $$;

-- Policy for staff role: can update existing blobs
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'blobs_staff_update' AND polrelid = 'documents.blobs'::regclass
    ) THEN
        CREATE POLICY blobs_staff_update ON documents.blobs
        FOR UPDATE
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for admin role: full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'blobs_admin_all' AND polrelid = 'documents.blobs'::regclass
    ) THEN
        CREATE POLICY blobs_admin_all ON documents.blobs
        FOR ALL
        TO admin
        USING (true);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON documents.blobs TO customer;
GRANT SELECT, INSERT, UPDATE ON documents.blobs TO staff;
GRANT ALL ON documents.blobs TO admin;
