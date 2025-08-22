-- Grant USAGE permissions on all custom schemas to all database roles
-- This ensures that when roles are switched via PostgresRoleMiddleware,
-- the search path can access tables in all schemas

DO $$ BEGIN
    -- Grant usage on all custom schemas to customer role
    GRANT USAGE ON SCHEMA auth TO customer;
    GRANT USAGE ON SCHEMA directory TO customer;
    GRANT USAGE ON SCHEMA mail TO customer;
    GRANT USAGE ON SCHEMA accounting TO customer;
    GRANT USAGE ON SCHEMA equity TO customer;
    GRANT USAGE ON SCHEMA estates TO customer;
    GRANT USAGE ON SCHEMA standards TO customer;
    GRANT USAGE ON SCHEMA legal TO customer;
    GRANT USAGE ON SCHEMA matters TO customer;
    GRANT USAGE ON SCHEMA documents TO customer;
    GRANT USAGE ON SCHEMA service TO customer;
    GRANT USAGE ON SCHEMA admin TO customer;

    -- Grant usage on all custom schemas to staff role  
    GRANT USAGE ON SCHEMA auth TO staff;
    GRANT USAGE ON SCHEMA directory TO staff;
    GRANT USAGE ON SCHEMA mail TO staff;
    GRANT USAGE ON SCHEMA accounting TO staff;
    GRANT USAGE ON SCHEMA equity TO staff;
    GRANT USAGE ON SCHEMA estates TO staff;
    GRANT USAGE ON SCHEMA standards TO staff;
    GRANT USAGE ON SCHEMA legal TO staff;
    GRANT USAGE ON SCHEMA matters TO staff;
    GRANT USAGE ON SCHEMA documents TO staff;
    GRANT USAGE ON SCHEMA service TO staff;
    GRANT USAGE ON SCHEMA admin TO staff;

    -- Grant usage on all custom schemas to admin role
    GRANT USAGE ON SCHEMA auth TO admin;
    GRANT USAGE ON SCHEMA directory TO admin;
    GRANT USAGE ON SCHEMA mail TO admin;
    GRANT USAGE ON SCHEMA accounting TO admin;
    GRANT USAGE ON SCHEMA equity TO admin;
    GRANT USAGE ON SCHEMA estates TO admin;
    GRANT USAGE ON SCHEMA standards TO admin;
    GRANT USAGE ON SCHEMA legal TO admin;
    GRANT USAGE ON SCHEMA matters TO admin;
    GRANT USAGE ON SCHEMA documents TO admin;
    GRANT USAGE ON SCHEMA service TO admin;
    GRANT USAGE ON SCHEMA admin TO admin;
END $$;

-- Add comment about the purpose of this migration
COMMENT ON SCHEMA standards IS 'Standards schema with USAGE permissions for all roles';
