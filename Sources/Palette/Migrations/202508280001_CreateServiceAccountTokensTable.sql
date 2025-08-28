-- Create the auth.service_account_tokens table for storing service account authentication tokens
DO $$
BEGIN
    -- Create the service_account_tokens table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'auth'
        AND table_name = 'service_account_tokens'
    ) THEN
        CREATE TABLE auth.service_account_tokens (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT NOT NULL,
            token_hash TEXT NOT NULL UNIQUE,
            service_type TEXT NOT NULL CHECK (service_type IN ('slack_bot', 'ci_cd', 'monitoring')),
            expires_at TIMESTAMP WITH TIME ZONE,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
            last_used_at TIMESTAMP WITH TIME ZONE
        );

        COMMENT ON TABLE auth.service_account_tokens IS 'Authentication tokens for service accounts and bots';
        COMMENT ON COLUMN auth.service_account_tokens.id IS 'Unique identifier for the service account token';
        COMMENT ON COLUMN auth.service_account_tokens.name IS 'Human-readable name for the service account';
        COMMENT ON COLUMN auth.service_account_tokens.token_hash IS 'SHA256 hash of the service account token';
        COMMENT ON COLUMN auth.service_account_tokens.service_type IS 'Type of service using this token';
        COMMENT ON COLUMN auth.service_account_tokens.expires_at IS 'Optional expiration timestamp for the token';
        COMMENT ON COLUMN auth.service_account_tokens.is_active IS 'Whether the token is currently active';
        COMMENT ON COLUMN auth.service_account_tokens.created_at IS 'Timestamp when token was created';
        COMMENT ON COLUMN auth.service_account_tokens.last_used_at IS 'Timestamp when token was last used for authentication';

        -- Create indexes for query performance
        CREATE INDEX idx_service_account_tokens_token_hash ON auth.service_account_tokens(token_hash);
        CREATE INDEX idx_service_account_tokens_service_type ON auth.service_account_tokens(service_type);
        CREATE INDEX idx_service_account_tokens_active ON auth.service_account_tokens(is_active) WHERE is_active = true;
        CREATE INDEX idx_service_account_tokens_expires_at ON auth.service_account_tokens(expires_at) WHERE expires_at IS NOT NULL;

        -- Row-level security
        ALTER TABLE auth.service_account_tokens ENABLE ROW LEVEL SECURITY;

        -- Admin users can do everything
        CREATE POLICY service_account_tokens_admin_policy ON auth.service_account_tokens
            FOR ALL
            TO admin
            USING (true)
            WITH CHECK (true);

        -- Staff can only view tokens (for debugging/monitoring purposes)
        CREATE POLICY service_account_tokens_staff_read_policy ON auth.service_account_tokens
            FOR SELECT
            TO staff
            USING (true);

        -- Grant table permissions
        GRANT SELECT ON auth.service_account_tokens TO staff;
        GRANT ALL ON auth.service_account_tokens TO admin;
    END IF;
END $$;
