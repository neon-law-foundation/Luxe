-- Create the ticket_watchers table in the service schema
DO $$
BEGIN
    -- Create the ticket_watchers table if it doesn't exist
    CREATE TABLE IF NOT EXISTS service.ticket_watchers (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        ticket_id UUID NOT NULL REFERENCES service.tickets(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        added_by UUID NOT NULL REFERENCES auth.users(id),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        
        -- Ensure a user can only watch a ticket once
        CONSTRAINT unique_ticket_watcher UNIQUE (ticket_id, user_id)
    );
    
    -- Add column comments for ticket_watchers table
    COMMENT ON TABLE service.ticket_watchers IS 'Users watching tickets for notifications and updates';
    COMMENT ON COLUMN service.ticket_watchers.id IS 'Unique identifier for the watcher record';
    COMMENT ON COLUMN service.ticket_watchers.ticket_id IS 'Reference to the ticket being watched';
    COMMENT ON COLUMN service.ticket_watchers.user_id IS 'Reference to user in auth.users who is watching the ticket';
    COMMENT ON COLUMN service.ticket_watchers.added_by IS 'Reference to user in auth.users who added this person as a watcher';
    COMMENT ON COLUMN service.ticket_watchers.created_at IS 'Timestamp when the watcher was added';
    
    -- Create indexes for performance
    CREATE INDEX IF NOT EXISTS idx_service_ticket_watchers_ticket ON service.ticket_watchers(ticket_id);
    CREATE INDEX IF NOT EXISTS idx_service_ticket_watchers_user ON service.ticket_watchers(user_id);
    
    -- Grant permissions on the ticket_watchers table
    -- Customers can see who is watching their tickets
    GRANT SELECT ON service.ticket_watchers TO customer;
    -- Staff can read all and add/remove watchers
    GRANT SELECT, INSERT, DELETE ON service.ticket_watchers TO staff;
    -- Admin has full access
    GRANT ALL ON service.ticket_watchers TO admin;
END $$;
