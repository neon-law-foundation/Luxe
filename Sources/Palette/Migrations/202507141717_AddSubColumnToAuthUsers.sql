-- Add sub column to auth.users table for storing Cognito sub IDs
-- This allows us to properly map Cognito users to our application users

DO $$
BEGIN
    -- Add the sub column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'auth' 
        AND table_name = 'users' 
        AND column_name = 'sub'
    ) THEN
        -- Add sub column - nullable but unique when not null
        ALTER TABLE auth.users 
        ADD COLUMN sub VARCHAR(255) NULL;
        
        -- Add unique constraint on sub column (allows multiple NULLs)
        ALTER TABLE auth.users 
        ADD CONSTRAINT auth_users_sub_unique UNIQUE (sub);
        
        -- Add comment to explain the purpose
        COMMENT ON COLUMN auth.users.sub IS 'Cognito subject ID for mapping external identity providers';
        
        RAISE NOTICE 'Added sub column to auth.users table with unique constraint';
    ELSE
        RAISE NOTICE 'Sub column already exists in auth.users table';
    END IF;
END $$;

-- Add index for performance when looking up by sub (outside the function)
CREATE INDEX IF NOT EXISTS idx_auth_users_sub
ON auth.users (sub)
WHERE sub IS NOT NULL;
