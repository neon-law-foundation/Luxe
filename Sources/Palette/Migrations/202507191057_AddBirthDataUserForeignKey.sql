-- Add foreign key constraint linking ethereal.birth_data to auth.users
-- This ensures referential integrity between birth data and user accounts

-- Add the foreign key constraint if it doesn't already exist
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_schema = 'ethereal' 
        AND table_name = 'birth_data' 
        AND constraint_name = 'fk_birth_data_user'
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE ethereal.birth_data 
        ADD CONSTRAINT fk_birth_data_user
        FOREIGN KEY (user_id) 
        REFERENCES auth.users(id) 
        ON DELETE CASCADE;
        
        COMMENT ON CONSTRAINT fk_birth_data_user ON ethereal.birth_data IS 
        'Links birth data to user accounts with cascade delete for data privacy';
    END IF;
END $$;

-- Create index on user_id for performance if it doesn't exist
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'ethereal' 
        AND tablename = 'birth_data' 
        AND indexname = 'idx_birth_data_user_id'
    ) THEN
        CREATE INDEX idx_birth_data_user_id ON ethereal.birth_data(user_id);
        COMMENT ON INDEX ethereal.idx_birth_data_user_id IS 
        'Performance index for user birth data lookups';
    END IF;
END $$;
