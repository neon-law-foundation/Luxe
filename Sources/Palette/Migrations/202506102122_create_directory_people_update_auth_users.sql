-- Create directory.people table and update auth.users table

-- Enable citext extension for case-insensitive text fields
CREATE EXTENSION IF NOT EXISTS citext;

-- Create directory.people table with name, email, and timestamps
CREATE TABLE IF NOT EXISTS directory.people (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email CITEXT NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp
);

-- Add table comment
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'directory' AND table_name = 'people') THEN
        COMMENT ON TABLE directory.people IS 'Directory of people with their basic contact information';
    END IF;
END $$;

-- Add column comments
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'directory' AND table_name = 'people' AND column_name = 'id') THEN
        COMMENT ON COLUMN directory.people.id IS 'Unique identifier for the person (UUIDv4)';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'directory' AND table_name = 'people' AND column_name = 'name') THEN
        COMMENT ON COLUMN directory.people.name IS 'Full name of the person';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'directory' AND table_name = 'people' AND column_name = 'email') THEN
        COMMENT ON COLUMN directory.people.email IS 'Email address of the person (case insensitive)';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'directory' AND table_name = 'people' AND column_name = 'created_at') THEN
        COMMENT ON COLUMN directory.people.created_at IS 'Timestamp when the person record was created';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'directory' AND table_name = 'people' AND column_name = 'updated_at') THEN
        COMMENT ON COLUMN directory.people.updated_at IS 'Timestamp when the person record was last updated';
    END IF;
END $$;

-- Create trigger to automatically update updated_at on row updates for directory.people
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_people_updated_at'
    ) THEN
        CREATE TRIGGER update_people_updated_at
        BEFORE UPDATE ON directory.people
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Modify auth.users table: change email column to username and add person_id
DO $$ BEGIN
    -- First, add the new username column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'username'
    ) THEN
        ALTER TABLE auth.users ADD COLUMN username VARCHAR(255);
    END IF;

    -- Copy email values to username column
    IF EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'email'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'username'
    ) THEN
        UPDATE auth.users SET username = email WHERE username IS NULL;
    END IF;

    -- Make username NOT NULL and UNIQUE
    IF EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'username'
    ) THEN
        ALTER TABLE auth.users ALTER COLUMN username SET NOT NULL;
        
        -- Add unique constraint if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints WHERE table_schema = 'auth' AND table_name = 'users' AND constraint_name = 'users_username_key'
        ) THEN
            ALTER TABLE auth.users ADD CONSTRAINT users_username_key UNIQUE (username);
        END IF;
    END IF;

    -- Drop the email column
    IF EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'email'
    ) THEN
        ALTER TABLE auth.users DROP COLUMN email;
    END IF;

    -- Add person_id column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'person_id'
    ) THEN
        ALTER TABLE auth.users ADD COLUMN person_id UUID;
    END IF;

    -- Add foreign key constraint to directory.people
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints WHERE table_schema = 'auth' AND table_name = 'users' AND constraint_name = 'fk_users_person_id'
    ) THEN
        ALTER TABLE auth.users ADD CONSTRAINT fk_users_person_id FOREIGN KEY (person_id) REFERENCES directory.people(id);
    END IF;
END $$;

-- Add column comments for new auth.users columns
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'username') THEN
        COMMENT ON COLUMN auth.users.username IS 'Username for authentication, must be unique';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'person_id') THEN
        COMMENT ON COLUMN auth.users.person_id IS 'Reference to the person record in directory.people';
    END IF;
END $$;

-- Create index on person_id for efficient lookups
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = 'idx_users_person_id' AND n.nspname = 'auth'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_users_person_id ON auth.users (person_id);
    END IF;
END $$;

-- Grant permissions for directory.people table
GRANT USAGE ON SCHEMA directory TO customer;
GRANT USAGE ON SCHEMA directory TO staff;
GRANT USAGE ON SCHEMA directory TO admin;

GRANT SELECT ON directory.people TO customer;
GRANT SELECT ON directory.people TO staff;
GRANT SELECT ON directory.people TO admin;

GRANT INSERT, UPDATE ON directory.people TO staff;
GRANT INSERT, UPDATE, DELETE ON directory.people TO admin;
