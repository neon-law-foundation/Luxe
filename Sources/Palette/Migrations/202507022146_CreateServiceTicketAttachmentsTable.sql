-- Create the ticket_attachments table in the service schema
DO $$
BEGIN
    -- Create the ticket_attachments table if it doesn't exist
    CREATE TABLE IF NOT EXISTS service.ticket_attachments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        ticket_id UUID REFERENCES service.tickets(id) ON DELETE CASCADE,
        conversation_id UUID REFERENCES service.ticket_conversations(id) ON DELETE CASCADE,
        blob_id UUID NOT NULL,
        
        original_filename VARCHAR(255) NOT NULL,
        uploaded_by UUID REFERENCES auth.users(id),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Add column comments for ticket_attachments table
    COMMENT ON TABLE service.ticket_attachments IS 'File attachments for tickets, references documents.blobs for actual file storage';
    COMMENT ON COLUMN service.ticket_attachments.id IS 'Unique identifier for the attachment';
    COMMENT ON COLUMN service.ticket_attachments.ticket_id IS 'Reference to the ticket this attachment belongs to';
    COMMENT ON COLUMN service.ticket_attachments.conversation_id IS 'Reference to the specific conversation message this attachment was added to';
    COMMENT ON COLUMN service.ticket_attachments.blob_id IS 'Reference to the blob in documents.blobs table where file is stored';
    COMMENT ON COLUMN service.ticket_attachments.original_filename IS 'Original filename as uploaded by the user';
    COMMENT ON COLUMN service.ticket_attachments.uploaded_by IS 'Reference to user in auth.users who uploaded this attachment';
    COMMENT ON COLUMN service.ticket_attachments.created_at IS 'Timestamp when the file was uploaded';
    
    -- Create indexes for performance
    CREATE INDEX IF NOT EXISTS idx_service_ticket_attachments_ticket ON service.ticket_attachments(ticket_id);
    CREATE INDEX IF NOT EXISTS idx_service_ticket_attachments_blob ON service.ticket_attachments(blob_id);
    
    -- Grant permissions on the ticket_attachments table
    -- Customers can see attachments for their tickets
    GRANT SELECT ON service.ticket_attachments TO customer;
    -- Staff can read all and create new attachments
    GRANT SELECT, INSERT ON service.ticket_attachments TO staff;
    -- Admin has full access
    GRANT ALL ON service.ticket_attachments TO admin;
END $$;
