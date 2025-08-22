-- Create mail.mailboxes table
-- This table stores mailbox information linked to directory addresses
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'mail' AND table_name = 'mailboxes'
    ) THEN
        CREATE TABLE mail.mailboxes (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            address_id UUID NOT NULL,
            mailbox_number INTEGER NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT true,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
            CONSTRAINT fk_mailbox_address FOREIGN KEY (address_id) REFERENCES directory.address (id),
            CONSTRAINT unique_address_mailbox UNIQUE (address_id, mailbox_number)
        );
        
        -- Add comments
        COMMENT ON TABLE mail.mailboxes IS 'Stores mailbox information linked to physical addresses';
        COMMENT ON COLUMN mail.mailboxes.id IS 'Unique identifier for the mailbox';
        COMMENT ON COLUMN mail.mailboxes.address_id IS 'Foreign key reference to the directory.address table';
        COMMENT ON COLUMN mail.mailboxes.mailbox_number IS 'The mailbox number at the given address';
        COMMENT ON COLUMN mail.mailboxes.is_active IS 'Whether the mailbox is currently active and can receive mail';
        COMMENT ON COLUMN mail.mailboxes.created_at IS 'Timestamp when the mailbox was created';
        COMMENT ON COLUMN mail.mailboxes.updated_at IS 'Timestamp when the mailbox was last updated';
        
        -- Create indexes
        CREATE INDEX IF NOT EXISTS idx_mailboxes_address_id ON mail.mailboxes (address_id);
        CREATE INDEX IF NOT EXISTS idx_mailboxes_is_active ON mail.mailboxes (is_active);
        CREATE INDEX IF NOT EXISTS idx_mailboxes_mailbox_number ON mail.mailboxes (mailbox_number);
    END IF;
END $$;

-- Create updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_mail_mailboxes_updated_at'
    ) THEN
        CREATE TRIGGER update_mail_mailboxes_updated_at 
        BEFORE UPDATE ON mail.mailboxes
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Row-level security
ALTER TABLE mail.mailboxes ENABLE ROW LEVEL SECURITY;

-- Policy for customer role: can only read mailboxes
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'mailboxes_customer_read' AND polrelid = 'mail.mailboxes'::regclass
    ) THEN
        CREATE POLICY mailboxes_customer_read ON mail.mailboxes
        FOR SELECT
        TO customer
        USING (true);
    END IF;
END $$;

-- Policy for staff role: can read all mailboxes
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'mailboxes_staff_read' AND polrelid = 'mail.mailboxes'::regclass
    ) THEN
        CREATE POLICY mailboxes_staff_read ON mail.mailboxes
        FOR SELECT
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for admin role: full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'mailboxes_admin_all' AND polrelid = 'mail.mailboxes'::regclass
    ) THEN
        CREATE POLICY mailboxes_admin_all ON mail.mailboxes
        FOR ALL
        TO admin
        USING (true);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON mail.mailboxes TO customer;
GRANT SELECT ON mail.mailboxes TO staff;
GRANT ALL ON mail.mailboxes TO admin;
