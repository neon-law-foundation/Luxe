-- Create matters.answers table
-- This table stores individual answers to questions, tracking who answered and linking to various entities
-- Each answer is tied to a specific question, answerer, entity, and optionally an assigned notation

-- Create the answers table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'matters'
        AND table_name = 'answers'
    ) THEN
        CREATE TABLE matters.answers (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            blob_id UUID,
            answerer_id UUID NOT NULL,
            question_id UUID NOT NULL,
            entity_id UUID NOT NULL,
            assigned_notation_id UUID,
            response JSONB NOT NULL DEFAULT '{}'::JSONB,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,

            -- Foreign key constraints
            CONSTRAINT fk_answers_blob
                FOREIGN KEY (blob_id)
                REFERENCES documents.blobs(id)
                ON DELETE SET NULL,
            CONSTRAINT fk_answers_answerer
                FOREIGN KEY (answerer_id)
                REFERENCES directory.people(id)
                ON DELETE CASCADE,
            CONSTRAINT fk_answers_question
                FOREIGN KEY (question_id)
                REFERENCES standards.questions(id)
                ON DELETE CASCADE,
            CONSTRAINT fk_answers_entity
                FOREIGN KEY (entity_id)
                REFERENCES directory.entities(id)
                ON DELETE CASCADE,
            CONSTRAINT fk_answers_assigned_notation
                FOREIGN KEY (assigned_notation_id)
                REFERENCES matters.assigned_notations(id)
                ON DELETE SET NULL
        );

        -- Create indexes for performance
        CREATE INDEX idx_answers_blob_id ON matters.answers(blob_id);
        CREATE INDEX idx_answers_answerer_id ON matters.answers(answerer_id);
        CREATE INDEX idx_answers_question_id ON matters.answers(question_id);
        CREATE INDEX idx_answers_entity_id ON matters.answers(entity_id);
        CREATE INDEX idx_answers_assigned_notation_id ON matters.answers(assigned_notation_id);
        CREATE INDEX idx_answers_created_at ON matters.answers(created_at);
        
        -- Composite indexes for common query patterns
        CREATE INDEX idx_answers_entity_question ON matters.answers(entity_id, question_id);
        CREATE INDEX idx_answers_answerer_entity ON matters.answers(answerer_id, entity_id);
        CREATE INDEX idx_answers_assigned_notation_question ON matters.answers(assigned_notation_id, question_id);
    END IF;
END $$;

-- Add updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_matters_answers_updated_at'
    ) THEN
        CREATE TRIGGER update_matters_answers_updated_at
        BEFORE UPDATE ON matters.answers
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE matters.answers ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Customer role: Can view answers related to their entities
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'answers'
        AND policyname = 'answers_customer_select_policy'
    ) THEN
        CREATE POLICY answers_customer_select_policy ON matters.answers
        FOR SELECT TO customer
        USING (TRUE);
    END IF;
END $$;

-- Customer role: Can insert answers for their entities
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'answers'
        AND policyname = 'answers_customer_insert_policy'
    ) THEN
        CREATE POLICY answers_customer_insert_policy ON matters.answers
        FOR INSERT TO customer
        WITH CHECK (TRUE);
    END IF;
END $$;

-- Customer role: Can update their own answers
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'answers'
        AND policyname = 'answers_customer_update_policy'
    ) THEN
        CREATE POLICY answers_customer_update_policy ON matters.answers
        FOR UPDATE TO customer
        USING (TRUE)
        WITH CHECK (TRUE);
    END IF;
END $$;

-- Staff role: Can view and manage all answers
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'answers'
        AND policyname = 'answers_staff_select_policy'
    ) THEN
        CREATE POLICY answers_staff_select_policy ON matters.answers
        FOR SELECT TO staff
        USING (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'answers'
        AND policyname = 'answers_staff_insert_policy'
    ) THEN
        CREATE POLICY answers_staff_insert_policy ON matters.answers
        FOR INSERT TO staff
        WITH CHECK (TRUE);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'matters'
        AND tablename = 'answers'
        AND policyname = 'answers_staff_update_policy'
    ) THEN
        CREATE POLICY answers_staff_update_policy ON matters.answers
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
        AND tablename = 'answers'
        AND policyname = 'answers_admin_all_policy'
    ) THEN
        CREATE POLICY answers_admin_all_policy ON matters.answers
        FOR ALL TO admin
        USING (TRUE)
        WITH CHECK (TRUE);
    END IF;
END $$;

-- Grant permissions to roles
GRANT SELECT, INSERT, UPDATE ON matters.answers TO customer;
GRANT SELECT, INSERT, UPDATE ON matters.answers TO staff;
GRANT ALL ON matters.answers TO admin;

-- Add comments for documentation
COMMENT ON TABLE matters.answers IS
'Individual answers to questions provided by users, linked to entities and optionally assigned notations';
COMMENT ON COLUMN matters.answers.id IS 'Unique identifier for the answer record';
COMMENT ON COLUMN matters.answers.blob_id IS
'Optional foreign key reference to a document blob associated with this answer';
COMMENT ON COLUMN matters.answers.answerer_id IS 'Foreign key reference to the person who provided this answer';
COMMENT ON COLUMN matters.answers.question_id IS 'Foreign key reference to the question being answered';
COMMENT ON COLUMN matters.answers.entity_id IS 'Foreign key reference to the entity this answer relates to';
COMMENT ON COLUMN matters.answers.assigned_notation_id IS
'Optional foreign key reference to the assigned notation this answer belongs to';
COMMENT ON COLUMN matters.answers.response IS 'JSON object containing the structured answer data';
COMMENT ON COLUMN matters.answers.created_at IS 'Timestamp when the answer was created';
COMMENT ON COLUMN matters.answers.updated_at IS 'Timestamp when the answer was last updated';
