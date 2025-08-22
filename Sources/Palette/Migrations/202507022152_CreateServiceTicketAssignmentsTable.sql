-- Create the ticket_assignments table in the service schema
DO $$
BEGIN
    -- Create the ticket_assignments table if it doesn't exist
    CREATE TABLE IF NOT EXISTS service.ticket_assignments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        ticket_id UUID NOT NULL REFERENCES service.tickets(id) ON DELETE CASCADE,
        assigned_to UUID REFERENCES auth.users(id),
        assigned_from UUID REFERENCES auth.users(id),
        assigned_by UUID REFERENCES auth.users(id),
        assignment_reason TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Add column comments for ticket_assignments table
    COMMENT ON TABLE service.ticket_assignments IS 'Assignment history for tickets, tracking ownership changes';
    COMMENT ON COLUMN service.ticket_assignments.id IS 'Unique identifier for the assignment record';
    COMMENT ON COLUMN service.ticket_assignments.ticket_id IS 'Reference to the ticket being assigned';
    COMMENT ON COLUMN service.ticket_assignments.assigned_to IS 'Reference to user in auth.users the ticket was assigned to (NULL for unassignment)';
    COMMENT ON COLUMN service.ticket_assignments.assigned_from IS 'Reference to user in auth.users the ticket was previously assigned to (NULL for initial assignment)';
    COMMENT ON COLUMN service.ticket_assignments.assigned_by IS 'Reference to user in auth.users who performed the assignment action';
    COMMENT ON COLUMN service.ticket_assignments.assignment_reason IS 'Optional reason for the assignment change';
    COMMENT ON COLUMN service.ticket_assignments.created_at IS 'Timestamp when the assignment was made';
    
    -- Create indexes for performance
    CREATE INDEX IF NOT EXISTS idx_service_ticket_assignments_ticket ON service.ticket_assignments(ticket_id);
    
    -- Grant permissions on the ticket_assignments table
    -- Customers can see assignment history for their tickets (transparency)
    GRANT SELECT ON service.ticket_assignments TO customer;
    -- Staff can read all and create new assignments
    GRANT SELECT, INSERT ON service.ticket_assignments TO staff;
    -- Admin has full access
    GRANT ALL ON service.ticket_assignments TO admin;
END $$;
