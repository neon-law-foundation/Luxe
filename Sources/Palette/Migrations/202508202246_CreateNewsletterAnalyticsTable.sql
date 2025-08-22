-- Create the marketing.newsletter_analytics table for tracking newsletter performance metrics
DO $$
BEGIN
    -- Create the newsletter_analytics table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'marketing'
        AND table_name = 'newsletter_analytics'
    ) THEN
        CREATE TABLE marketing.newsletter_analytics (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            newsletter_id UUID NOT NULL REFERENCES marketing.newsletters(id) ON DELETE CASCADE,
            user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
            event_type TEXT NOT NULL CHECK (event_type IN ('sent', 'opened', 'clicked', 'unsubscribed')),
            event_data JSONB,
            ip_address INET,
            user_agent TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
        );

        COMMENT ON TABLE marketing.newsletter_analytics IS 'Table for tracking newsletter engagement metrics and analytics';
        COMMENT ON COLUMN marketing.newsletter_analytics.id IS 'Unique identifier for the analytics event';
        COMMENT ON COLUMN marketing.newsletter_analytics.newsletter_id IS 'Reference to the newsletter being tracked';
        COMMENT ON COLUMN marketing.newsletter_analytics.user_id IS 'Reference to the user (null for anonymous events)';
        COMMENT ON COLUMN marketing.newsletter_analytics.event_type IS 'Type of event: sent, opened, clicked, unsubscribed';
        COMMENT ON COLUMN marketing.newsletter_analytics.event_data IS 'Additional event metadata in JSON format';
        COMMENT ON COLUMN marketing.newsletter_analytics.ip_address IS 'IP address of the user for the event';
        COMMENT ON COLUMN marketing.newsletter_analytics.user_agent IS 'User agent string for web-based events';
        COMMENT ON COLUMN marketing.newsletter_analytics.created_at IS 'Timestamp when the event occurred';

        -- Create indexes for query performance
        CREATE INDEX idx_newsletter_analytics_newsletter_id ON marketing.newsletter_analytics(newsletter_id);
        CREATE INDEX idx_newsletter_analytics_user_id ON marketing.newsletter_analytics(user_id);
        CREATE INDEX idx_newsletter_analytics_event_type ON marketing.newsletter_analytics(event_type);
        CREATE INDEX idx_newsletter_analytics_created_at ON marketing.newsletter_analytics(created_at);
        
        -- Composite index for common queries
        CREATE INDEX idx_newsletter_analytics_newsletter_event ON marketing.newsletter_analytics(newsletter_id, event_type);

        -- Row-level security
        ALTER TABLE marketing.newsletter_analytics ENABLE ROW LEVEL SECURITY;

        -- Admin users can do everything
        CREATE POLICY newsletter_analytics_admin_policy ON marketing.newsletter_analytics
            FOR ALL
            TO admin
            USING (true)
            WITH CHECK (true);

        -- Staff can view analytics
        CREATE POLICY newsletter_analytics_staff_read_policy ON marketing.newsletter_analytics
            FOR SELECT
            TO staff
            USING (true);

        -- Users can view analytics events (simplified policy for now)
        CREATE POLICY newsletter_analytics_user_policy ON marketing.newsletter_analytics
            FOR SELECT
            TO customer
            USING (true);

        -- Grant table permissions
        GRANT SELECT ON marketing.newsletter_analytics TO customer;
        GRANT SELECT ON marketing.newsletter_analytics TO staff;
        GRANT ALL ON marketing.newsletter_analytics TO admin;
    END IF;
END $$;
