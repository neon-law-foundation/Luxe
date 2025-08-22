-- Create the ticket_custom_fields table in the service schema
DO $$
BEGIN
    -- Create the ticket_custom_fields table if it doesn't exist
    CREATE TABLE IF NOT EXISTS service.ticket_custom_fields (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        ticket_id UUID NOT NULL REFERENCES service.tickets(id) ON DELETE CASCADE,
        custom_field_id UUID NOT NULL REFERENCES service.custom_fields(id) ON DELETE CASCADE,
        value TEXT NOT NULL DEFAULT '',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        
        -- Ensure a ticket can only have one value per custom field
        CONSTRAINT unique_ticket_custom_field UNIQUE (ticket_id, custom_field_id)
    );
    
    -- Add column comments for ticket_custom_fields table
    COMMENT ON TABLE service.ticket_custom_fields IS 'Values for custom fields associated with tickets';
    COMMENT ON COLUMN service.ticket_custom_fields.id IS 'Unique identifier for the custom field value';
    COMMENT ON COLUMN service.ticket_custom_fields.ticket_id IS 'Reference to the ticket this custom field value belongs to';
    COMMENT ON COLUMN service.ticket_custom_fields.custom_field_id IS 'Reference to the custom field definition';
    COMMENT ON COLUMN service.ticket_custom_fields.value IS 'The value entered for this custom field (stored as text, JSON for complex types)';
    COMMENT ON COLUMN service.ticket_custom_fields.created_at IS 'Timestamp when the custom field value was created';
    COMMENT ON COLUMN service.ticket_custom_fields.updated_at IS 'Timestamp when the custom field value was last updated';
    
    -- Create indexes for performance
    CREATE INDEX IF NOT EXISTS idx_service_ticket_custom_fields_ticket ON service.ticket_custom_fields(ticket_id);
    CREATE INDEX IF NOT EXISTS idx_service_ticket_custom_fields_field ON service.ticket_custom_fields(custom_field_id);
    
    -- Grant permissions on the ticket_custom_fields table
    -- Customers can see custom field values for their tickets
    GRANT SELECT ON service.ticket_custom_fields TO customer;
    -- Staff can read and update custom field values
    GRANT SELECT, INSERT, UPDATE ON service.ticket_custom_fields TO staff;
    -- Admin has full access
    GRANT ALL ON service.ticket_custom_fields TO admin;
END $$;
