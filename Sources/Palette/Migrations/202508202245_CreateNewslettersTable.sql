-- Create the marketing.newsletters table for storing sent newsletters
DO $$
BEGIN
    -- Create the newsletters table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'marketing'
        AND table_name = 'newsletters'
    ) THEN
        CREATE TABLE marketing.newsletters (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT NOT NULL,
            subject_line TEXT NOT NULL,
            markdown_content TEXT NOT NULL,
            sent_at TIMESTAMP WITH TIME ZONE,
            recipient_count INTEGER DEFAULT 0,
            created_by UUID NOT NULL REFERENCES auth.users(id),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
        );

        COMMENT ON TABLE marketing.newsletters IS 'Table storing newsletter content and metadata';
        COMMENT ON COLUMN marketing.newsletters.id IS 'Unique identifier for the newsletter';
        COMMENT ON COLUMN marketing.newsletters.name IS 'Newsletter type/name (nv-sci-tech, sagebrush, neon-law)';
        COMMENT ON COLUMN marketing.newsletters.subject_line IS 'Email subject line for the newsletter';
        COMMENT ON COLUMN marketing.newsletters.markdown_content IS 'Newsletter content in markdown format (immutable after send)';
        COMMENT ON COLUMN marketing.newsletters.sent_at IS 'Timestamp when the newsletter was sent (null if draft)';
        COMMENT ON COLUMN marketing.newsletters.recipient_count IS 'Number of recipients the newsletter was sent to';
        COMMENT ON COLUMN marketing.newsletters.created_by IS 'Admin user who created the newsletter';
        COMMENT ON COLUMN marketing.newsletters.created_at IS 'Timestamp when the newsletter was created';
        COMMENT ON COLUMN marketing.newsletters.updated_at IS 'Timestamp when the newsletter was last updated';

        -- Add constraint for newsletter name enum values
        ALTER TABLE marketing.newsletters
        ADD CONSTRAINT newsletters_name_check
        CHECK (name IN ('nv-sci-tech', 'sagebrush', 'neon-law'));

        -- Add constraint to ensure recipient_count is non-negative
        ALTER TABLE marketing.newsletters
        ADD CONSTRAINT newsletters_recipient_count_check
        CHECK (recipient_count >= 0);

        -- Add constraint to ensure subject_line has reasonable length
        ALTER TABLE marketing.newsletters
        ADD CONSTRAINT newsletters_subject_line_length
        CHECK (char_length(subject_line) > 0 AND char_length(subject_line) <= 200);

        -- Create indexes for query performance
        CREATE INDEX idx_newsletters_sent_at ON marketing.newsletters(sent_at);
        CREATE INDEX idx_newsletters_name ON marketing.newsletters(name);
        CREATE INDEX idx_newsletters_created_by ON marketing.newsletters(created_by);

        -- Create trigger to update updated_at timestamp
        CREATE TRIGGER update_newsletters_updated_at
            BEFORE UPDATE ON marketing.newsletters
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();

        -- Row-level security
        ALTER TABLE marketing.newsletters ENABLE ROW LEVEL SECURITY;

        -- Admin users can do everything
        CREATE POLICY newsletters_admin_policy ON marketing.newsletters
            FOR ALL
            TO admin
            USING (true)
            WITH CHECK (true);

        -- Staff can view newsletters
        CREATE POLICY newsletters_staff_read_policy ON marketing.newsletters
            FOR SELECT
            TO staff
            USING (true);

        -- Customers can view sent newsletters (public content)
        CREATE POLICY newsletters_customer_read_policy ON marketing.newsletters
            FOR SELECT
            TO customer
            USING (sent_at IS NOT NULL);

        -- Grant table permissions
        GRANT SELECT ON marketing.newsletters TO customer;
        GRANT SELECT ON marketing.newsletters TO staff;
        GRANT ALL ON marketing.newsletters TO admin;
    END IF;
END $$;
