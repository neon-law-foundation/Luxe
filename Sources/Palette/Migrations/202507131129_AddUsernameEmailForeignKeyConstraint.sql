-- Add foreign key constraint to ensure auth.users.username corresponds to directory.people.email
-- This ensures that every username in auth.users table must have a matching email in directory.people table
-- This enforces referential integrity between authentication users and directory people records

DO $$
BEGIN
    -- First verify data consistency before adding constraint
    -- Check if there are any auth.users records without corresponding directory.people.email
    IF EXISTS (
        SELECT 1 FROM auth.users u
        LEFT JOIN directory.people p ON u.username = p.email
        WHERE p.email IS NULL
    ) THEN
        RAISE EXCEPTION 'Cannot add foreign key constraint: Found auth.users records without corresponding directory.people.email records';
    END IF;

    -- Add foreign key constraint from auth.users.username to directory.people.email
    -- This constraint ensures that every username must reference a valid person email
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_schema = 'auth'
        AND table_name = 'users'
        AND constraint_name = 'fk_auth_users_username_directory_people_email'
    ) THEN
        ALTER TABLE auth.users
        ADD CONSTRAINT fk_auth_users_username_directory_people_email
        FOREIGN KEY (username) REFERENCES directory.people(email);
    END IF;

    -- Add constraint comment
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_schema = 'auth'
        AND table_name = 'users'
        AND constraint_name = 'fk_auth_users_username_directory_people_email'
    ) THEN
        COMMENT ON CONSTRAINT fk_auth_users_username_directory_people_email ON auth.users IS
        'Ensures that auth.users.username must correspond to a valid directory.people.email record. This enforces referential integrity between authentication and directory systems.';
    END IF;

    -- Update table comment to reflect the new constraint
    COMMENT ON TABLE auth.users IS
    'Authentication users table | Protected: admin@neonlaw.com cannot be deleted | Constraint: username must reference directory.people.email';

    -- Update column comment to reflect the foreign key relationship
    COMMENT ON COLUMN auth.users.username IS
    'Username for authentication (email format). Uses CITEXT type for case-insensitive comparisons. Must correspond to a valid directory.people.email record.';

END $$;
