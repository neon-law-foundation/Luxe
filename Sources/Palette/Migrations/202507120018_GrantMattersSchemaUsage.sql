-- Grant USAGE permissions on matters schema to all roles
-- This ensures that users can access tables within the matters schema

-- Grant schema usage permissions
GRANT USAGE ON SCHEMA matters TO customer;
GRANT USAGE ON SCHEMA matters TO staff;
GRANT USAGE ON SCHEMA matters TO admin;

-- Add comment for documentation
COMMENT ON SCHEMA matters IS 'Schema for legal matters including projects, assigned notations, and disclosures';
