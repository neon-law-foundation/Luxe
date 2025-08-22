-- Create assigned_notations table in the matters schema
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'matters'
        AND tablename = 'assigned_notations'
    ) THEN
        CREATE TABLE matters.assigned_notations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            entity_id UUID NOT NULL,
            state VARCHAR(50) NOT NULL,
            change_language JSONB NOT NULL DEFAULT '{}'::JSONB,
            due_at TIMESTAMP WITH TIME ZONE,
            person_id UUID,
            answers JSONB NOT NULL DEFAULT '{}'::JSONB,
            notation_id UUID NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            CONSTRAINT fk_assigned_notations_entity
                FOREIGN KEY (entity_id)
                REFERENCES directory.entities(id)
                ON DELETE CASCADE,
            CONSTRAINT fk_assigned_notations_person
                FOREIGN KEY (person_id)
                REFERENCES directory.people(id)
                ON DELETE SET NULL,
            CONSTRAINT fk_assigned_notations_notation
                FOREIGN KEY (notation_id)
                REFERENCES standards.notations(id)
                ON DELETE CASCADE
        );

        -- Add check constraint for state enum
        ALTER TABLE matters.assigned_notations
        ADD CONSTRAINT assigned_notations_state_check
        CHECK (state IN ('awaiting_flow', 'awaiting_review', 'awaiting_alignment', 'complete', 'complete_with_error'));

        -- Create indexes for foreign keys and state
        CREATE INDEX idx_assigned_notations_entity_id
            ON matters.assigned_notations(entity_id);
        CREATE INDEX idx_assigned_notations_person_id
            ON matters.assigned_notations(person_id);
        CREATE INDEX idx_assigned_notations_notation_id
            ON matters.assigned_notations(notation_id);
        CREATE INDEX idx_assigned_notations_state
            ON matters.assigned_notations(state);
        CREATE INDEX idx_assigned_notations_due_at
            ON matters.assigned_notations(due_at);
    END IF;
END $$;

-- Add updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_matters_assigned_notations_updated_at'
    ) THEN
        CREATE TRIGGER update_matters_assigned_notations_updated_at
        BEFORE UPDATE ON matters.assigned_notations
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE matters.assigned_notations ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Customer role: Can view their own assigned notations (through entity relationship)
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'assigned_notations'
        AND policyname = 'assigned_notations_customer_select_policy'
    ) THEN
        CREATE POLICY assigned_notations_customer_select_policy ON matters.assigned_notations
        FOR SELECT TO customer
        USING (TRUE);
    END IF;
END $$;

-- Staff role: Can view and manage all assigned notations
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'assigned_notations'
        AND policyname = 'assigned_notations_staff_select_policy'
    ) THEN
        CREATE POLICY assigned_notations_staff_select_policy ON matters.assigned_notations
        FOR SELECT TO staff
        USING (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'assigned_notations'
        AND policyname = 'assigned_notations_staff_insert_policy'
    ) THEN
        CREATE POLICY assigned_notations_staff_insert_policy ON matters.assigned_notations
        FOR INSERT TO staff
        WITH CHECK (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'assigned_notations'
        AND policyname = 'assigned_notations_staff_update_policy'
    ) THEN
        CREATE POLICY assigned_notations_staff_update_policy ON matters.assigned_notations
        FOR UPDATE TO staff
        USING (TRUE)
        WITH CHECK (TRUE);
    END IF;
END $$;

-- Admin role: Full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'assigned_notations'
        AND policyname = 'assigned_notations_admin_all_policy'
    ) THEN
        CREATE POLICY assigned_notations_admin_all_policy ON matters.assigned_notations
        FOR ALL TO admin
        USING (TRUE)
        WITH CHECK (TRUE);
    END IF;
END $$;

-- Grant permissions to roles
GRANT SELECT ON matters.assigned_notations TO customer;
GRANT SELECT, INSERT, UPDATE ON matters.assigned_notations TO staff;
GRANT ALL ON matters.assigned_notations TO admin;

-- Add comments for documentation
COMMENT ON TABLE matters.assigned_notations IS
'Tracks assigned notations to entities with their completion state and answers';
COMMENT ON COLUMN matters.assigned_notations.id IS
'Unique identifier for the assigned notation';
COMMENT ON COLUMN matters.assigned_notations.entity_id IS
'Foreign key reference to the entity this notation is assigned to';
COMMENT ON COLUMN matters.assigned_notations.state IS
'Current state of the notation: awaiting_flow, awaiting_review, awaiting_alignment, complete, complete_with_error';
COMMENT ON COLUMN matters.assigned_notations.change_language IS
'JSON object containing any change language or modifications to the notation';
COMMENT ON COLUMN matters.assigned_notations.due_at IS
'Optional timestamp indicating when this notation assignment is due';
COMMENT ON COLUMN matters.assigned_notations.person_id IS
'Optional foreign key reference to the person assigned to complete this notation';
COMMENT ON COLUMN matters.assigned_notations.answers IS
'JSON object containing the answers provided for this notation';
COMMENT ON COLUMN matters.assigned_notations.notation_id IS
'Foreign key reference to the notation template being used';
COMMENT ON COLUMN matters.assigned_notations.created_at IS
'Timestamp when the notation was assigned';
COMMENT ON COLUMN matters.assigned_notations.updated_at IS
'Timestamp when the assigned notation was last updated';
