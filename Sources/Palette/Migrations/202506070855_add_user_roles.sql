-- Create user role enum type
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.user_role AS ENUM ('customer', 'staff', 'admin');
    END IF;
END $$;

-- Add role column to auth.users table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'role'
    ) THEN
        ALTER TABLE auth.users ADD COLUMN role auth.user_role NOT NULL DEFAULT 'customer';
    END IF;
END $$;

-- Add check constraint to ensure role is one of the allowed values
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints WHERE table_schema = 'auth' AND table_name = 'users' AND constraint_name = 'check_user_role'
    ) THEN
        ALTER TABLE auth.users ADD CONSTRAINT check_user_role CHECK (role IN ('customer', 'staff', 'admin'));
    END IF;
END $$;

-- Add column comment
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'role') THEN
        COMMENT ON COLUMN auth.users.role IS 'User role determining access level and permissions';
    END IF;
END $$;

-- Create index on role column for efficient queries
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = 'idx_users_role' AND n.nspname = 'auth'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_users_role ON auth.users (role);
    END IF;
END $$;

-- Create PostgreSQL roles for row level security (ignore errors if roles already exist)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'customer') THEN
        CREATE ROLE customer;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'staff') THEN
        CREATE ROLE staff;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin') THEN
        CREATE ROLE admin;
    END IF;
END $$;

-- Grant basic connection privileges to all roles
GRANT CONNECT ON DATABASE luxe TO customer;
GRANT CONNECT ON DATABASE luxe TO staff;
GRANT CONNECT ON DATABASE luxe TO admin;

-- Grant usage on auth schema to all roles
GRANT USAGE ON SCHEMA auth TO customer;
GRANT USAGE ON SCHEMA auth TO staff;
GRANT USAGE ON SCHEMA auth TO admin;

-- Grant select access to users table for all roles (they'll be restricted by RLS)
GRANT SELECT ON auth.users TO customer;
GRANT SELECT ON auth.users TO staff;
GRANT SELECT ON auth.users TO admin;

-- Grant additional privileges for higher-level roles
GRANT INSERT, UPDATE ON auth.users TO staff;
GRANT INSERT, UPDATE, DELETE ON auth.users TO admin;
