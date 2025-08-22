-- Create mail.letters table
-- This table stores letters received at virtual mailboxes
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'mail' AND table_name = 'letters'
    ) THEN
        CREATE TABLE mail.letters (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            mailbox_id UUID NOT NULL,
            sender_address_id UUID,
            received_date DATE NOT NULL,
            postmark_date DATE,
            tracking_number TEXT,
            carrier TEXT,
            letter_type TEXT,
            status TEXT NOT NULL DEFAULT 'received' 
                CHECK (status IN ('received', 'scanned', 'emailed', 'forwarded', 'shredded', 'returned')),
            scanned_at TIMESTAMP WITH TIME ZONE,
            scanned_by UUID,
            emailed_at TIMESTAMP WITH TIME ZONE,
            emailed_to TEXT[],
            forwarded_at TIMESTAMP WITH TIME ZONE,
            forwarded_to_address TEXT,
            forwarding_tracking_number TEXT,
            shredded_at TIMESTAMP WITH TIME ZONE,
            returned_at TIMESTAMP WITH TIME ZONE,
            return_reason TEXT,
            notes TEXT,
            is_priority BOOLEAN DEFAULT false,
            requires_signature BOOLEAN DEFAULT false,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
            CONSTRAINT fk_letter_mailbox FOREIGN KEY (mailbox_id) REFERENCES mail.mailboxes (id),
            CONSTRAINT fk_letter_sender_address FOREIGN KEY (sender_address_id) REFERENCES directory.address (id),
            CONSTRAINT fk_letter_scanned_by FOREIGN KEY (scanned_by) REFERENCES auth.users (id)
        );
    END IF;
END $$;

-- Add comments
COMMENT ON TABLE mail.letters IS 'Stores letters received at virtual mailboxes';
COMMENT ON COLUMN mail.letters.id IS 'Unique identifier for the letter';
COMMENT ON COLUMN mail.letters.mailbox_id IS 'Foreign key reference to the mailbox that received the letter';
COMMENT ON COLUMN mail.letters.sender_address_id IS
'Foreign key reference to the sender address in directory.address table';
COMMENT ON COLUMN mail.letters.received_date IS 'Date when the letter was physically received at the mailbox';
COMMENT ON COLUMN mail.letters.postmark_date IS 'Date from the postal cancellation mark';
COMMENT ON COLUMN mail.letters.tracking_number IS 'Tracking number for trackable mail pieces';
COMMENT ON COLUMN mail.letters.carrier IS 'Delivery service that brought the mail (USPS, UPS, FedEx, etc.)';
COMMENT ON COLUMN mail.letters.letter_type IS 'Classification of mail (regular, certified, registered, priority, etc.)';
COMMENT ON COLUMN mail.letters.status IS 'Current processing status of the letter';
COMMENT ON COLUMN mail.letters.scanned_at IS 'Timestamp when the letter was scanned';
COMMENT ON COLUMN mail.letters.scanned_by IS 'User who scanned the letter';
COMMENT ON COLUMN mail.letters.emailed_at IS 'Timestamp when the scan was emailed to the customer';
COMMENT ON COLUMN mail.letters.emailed_to IS 'Array of email addresses the scan was sent to';
COMMENT ON COLUMN mail.letters.forwarded_at IS 'Timestamp when the letter was physically forwarded';
COMMENT ON COLUMN mail.letters.forwarded_to_address IS 'Address where the letter was forwarded to';
COMMENT ON COLUMN mail.letters.forwarding_tracking_number IS 'Tracking number for the forwarded mail';
COMMENT ON COLUMN mail.letters.shredded_at IS 'Timestamp when the letter was securely destroyed';
COMMENT ON COLUMN mail.letters.returned_at IS 'Timestamp when the letter was returned to sender';
COMMENT ON COLUMN mail.letters.return_reason IS 'Reason why the letter was returned';
COMMENT ON COLUMN mail.letters.notes IS 'Additional notes about the letter';
COMMENT ON COLUMN mail.letters.is_priority IS 'Flag indicating if the letter requires urgent handling';
COMMENT ON COLUMN mail.letters.requires_signature IS 'Flag indicating if the letter requires signature confirmation';
COMMENT ON COLUMN mail.letters.created_at IS 'Timestamp when the letter record was created';
COMMENT ON COLUMN mail.letters.updated_at IS 'Timestamp when the letter record was last updated';

-- Create updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_mail_letters_updated_at'
    ) THEN
        CREATE TRIGGER update_mail_letters_updated_at 
        BEFORE UPDATE ON mail.letters
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_letters_mailbox_id ON mail.letters (mailbox_id);
CREATE INDEX IF NOT EXISTS idx_letters_sender_address_id ON mail.letters (sender_address_id);
CREATE INDEX IF NOT EXISTS idx_letters_status ON mail.letters (status);
CREATE INDEX IF NOT EXISTS idx_letters_received_date ON mail.letters (received_date);
CREATE INDEX IF NOT EXISTS idx_letters_is_priority ON mail.letters (is_priority);
CREATE INDEX IF NOT EXISTS idx_letters_scanned_by ON mail.letters (scanned_by);

-- Row-level security
ALTER TABLE mail.letters ENABLE ROW LEVEL SECURITY;

-- Policy for customer role: can only read letters for their own mailboxes
-- This will need to be refined based on how customer ownership is determined
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'letters_customer_read' AND polrelid = 'mail.letters'::regclass
    ) THEN
        CREATE POLICY letters_customer_read ON mail.letters
        FOR SELECT
        TO customer
        USING (true); -- Will be updated to check ownership through mailbox relationships
    END IF;
END $$;

-- Policy for staff role: can read all letters and create/update but not delete
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'letters_staff_read' AND polrelid = 'mail.letters'::regclass
    ) THEN
        CREATE POLICY letters_staff_read ON mail.letters
        FOR SELECT
        TO staff
        USING (true);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'letters_staff_insert' AND polrelid = 'mail.letters'::regclass
    ) THEN
        CREATE POLICY letters_staff_insert ON mail.letters
        FOR INSERT
        TO staff
        WITH CHECK (true);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'letters_staff_update' AND polrelid = 'mail.letters'::regclass
    ) THEN
        CREATE POLICY letters_staff_update ON mail.letters
        FOR UPDATE
        TO staff
        USING (true);
    END IF;
END $$;

-- Policy for admin role: full access
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy 
        WHERE polname = 'letters_admin_all' AND polrelid = 'mail.letters'::regclass
    ) THEN
        CREATE POLICY letters_admin_all ON mail.letters
        FOR ALL
        TO admin
        USING (true);
    END IF;
END $$;

-- Grant permissions
GRANT SELECT ON mail.letters TO customer;
GRANT SELECT, INSERT, UPDATE ON mail.letters TO staff;
GRANT ALL ON mail.letters TO admin;
