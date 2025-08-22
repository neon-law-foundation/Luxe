-- Create notations_questions join table in the standards schema
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'standards'
        AND tablename = 'notations_questions'
    ) THEN
        CREATE TABLE standards.notations_questions (
            notation_id UUID NOT NULL,
            question_id UUID NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            PRIMARY KEY (notation_id, question_id),
            CONSTRAINT fk_notations_questions_notation
                FOREIGN KEY (notation_id) 
                REFERENCES standards.notations(id) 
                ON DELETE CASCADE,
            CONSTRAINT fk_notations_questions_question
                FOREIGN KEY (question_id) 
                REFERENCES standards.questions(id) 
                ON DELETE CASCADE
        );

        -- Create indexes for foreign keys
        CREATE INDEX idx_notations_questions_notation_id 
            ON standards.notations_questions(notation_id);
        CREATE INDEX idx_notations_questions_question_id 
            ON standards.notations_questions(question_id);
    END IF;
END $$;

-- Add updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_standards_notations_questions_updated_at'
    ) THEN
        CREATE TRIGGER update_standards_notations_questions_updated_at
        BEFORE UPDATE ON standards.notations_questions
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE standards.notations_questions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Customer role: Can view join records for published notations
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations_questions'
        AND policyname = 'notations_questions_customer_select_policy'
    ) THEN
        CREATE POLICY notations_questions_customer_select_policy ON standards.notations_questions
        FOR SELECT TO customer
        USING (
            EXISTS (
                SELECT 1 FROM standards.notations n
                WHERE n.id = notation_id
                AND n.published = TRUE
            )
        );
    END IF;
END $$;

-- Staff role: Can view all and manage unpublished notation relationships
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations_questions'
        AND policyname = 'notations_questions_staff_select_policy'
    ) THEN
        CREATE POLICY notations_questions_staff_select_policy ON standards.notations_questions
        FOR SELECT TO staff
        USING (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations_questions'
        AND policyname = 'notations_questions_staff_insert_policy'
    ) THEN
        CREATE POLICY notations_questions_staff_insert_policy ON standards.notations_questions
        FOR INSERT TO staff
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM standards.notations n
                WHERE n.id = notation_id
                AND n.published = FALSE
            )
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations_questions'
        AND policyname = 'notations_questions_staff_update_policy'
    ) THEN
        CREATE POLICY notations_questions_staff_update_policy ON standards.notations_questions
        FOR UPDATE TO staff
        USING (
            EXISTS (
                SELECT 1 FROM standards.notations n
                WHERE n.id = notation_id
                AND n.published = FALSE
            )
        )
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM standards.notations n
                WHERE n.id = notation_id
                AND n.published = FALSE
            )
        );
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations_questions'
        AND policyname = 'notations_questions_staff_delete_policy'
    ) THEN
        CREATE POLICY notations_questions_staff_delete_policy ON standards.notations_questions
        FOR DELETE TO staff
        USING (
            EXISTS (
                SELECT 1 FROM standards.notations n
                WHERE n.id = notation_id
                AND n.published = FALSE
            )
        );
    END IF;
END $$;

-- Admin role: Full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'standards'
        AND tablename = 'notations_questions'
        AND policyname = 'notations_questions_admin_all_policy'
    ) THEN
        CREATE POLICY notations_questions_admin_all_policy ON standards.notations_questions
        FOR ALL TO admin
        USING (TRUE)
        WITH CHECK (TRUE);
    END IF;
END $$;

-- Grant permissions to roles
GRANT SELECT ON standards.notations_questions TO customer;
GRANT SELECT, INSERT, UPDATE, DELETE ON standards.notations_questions TO staff;
GRANT ALL ON standards.notations_questions TO admin;

-- Add comments for documentation
COMMENT ON TABLE standards.notations_questions IS
'Join table linking notations to their associated questions';
COMMENT ON COLUMN standards.notations_questions.notation_id IS
'Foreign key reference to the notation';
COMMENT ON COLUMN standards.notations_questions.question_id IS
'Foreign key reference to the question';
COMMENT ON COLUMN standards.notations_questions.created_at IS
'Timestamp when the notation-question association was created';
COMMENT ON COLUMN standards.notations_questions.updated_at IS
'Timestamp when the notation-question association was last updated';
