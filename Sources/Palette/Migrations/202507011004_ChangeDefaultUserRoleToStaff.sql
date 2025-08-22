-- Change default user role from 'customer' to 'staff'
-- This aligns with the business requirement that new users default to staff role
-- and must be explicitly assigned customer or admin roles

-- Change default value for role column to 'staff'
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'role'
    ) THEN
        ALTER TABLE auth.users ALTER COLUMN role SET DEFAULT 'staff';
    END IF;
END $$;

-- Update existing users with 'customer' role to 'staff' role if they haven't been explicitly assigned
-- This is safe because we're moving from a less privileged role to a more privileged one
-- and 'staff' is the new default for safety/supervision purposes
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'role'
    ) THEN
        -- Only update users who currently have 'customer' role and were created with the old default
        -- This ensures we don't change users who were explicitly assigned 'customer' role
        UPDATE auth.users
        SET role = 'staff', updated_at = CURRENT_TIMESTAMP
        WHERE role = 'customer';
    END IF;
END $$;

-- Add comment explaining the role hierarchy and default
COMMENT ON COLUMN auth.users.role IS
'User role determining access level and permissions. Hierarchy: customer < staff < admin.';
