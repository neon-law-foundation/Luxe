-- Create the tickets table in the service schema
DO $$
BEGIN
    -- Create the tickets table if it doesn't exist
    CREATE TABLE IF NOT EXISTS service.tickets (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        ticket_number VARCHAR(50) UNIQUE NOT NULL,
        subject VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        
        -- Requester information
        requester_id UUID NOT NULL REFERENCES auth.users(id),
        requester_email VARCHAR(255),
        
        -- Assignment and ownership
        assignee_id UUID REFERENCES auth.users(id),
        
        -- Classification (removed category_id as requested)
        priority VARCHAR(20) NOT NULL DEFAULT 'medium',
        status VARCHAR(50) NOT NULL DEFAULT 'open',
        
        -- Metadata
        source VARCHAR(50) DEFAULT 'web',
        tags TEXT[],
        
        -- Timestamps
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        resolved_at TIMESTAMP WITH TIME ZONE,
        closed_at TIMESTAMP WITH TIME ZONE,
        
        -- Constraints
        CONSTRAINT valid_priority CHECK (priority IN ('low', 'medium', 'high', 'critical')),
        CONSTRAINT valid_status CHECK (status IN ('open', 'pending', 'in_progress', 'resolved', 'closed'))
    );
    
    -- Add column comments for tickets table
    COMMENT ON TABLE service.tickets IS 'Main table for customer service tickets';
    COMMENT ON COLUMN service.tickets.id IS 'Unique identifier for the ticket';
    COMMENT ON COLUMN service.tickets.ticket_number IS 'Human-readable ticket number displayed to users (e.g., TKT-001234)';
    COMMENT ON COLUMN service.tickets.subject IS 'Brief summary of the ticket issue';
    COMMENT ON COLUMN service.tickets.description IS 'Detailed description of the issue or request';
    COMMENT ON COLUMN service.tickets.requester_id IS 'Reference to user in auth.users who submitted the ticket';
    COMMENT ON COLUMN service.tickets.requester_email IS 'Email of ticket requester, used when requester is not a registered user';
    COMMENT ON COLUMN service.tickets.assignee_id IS 'Reference to user in auth.users currently assigned to work on this ticket';
    COMMENT ON COLUMN service.tickets.priority IS 'Priority level: low, medium, high, or critical';
    COMMENT ON COLUMN service.tickets.status IS 'Current status: open, pending, in_progress, resolved, or closed';
    COMMENT ON COLUMN service.tickets.source IS 'How the ticket was submitted: email, web, phone, or chat';
    COMMENT ON COLUMN service.tickets.tags IS 'Array of tags for flexible categorization and searching';
    COMMENT ON COLUMN service.tickets.created_at IS 'Timestamp when the ticket was created';
    COMMENT ON COLUMN service.tickets.updated_at IS 'Timestamp when the ticket was last updated';
    COMMENT ON COLUMN service.tickets.resolved_at IS 'Timestamp when the ticket was marked as resolved';
    COMMENT ON COLUMN service.tickets.closed_at IS 'Timestamp when the ticket was closed';
    
    -- Create indexes for performance
    CREATE INDEX IF NOT EXISTS idx_service_tickets_requester ON service.tickets(requester_id);
    CREATE INDEX IF NOT EXISTS idx_service_tickets_assignee ON service.tickets(assignee_id);
    CREATE INDEX IF NOT EXISTS idx_service_tickets_status ON service.tickets(status);
    CREATE INDEX IF NOT EXISTS idx_service_tickets_priority ON service.tickets(priority);
    CREATE INDEX IF NOT EXISTS idx_service_tickets_created_at ON service.tickets(created_at);
    
    -- Create a sequence for ticket numbers
    CREATE SEQUENCE IF NOT EXISTS service.ticket_number_seq START 1000;
    
    -- Grant permissions on the tickets table
    GRANT SELECT ON service.tickets TO customer;
    GRANT SELECT, INSERT, UPDATE ON service.tickets TO staff;
    GRANT ALL ON service.tickets TO admin;
    
    -- Grant usage on the sequence
    GRANT USAGE ON SEQUENCE service.ticket_number_seq TO staff, admin;
END $$;

-- Create function to generate ticket numbers (outside of DO block)
CREATE OR REPLACE FUNCTION service.generate_ticket_number()
RETURNS TEXT AS
$$
BEGIN
    RETURN 'TKT-' || LPAD(nextval('service.ticket_number_seq')::TEXT, 6, '0');
END;
$$
LANGUAGE plpgsql;

-- Create function to set ticket number
CREATE OR REPLACE FUNCTION service.set_ticket_number()
RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.ticket_number IS NULL THEN
        NEW.ticket_number := service.generate_ticket_number();
    END IF;
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Create trigger to auto-generate ticket numbers
DROP TRIGGER IF EXISTS trigger_set_ticket_number ON service.tickets;
CREATE TRIGGER trigger_set_ticket_number
BEFORE INSERT ON service.tickets
FOR EACH ROW
EXECUTE FUNCTION service.set_ticket_number();

-- Create trigger for updated_at timestamp
DROP TRIGGER IF EXISTS trigger_tickets_updated_at ON service.tickets;
CREATE TRIGGER trigger_tickets_updated_at
BEFORE UPDATE ON service.tickets
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
