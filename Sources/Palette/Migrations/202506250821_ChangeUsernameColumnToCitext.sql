-- Migrate auth.users.username column from VARCHAR to CITEXT for case-insensitive comparisons
DO $$
BEGIN
    -- Create citext extension if it doesn't exist
    CREATE EXTENSION IF NOT EXISTS citext;

    -- Check if username column exists and is not already CITEXT
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'auth'
        AND table_name = 'users'
        AND column_name = 'username'
        AND data_type != 'citext'
    ) THEN
        -- Drop policies that depend on the username column
        BEGIN
            DROP POLICY IF EXISTS customer_can_see_own_user ON auth.users;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            DROP POLICY IF EXISTS admin_can_see_all_users ON auth.users;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            DROP POLICY IF EXISTS staff_can_see_all_users ON auth.users;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        -- Drop the existing unique constraint on username
        ALTER TABLE auth.users DROP CONSTRAINT IF EXISTS users_username_key;

        -- Change the column type to CITEXT
        ALTER TABLE auth.users ALTER COLUMN username TYPE CITEXT;

        -- Re-add the unique constraint
        ALTER TABLE auth.users ADD CONSTRAINT users_username_key UNIQUE (username);

        -- Recreate the policies
        BEGIN
            CREATE POLICY customer_can_see_own_user ON auth.users
            FOR SELECT TO customer
            USING (username = current_user);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;

        BEGIN
            CREATE POLICY admin_can_see_all_users ON auth.users
            FOR ALL TO admin
            USING (true);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;

        BEGIN
            CREATE POLICY staff_can_see_all_users ON auth.users
            FOR SELECT TO staff
            USING (true);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;

        -- Add comment explaining the change
        COMMENT ON COLUMN auth.users.username IS
            'Case-insensitive username for authentication. Uses CITEXT type for case-insensitive comparisons.';
    END IF;
END $$;
