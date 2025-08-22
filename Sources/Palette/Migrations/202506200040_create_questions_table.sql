-- Create the standards.questions table for managing question templates
CREATE TABLE IF NOT EXISTS standards.questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prompt TEXT NOT NULL,
    question_type TEXT NOT NULL CHECK (question_type IN (
        'string',        -- One line of text
        'text',          -- Multi-line text stored as Content Editable
        'date',          -- Date
        'datetime',      -- Date and time
        'number',        -- Number
        'yes_no',        -- Yes or No
        'radio',         -- Radio buttons for an XOR selection
        'select',        -- Select dropdown for a single selection
        'multi_select',  -- Select dropdown for multiple selections
        'secret',        -- Sensitive data like SSNs and EINs
        'signature',     -- E-signature record in our database
        'notarization',  -- Notarization record
        'phone',         -- Phone number that we can verify by sending an OTP message to
        'email',         -- Email address that we can verify by sending an OTP message to
        'ssn',           -- Social Security Number, with a specific format
        'ein',           -- Employer Identification Number, with a specific format
        'file',          -- File upload
        'person',        -- directory.people record
        'address',       -- directory.addresses record
        'issuance',      -- equity.issuances record
        'entity',        -- directory.entities record
        'document'       -- documents.blobs record
    )),
    code CITEXT NOT NULL UNIQUE,
    help_text TEXT,
    choices JSONB NOT NULL DEFAULT '[]'::JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp
);

-- Add comments for the table and columns
COMMENT ON TABLE standards.questions IS 'Questions templates used in Sagebrush Standards';
COMMENT ON COLUMN standards.questions.id IS 'Unique identifier for the question';
COMMENT ON COLUMN standards.questions.prompt IS 'The question text displayed to users';
COMMENT ON COLUMN standards.questions.question_type IS 'Type of input control for the question';
COMMENT ON COLUMN standards.questions.code IS 'Unique code identifier for referencing the question';
COMMENT ON COLUMN standards.questions.help_text IS 'Additional help text displayed to users';
COMMENT ON COLUMN standards.questions.choices IS 'JSON array of choices for select/radio/multi_select types';
COMMENT ON COLUMN standards.questions.created_at IS 'Timestamp when the question was created';
COMMENT ON COLUMN standards.questions.updated_at IS 'Timestamp when the question was last updated';

-- Create trigger for updating the updated_at timestamp
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_standards_questions_updated_at'
    ) THEN
        CREATE TRIGGER update_standards_questions_updated_at
        BEFORE UPDATE ON standards.questions
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create indexes for commonly queried columns
CREATE INDEX IF NOT EXISTS idx_standards_questions_code ON standards.questions (code);
CREATE INDEX IF NOT EXISTS idx_standards_questions_question_type ON standards.questions (question_type);

-- Enable row-level security
ALTER TABLE standards.questions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Customer role can read questions
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'questions_customer_read'
    ) THEN
        CREATE POLICY questions_customer_read ON standards.questions
        FOR SELECT TO customer USING (true);
    END IF;
END $$;

-- Staff role can read questions
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'questions_staff_read'
    ) THEN
        CREATE POLICY questions_staff_read ON standards.questions
        FOR SELECT TO staff USING (true);
    END IF;
END $$;

-- Admin role has full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'questions_admin_all'
    ) THEN
        CREATE POLICY questions_admin_all ON standards.questions
        FOR ALL TO admin USING (true);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON standards.questions TO customer;
GRANT SELECT ON standards.questions TO staff;
GRANT ALL ON standards.questions TO admin;
