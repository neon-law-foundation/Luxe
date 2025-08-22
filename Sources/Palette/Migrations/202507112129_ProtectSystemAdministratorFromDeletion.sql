-- Migration: Protect System Administrator From Deletion
-- Description: Add database-level protection to prevent deletion of admin@neonlaw.com user and person records
-- Created: 2025-07-11

-- Create function to prevent deletion of system administrator records
DO $$
BEGIN
    -- Create function to check and prevent deletion of admin@neonlaw.com
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname = 'prevent_system_admin_deletion' AND n.nspname = 'public'
    ) THEN
        CREATE OR REPLACE FUNCTION prevent_system_admin_deletion()
        RETURNS TRIGGER AS $trigger$
        BEGIN
            -- For auth.users table, check username
            IF TG_TABLE_NAME = 'users' AND TG_TABLE_SCHEMA = 'auth' THEN
                IF OLD.username = 'admin@neonlaw.com' THEN
                    RAISE EXCEPTION 'Cannot delete system administrator account: admin@neonlaw.com'
                        USING ERRCODE = 'P0001',
                              HINT = 'This user account is protected from deletion for system security.';
                END IF;
            END IF;

            -- For directory.people table, check email
            IF TG_TABLE_NAME = 'people' AND TG_TABLE_SCHEMA = 'directory' THEN
                IF OLD.email = 'admin@neonlaw.com' THEN
                    RAISE EXCEPTION 'Cannot delete system administrator person record: admin@neonlaw.com'
                        USING ERRCODE = 'P0001',
                              HINT = 'This person record is protected from deletion for system security.';
                END IF;
            END IF;

            RETURN OLD;
        END;
        $trigger$ LANGUAGE plpgsql;

        COMMENT ON FUNCTION prevent_system_admin_deletion() IS
            'Prevents deletion of system administrator (admin@neonlaw.com) from auth.users and directory.people';
    END IF;
END $$;

-- Create trigger on auth.users table to prevent deletion of admin@neonlaw.com user
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'prevent_admin_user_deletion'
    ) THEN
        CREATE TRIGGER prevent_admin_user_deletion
            BEFORE DELETE ON auth.users
            FOR EACH ROW
            EXECUTE FUNCTION prevent_system_admin_deletion();

        COMMENT ON TRIGGER prevent_admin_user_deletion ON auth.users IS
            'Prevents deletion of system administrator user account (admin@neonlaw.com)';
    END IF;
END $$;

-- Create trigger on directory.people table to prevent deletion of admin@neonlaw.com person
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'prevent_admin_person_deletion'
    ) THEN
        CREATE TRIGGER prevent_admin_person_deletion
            BEFORE DELETE ON directory.people
            FOR EACH ROW
            EXECUTE FUNCTION prevent_system_admin_deletion();

        COMMENT ON TRIGGER prevent_admin_person_deletion ON directory.people IS
            'Prevents deletion of system administrator person record (admin@neonlaw.com)';
    END IF;
END $$;

-- Add simple comments for documentation
COMMENT ON TABLE auth.users IS 'Authentication users table | Protected: admin@neonlaw.com cannot be deleted';
COMMENT ON TABLE directory.people IS
'Directory of people with their basic contact information | Protected: admin@neonlaw.com cannot be deleted';
