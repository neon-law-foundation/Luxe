-- Create create_person_and_user function for admin user creation
-- This function creates both a person and user record atomically with proper authorization checks

-- Create admin schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS admin;

-- Grant usage on admin schema to admin role
GRANT USAGE ON SCHEMA admin TO admin;

-- First, enable RLS on both tables if not already enabled
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c 
        JOIN pg_namespace n ON n.oid = c.relnamespace 
        WHERE c.relname = 'people' AND n.nspname = 'directory' AND c.relrowsecurity = true
    ) THEN
        ALTER TABLE directory.people ENABLE ROW LEVEL SECURITY;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c 
        JOIN pg_namespace n ON n.oid = c.relnamespace 
        WHERE c.relname = 'users' AND n.nspname = 'auth' AND c.relrowsecurity = true
    ) THEN
        ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

-- Create RLS policies for directory.people table
DO $$ BEGIN
    -- Admin can see all people
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'directory' AND tablename = 'people' AND policyname = 'admin_can_see_all_people'
    ) THEN
        CREATE POLICY admin_can_see_all_people ON directory.people FOR SELECT TO admin USING (true);
    END IF;
    
    -- Staff can see all people
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'directory' AND tablename = 'people' AND policyname = 'staff_can_see_all_people'
    ) THEN
        CREATE POLICY staff_can_see_all_people ON directory.people FOR SELECT TO staff USING (true);
    END IF;
    
    -- Customers can only see their own person record
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'directory' AND tablename = 'people' AND policyname = 'customer_can_see_own_person'
    ) THEN
        CREATE POLICY customer_can_see_own_person ON directory.people FOR SELECT TO customer 
        USING (email = current_setting('app.current_user_email', true));
    END IF;
    
    -- Only admin can insert people
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'directory' AND tablename = 'people' AND policyname = 'admin_can_insert_people'
    ) THEN
        CREATE POLICY admin_can_insert_people ON directory.people FOR INSERT TO admin WITH CHECK (true);
    END IF;
    
    -- Only admin can update people
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'directory' AND tablename = 'people' AND policyname = 'admin_can_update_people'
    ) THEN
        CREATE POLICY admin_can_update_people ON directory.people FOR UPDATE TO admin USING (true) WITH CHECK (true);
    END IF;
    
    -- Only admin can delete people
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'directory' AND tablename = 'people' AND policyname = 'admin_can_delete_people'
    ) THEN
        CREATE POLICY admin_can_delete_people ON directory.people FOR DELETE TO admin USING (true);
    END IF;
END $$;

-- Create RLS policies for auth.users table
DO $$ BEGIN
    -- Admin can see all users
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'auth' AND tablename = 'users' AND policyname = 'admin_can_see_all_users'
    ) THEN
        CREATE POLICY admin_can_see_all_users ON auth.users FOR SELECT TO admin USING (true);
    END IF;
    
    -- Staff can see all users
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'auth' AND tablename = 'users' AND policyname = 'staff_can_see_all_users'
    ) THEN
        CREATE POLICY staff_can_see_all_users ON auth.users FOR SELECT TO staff USING (true);
    END IF;
    
    -- Customers can only see their own user record
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'auth' AND tablename = 'users' AND policyname = 'customer_can_see_own_user'
    ) THEN
        CREATE POLICY customer_can_see_own_user ON auth.users FOR SELECT TO customer 
        USING (username = current_setting('app.current_user_username', true));
    END IF;
    
    -- Only admin can insert users
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'auth' AND tablename = 'users' AND policyname = 'admin_can_insert_users'
    ) THEN
        CREATE POLICY admin_can_insert_users ON auth.users FOR INSERT TO admin WITH CHECK (true);
    END IF;
    
    -- Only admin can update users
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'auth' AND tablename = 'users' AND policyname = 'admin_can_update_users'
    ) THEN
        CREATE POLICY admin_can_update_users ON auth.users FOR UPDATE TO admin USING (true) WITH CHECK (true);
    END IF;
    
    -- Only admin can delete users
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'auth' AND tablename = 'users' AND policyname = 'admin_can_delete_users'
    ) THEN
        CREATE POLICY admin_can_delete_users ON auth.users FOR DELETE TO admin USING (true);
    END IF;
