-- Rename address_id column to directory_address_id in mail.mailboxes table
-- This migration updates the column name to be more explicit about the reference to directory.address
DO $$ BEGIN
    -- Check if the column exists and rename it
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'mail' 
        AND table_name = 'mailboxes' 
        AND column_name = 'address_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'mail' 
        AND table_name = 'mailboxes' 
        AND column_name = 'directory_address_id'
    ) THEN
        -- Rename the column
        ALTER TABLE mail.mailboxes RENAME COLUMN address_id TO directory_address_id;
        
        -- Drop the old index
        DROP INDEX IF EXISTS mail.idx_mailboxes_address_id;
        
        -- Create new index with updated name
        CREATE INDEX idx_mailboxes_directory_address_id ON mail.mailboxes (directory_address_id);
        
        -- Update the comment on the column
        COMMENT ON COLUMN mail.mailboxes.directory_address_id IS 
            'Foreign key reference to the directory.address table';
    END IF;
END $$;
