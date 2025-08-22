-- Create person_entity_roles table in auth schema
-- This table establishes relationships between people and entities with specific roles

-- Create enum type for person entity roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'person_entity_role_type') THEN
        CREATE TYPE auth.person_entity_role_type AS ENUM ('owner', 'admin', 'staff');
        COMMENT ON TYPE auth.person_entity_role_type IS
            'Role types for person-entity relationships: owner (full control), admin (management access), staff (limited access)';
    END IF;
END $$;

-- Create the person_entity_roles table
CREATE TABLE IF NOT EXISTS auth.person_entity_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID NOT NULL REFERENCES directory.people (id) ON DELETE CASCADE,
    entity_id UUID NOT NULL REFERENCES directory.entities (id) ON DELETE CASCADE,
    role auth.PERSON_ENTITY_ROLE_TYPE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,

    -- Ensure a person can only have one role per entity
    CONSTRAINT unique_person_entity_role UNIQUE (person_id, entity_id)
);

-- Add table and column comments
COMMENT ON TABLE auth.person_entity_roles IS
'Defines role-based relationships between people and legal entities for authorization purposes';
COMMENT ON COLUMN auth.person_entity_roles.id IS
'Unique identifier for the person-entity role relationship';
COMMENT ON COLUMN auth.person_entity_roles.person_id IS
'Reference to the person in the directory.people table';
COMMENT ON COLUMN auth.person_entity_roles.entity_id IS
'Reference to the entity in the directory.entities table';
COMMENT ON COLUMN auth.person_entity_roles.role IS
'Role type: owner (full control), admin (management), or staff (limited access)';
COMMENT ON COLUMN auth.person_entity_roles.created_at IS
'Timestamp when the role relationship was created';
COMMENT ON COLUMN auth.person_entity_roles.updated_at IS
'Timestamp when the role relationship was last updated';

-- Create updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_person_entity_roles_updated_at'
    ) THEN
        CREATE TRIGGER update_person_entity_roles_updated_at
        BEFORE UPDATE ON auth.person_entity_roles
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_person_entity_roles_person_id
ON auth.person_entity_roles (person_id);
CREATE INDEX IF NOT EXISTS idx_person_entity_roles_entity_id
ON auth.person_entity_roles (entity_id);
CREATE INDEX IF NOT EXISTS idx_person_entity_roles_role
ON auth.person_entity_roles (role);

-- Enable row-level security
ALTER TABLE auth.person_entity_roles ENABLE ROW LEVEL SECURITY;

-- Create policies for row-level security
-- Policy for customer role: can only read their own role relationships
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'person_entity_roles_customer_read'
    ) THEN
        CREATE POLICY person_entity_roles_customer_read ON auth.person_entity_roles
        FOR SELECT
        TO customer
        USING (true);
    END IF;
END $$;

-- Policy for staff role: can read all role relationships
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'person_entity_roles_staff_read'
    ) THEN
        CREATE POLICY person_entity_roles_staff_read ON auth.person_entity_roles
        FOR SELECT
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for admin role: full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'person_entity_roles_admin_all'
    ) THEN
        CREATE POLICY person_entity_roles_admin_all ON auth.person_entity_roles
        FOR ALL
        TO admin
        USING (true);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON auth.person_entity_roles TO customer;
GRANT SELECT ON auth.person_entity_roles TO staff;
GRANT ALL ON auth.person_entity_roles TO admin;