END $$;

-- Create the create_person_and_user function
CREATE OR REPLACE FUNCTION admin.create_person_and_user(
    p_name varchar(255),
    p_email citext,
    p_username varchar(255),
    p_role auth.user_role DEFAULT 'customer'
)
RETURNS TABLE (
    person_id uuid,
    user_id uuid,
    created_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_person_id uuid;
    v_user_id uuid;
    v_created_at timestamp with time zone;
BEGIN
    -- Check if the current user has admin role
    -- current_setting with true parameter returns empty string if not set
    IF COALESCE(NULLIF(current_setting('app.current_user_role', true), ''), 'none') != 'admin' THEN
        RAISE EXCEPTION 'Access denied: Only admin users can create new users and people';
    END IF;
    
    -- Validate input parameters
    IF p_name IS NULL OR LENGTH(TRIM(p_name)) = 0 THEN
        RAISE EXCEPTION 'Name cannot be empty';
    END IF;
    
    IF p_email IS NULL OR LENGTH(TRIM(p_email)) = 0 THEN
        RAISE EXCEPTION 'Email cannot be empty';
    END IF;
    
    IF p_username IS NULL OR LENGTH(TRIM(p_username)) = 0 THEN
        RAISE EXCEPTION 'Username cannot be empty';
    END IF;
    
    -- Check for email format validation
    IF p_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format';
    END IF;
    
    -- Check if person with this email already exists
    IF EXISTS (SELECT 1 FROM directory.people WHERE email = p_email) THEN
        RAISE EXCEPTION 'Person with email % already exists', p_email;
    END IF;
    
    -- Check if user with this username already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE username = p_username) THEN
        RAISE EXCEPTION 'User with username % already exists', p_username;
    END IF;
    
    -- Get current timestamp for consistency
    v_created_at := CURRENT_TIMESTAMP;
    
    -- Start transaction (function is already in a transaction)
    
    -- Create person record
    INSERT INTO directory.people (name, email, created_at, updated_at)
    VALUES (TRIM(p_name), LOWER(TRIM(p_email)), v_created_at, v_created_at)
    RETURNING id INTO v_person_id;
    
    -- Create user record with reference to person
    INSERT INTO auth.users (username, person_id, role, created_at, updated_at)
    VALUES (LOWER(TRIM(p_username)), v_person_id, p_role, v_created_at, v_created_at)
    RETURNING id INTO v_user_id;
    
    -- Return the created IDs and timestamp
    RETURN QUERY SELECT v_person_id, v_user_id, v_created_at;
END;
$$;

-- Add function comment
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_person_and_user' 
               AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'admin')) THEN
        COMMENT ON FUNCTION admin.create_person_and_user(varchar(255), citext, varchar(255), auth.user_role) IS 
        'Creates a person and user record atomically. Only accessible to admin users. Links person and user via email/username matching.';
    END IF;
END $$;

-- Grant execute permission only to admin role
GRANT EXECUTE ON FUNCTION admin.create_person_and_user(varchar(255), citext, varchar(255), auth.user_role) TO admin;

-- Revoke access from other roles
REVOKE EXECUTE ON FUNCTION admin.create_person_and_user(varchar(255), citext, varchar(255), auth.user_role) FROM public;
REVOKE EXECUTE ON FUNCTION admin.create_person_and_user(varchar(255), citext, varchar(255), auth.user_role)
FROM customer;
REVOKE EXECUTE ON FUNCTION admin.create_person_and_user(varchar(255), citext, varchar(255), auth.user_role)
FROM staff;
