-- Update documents.blobs referenced_by field to support polymorphism
-- This migration extends the referenced_by constraint to include all tables that reference documents.blobs
--
-- POLYMORPHISM EXPLANATION:
-- Polymorphism in database design allows a single table (documents.blobs) to be referenced
-- by multiple different entity types. The 'referenced_by' field acts as a discriminator
-- that identifies which type of entity is referencing the blob, while 'referenced_by_id'
-- contains the UUID of that specific entity.
--
-- This pattern enables:
-- 1. A single blob storage table that can serve multiple entity types
-- 2. Consistent blob management across the application
-- 3. Easier maintenance of file storage logic
-- 4. Referential integrity through foreign key constraints
--
-- Current referencing tables:
-- - mail.letters (scanned_document_id) 
-- - equity.share_issuances (document_id)
-- - matters.answers (blob_id)

-- Drop the existing check constraint (created inline in original table definition)
DO $$ 
DECLARE
    constraint_name_var TEXT;
BEGIN
    -- Find the existing check constraint name
    SELECT conname INTO constraint_name_var
    FROM pg_constraint 
    WHERE contype = 'c' 
    AND conrelid = 'documents.blobs'::regclass
    AND pg_get_constraintdef(oid) LIKE '%referenced_by%';
    
    -- Drop it if it exists
    IF constraint_name_var IS NOT NULL THEN
        EXECUTE 'ALTER TABLE documents.blobs DROP CONSTRAINT ' || constraint_name_var;
    END IF;
END $$;

-- Add the updated constraint with all referencing table types
ALTER TABLE documents.blobs
ADD CONSTRAINT documents_blobs_referenced_by_check
CHECK (referenced_by IN ('letters', 'share_issuances', 'answers'));

-- Update the column comment to reflect polymorphic usage
COMMENT ON COLUMN documents.blobs.referenced_by IS
'Type of entity referencing this blob (polymorphic discriminator). Values: letters, share_issuances, answers';

-- Update the table comment to explain polymorphism
COMMENT ON TABLE documents.blobs IS
'Stores file references in S3. Uses polymorphism: referenced_by discriminates, referenced_by_id has UUID';
