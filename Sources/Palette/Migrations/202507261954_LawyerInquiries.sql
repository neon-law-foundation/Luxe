-- Create table for lawyer inquiries
DO $$
BEGIN
    -- Create lawyer_inquiries table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'lawyer_inquiries'
    ) THEN
        CREATE TABLE lawyer_inquiries (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            firm_name VARCHAR(255) NOT NULL,
            contact_name VARCHAR(255) NOT NULL,
            email VARCHAR(255) NOT NULL,
            nevada_bar_member VARCHAR(20) CHECK (nevada_bar_member IN ('yes', 'no', 'considering')),
            current_software VARCHAR(255),
            use_cases TEXT,
            inquiry_status VARCHAR(50) DEFAULT 'new' NOT NULL CHECK (inquiry_status IN ('new', 'contacted', 'qualified', 'converted', 'declined')),
            notes TEXT,
            created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
            updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
        );

        -- Add comments
        COMMENT ON TABLE lawyer_inquiries IS 'Stores inquiries from lawyers interested in the AI platform';
        COMMENT ON COLUMN lawyer_inquiries.id IS 'Unique identifier for the inquiry';
        COMMENT ON COLUMN lawyer_inquiries.firm_name IS 'Name of the law firm making the inquiry';
        COMMENT ON COLUMN lawyer_inquiries.contact_name IS 'Name of the person submitting the inquiry';
        COMMENT ON COLUMN lawyer_inquiries.email IS 'Contact email address';
        COMMENT ON COLUMN lawyer_inquiries.nevada_bar_member IS 'Nevada Bar membership status: yes, no, or considering';
        COMMENT ON COLUMN lawyer_inquiries.current_software IS 'Current case management software they use';
        COMMENT ON COLUMN lawyer_inquiries.use_cases IS 'AI use cases they are interested in';
        COMMENT ON COLUMN lawyer_inquiries.inquiry_status IS 'Current status of the inquiry: new, contacted, qualified, converted, declined';
        COMMENT ON COLUMN lawyer_inquiries.notes IS 'Internal notes about the inquiry';
        COMMENT ON COLUMN lawyer_inquiries.created_at IS 'When the inquiry was submitted';
        COMMENT ON COLUMN lawyer_inquiries.updated_at IS 'When the inquiry was last updated';

        -- Create index on email for fast lookups
        CREATE INDEX idx_lawyer_inquiries_email ON lawyer_inquiries(email);

        -- Create index on status for filtering
        CREATE INDEX idx_lawyer_inquiries_status ON lawyer_inquiries(inquiry_status);

        -- Create index on created_at for sorting
        CREATE INDEX idx_lawyer_inquiries_created_at ON lawyer_inquiries(created_at DESC);
    END IF;

    -- Create updated_at trigger if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers
        WHERE trigger_schema = 'public'
        AND trigger_name = 'update_lawyer_inquiries_updated_at'
    ) THEN
        CREATE TRIGGER update_lawyer_inquiries_updated_at
        BEFORE UPDATE ON lawyer_inquiries
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;

    -- Set up row-level security
    ALTER TABLE lawyer_inquiries ENABLE ROW LEVEL SECURITY;

    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS lawyer_inquiries_customer_policy ON lawyer_inquiries;
    DROP POLICY IF EXISTS lawyer_inquiries_staff_policy ON lawyer_inquiries;
    DROP POLICY IF EXISTS lawyer_inquiries_admin_policy ON lawyer_inquiries;

    -- Customer role: No access to lawyer inquiries
    CREATE POLICY lawyer_inquiries_customer_policy ON lawyer_inquiries
        FOR ALL
        TO customer
        USING (false);

    -- Staff role: Can view all inquiries but not modify
    CREATE POLICY lawyer_inquiries_staff_policy ON lawyer_inquiries
        FOR SELECT
        TO staff
        USING (true);

    -- Admin role: Full access to all inquiries
    CREATE POLICY lawyer_inquiries_admin_policy ON lawyer_inquiries
        FOR ALL
        TO admin
        USING (true);

    -- Grant permissions
    GRANT SELECT ON lawyer_inquiries TO staff;
    GRANT ALL ON lawyer_inquiries TO admin;

    -- Grant permissions for test user (postgres superuser needs access for tests)
    GRANT ALL ON lawyer_inquiries TO postgres;
END $$;
