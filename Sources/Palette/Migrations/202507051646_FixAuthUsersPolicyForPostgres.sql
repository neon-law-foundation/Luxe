-- Migration: Fix Auth Users Policy For Postgres
-- Description: Add RLS policy to allow postgres user to access auth.users table for authentication
-- Created: 2025-07-05

DO $$
BEGIN
    -- Add policy to allow postgres user to access auth.users table for authentication purposes
    -- This is needed for SessionMiddleware to validate user sessions
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'auth' 
        AND tablename = 'users' 
        AND policyname = 'postgres_can_authenticate_users'
    ) THEN
        CREATE POLICY postgres_can_authenticate_users ON auth.users
            FOR SELECT TO postgres
            USING (true);
        
        COMMENT ON POLICY postgres_can_authenticate_users ON auth.users IS
            'Allows postgres user to query auth.users table for authentication purposes in SessionMiddleware';
    END IF;
END $$;
