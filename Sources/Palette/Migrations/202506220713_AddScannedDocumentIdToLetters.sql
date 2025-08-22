-- Add scanned_document_id column to mail.letters table
-- This column references the scanned document stored in documents.blobs
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'mail' 
        AND table_name = 'letters' 
        AND column_name = 'scanned_document_id'
    ) THEN
        ALTER TABLE mail.letters 
        ADD COLUMN scanned_document_id UUID;
        
        -- Add foreign key constraint
        ALTER TABLE mail.letters 
        ADD CONSTRAINT fk_letter_scanned_document 
        FOREIGN KEY (scanned_document_id) REFERENCES documents.blobs (id);
    END IF;
END $$;

-- Add comment for the new column
COMMENT ON COLUMN mail.letters.scanned_document_id IS
'Foreign key reference to the scanned document in documents.blobs table';

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_letters_scanned_document_id ON mail.letters (scanned_document_id);
