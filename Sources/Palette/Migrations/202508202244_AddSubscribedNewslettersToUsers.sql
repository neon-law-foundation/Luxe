-- Add subscribed_newsletters JSON column to auth.users table for newsletter preferences
DO $$
BEGIN
    -- Add subscribed_newsletters column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'auth'
        AND table_name = 'users'
        AND column_name = 'subscribed_newsletters'
    ) THEN
        ALTER TABLE auth.users
        ADD COLUMN subscribed_newsletters JSONB DEFAULT '{}'::jsonb NOT NULL;

        COMMENT ON COLUMN auth.users.subscribed_newsletters IS 'JSON object containing newsletter subscription preferences (e.g., {"sci_tech": true})';

        -- Add check constraint to ensure the JSON structure is valid
        ALTER TABLE auth.users
        ADD CONSTRAINT subscribed_newsletters_valid_structure
        CHECK (jsonb_typeof(subscribed_newsletters) = 'object');

        -- Create index for efficient queries on newsletter subscriptions
        CREATE INDEX idx_users_subscribed_newsletters_sci_tech
        ON auth.users ((subscribed_newsletters->>'sci_tech'))
        WHERE subscribed_newsletters->>'sci_tech' IS NOT NULL;
    END IF;
END $$;
