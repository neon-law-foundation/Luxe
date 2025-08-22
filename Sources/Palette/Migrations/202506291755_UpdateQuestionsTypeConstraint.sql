DO $$
BEGIN
    -- Drop the old check constraint
    ALTER TABLE standards.questions DROP CONSTRAINT IF EXISTS questions_question_type_check;

    -- Add the updated check constraint with correct values matching the Swift enum
    ALTER TABLE standards.questions ADD CONSTRAINT questions_question_type_check CHECK (question_type IN (
        'string',           -- One line of text
        'text',             -- Multi-line text stored as Content Editable
        'date',             -- Date
        'datetime',         -- Date and time
        'number',           -- Number
        'yes_no',           -- Yes or No
        'radio',            -- Radio buttons for an XOR selection
        'select',           -- Select dropdown for a single selection
        'multi_select',     -- Select dropdown for multiple selections
        'secret',           -- Sensitive data like SSNs and EINs
        'signature',        -- E-signature record in our database
        'notarization',     -- Notarization requiring an ID from Proof
        'phone',            -- Phone number that we can verify by sending an OTP message to
        'email',            -- Email address that we can verify by sending an OTP message to
        'ssn',              -- Social Security Number, with a specific format
        'ein',              -- Employer Identification Number, with a specific format
        'file',             -- File upload
        'person',           -- Directory.Person record
        'address',          -- Directory.Address record
        'issuance',         -- Shares.Issuance record
        'org',              -- Directory.Entity record (changed from 'entity' to 'org')
        'document',         -- Documents.Document record
        'registered_agent'  -- A registered agent record in our database
    ));
END $$;
