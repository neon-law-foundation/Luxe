-- Create the marketing.newsletter_templates table for storing reusable newsletter templates
DO $$
BEGIN
    -- Create the newsletter_templates table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'marketing'
        AND table_name = 'newsletter_templates'
    ) THEN
        CREATE TABLE marketing.newsletter_templates (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            template_content TEXT NOT NULL,
            category TEXT DEFAULT 'general',
            is_active BOOLEAN DEFAULT true,
            created_by UUID NOT NULL REFERENCES auth.users(id),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
        );

        COMMENT ON TABLE marketing.newsletter_templates IS 'Reusable newsletter templates for consistent formatting';
        COMMENT ON COLUMN marketing.newsletter_templates.id IS 'Unique identifier for the template';
        COMMENT ON COLUMN marketing.newsletter_templates.name IS 'Template name for identification';
        COMMENT ON COLUMN marketing.newsletter_templates.description IS 'Description of template purpose and usage';
        COMMENT ON COLUMN marketing.newsletter_templates.template_content IS 'Markdown template with merge tag placeholders';
        COMMENT ON COLUMN marketing.newsletter_templates.category IS 'Template category for organization';
        COMMENT ON COLUMN marketing.newsletter_templates.is_active IS 'Whether template is available for use';
        COMMENT ON COLUMN marketing.newsletter_templates.created_by IS 'Admin user who created the template';
        COMMENT ON COLUMN marketing.newsletter_templates.created_at IS 'Timestamp when template was created';
        COMMENT ON COLUMN marketing.newsletter_templates.updated_at IS 'Timestamp when template was last updated';

        -- Add constraint for category enum values
        ALTER TABLE marketing.newsletter_templates
        ADD CONSTRAINT newsletter_templates_category_check
        CHECK (category IN ('general', 'announcement', 'update', 'newsletter'));

        -- Add constraint to ensure template_content is not empty
        ALTER TABLE marketing.newsletter_templates
        ADD CONSTRAINT newsletter_templates_content_check
        CHECK (char_length(template_content) > 10);

        -- Create indexes for query performance
        CREATE INDEX idx_newsletter_templates_category ON marketing.newsletter_templates(category);
        CREATE INDEX idx_newsletter_templates_is_active ON marketing.newsletter_templates(is_active);
        CREATE INDEX idx_newsletter_templates_created_by ON marketing.newsletter_templates(created_by);

        -- Create trigger to update updated_at timestamp
        CREATE TRIGGER update_newsletter_templates_updated_at
            BEFORE UPDATE ON marketing.newsletter_templates
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();

        -- Row-level security
        ALTER TABLE marketing.newsletter_templates ENABLE ROW LEVEL SECURITY;

        -- Admin users can do everything
        CREATE POLICY newsletter_templates_admin_policy ON marketing.newsletter_templates
            FOR ALL
            TO admin
            USING (true)
            WITH CHECK (true);

        -- Staff can view active templates
        CREATE POLICY newsletter_templates_staff_read_policy ON marketing.newsletter_templates
            FOR SELECT
            TO staff
            USING (is_active = true);

        -- Grant table permissions
        GRANT SELECT ON marketing.newsletter_templates TO staff;
        GRANT ALL ON marketing.newsletter_templates TO admin;
    END IF;
END $$;
