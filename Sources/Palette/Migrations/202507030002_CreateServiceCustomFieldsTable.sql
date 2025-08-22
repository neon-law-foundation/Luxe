-- Create the custom_fields table in the service schema
DO $$
BEGIN
    -- Create the custom_fields table if it doesn't exist
    CREATE TABLE IF NOT EXISTS service.custom_fields (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        field_type VARCHAR(50) NOT NULL,
        description TEXT,
        required BOOLEAN NOT NULL DEFAULT FALSE,
        options JSONB,
        position INTEGER NOT NULL DEFAULT 0,
        created_by UUID NOT NULL REFERENCES auth.users(id),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        
        -- Ensure field type is valid
        CONSTRAINT valid_field_type CHECK (field_type IN ('text', 'textarea', 'number', 'date', 'select', 'multiselect', 'checkbox')),
        -- Ensure name is unique
        CONSTRAINT unique_custom_field_name UNIQUE (name),
        -- Ensure position is non-negative
        CONSTRAINT positive_position CHECK (position >= 0)
    );
    
    -- Add column comments for custom_fields table
    COMMENT ON TABLE service.custom_fields IS 'Custom field definitions for tickets, allowing dynamic form creation';
    COMMENT ON COLUMN service.custom_fields.id IS 'Unique identifier for the custom field';
    COMMENT ON COLUMN service.custom_fields.name IS 'Display name of the custom field';
    COMMENT ON COLUMN service.custom_fields.field_type IS 'Type of field: text, textarea, number, date, select, multiselect, checkbox';
    COMMENT ON COLUMN service.custom_fields.description IS 'Optional description or help text for the field';
    COMMENT ON COLUMN service.custom_fields.required IS 'Whether this field is required when filling out tickets';
    COMMENT ON COLUMN service.custom_fields.options IS 'JSON array of options for select/multiselect fields';
    COMMENT ON COLUMN service.custom_fields.position IS 'Display order position of the field in forms';
    COMMENT ON COLUMN service.custom_fields.created_by IS 'Reference to user in auth.users who created this custom field';
    COMMENT ON COLUMN service.custom_fields.created_at IS 'Timestamp when the field was created';
    COMMENT ON COLUMN service.custom_fields.updated_at IS 'Timestamp when the field was last updated';
    
    -- Create indexes for performance
    CREATE INDEX IF NOT EXISTS idx_service_custom_fields_position ON service.custom_fields(position);
    CREATE INDEX IF NOT EXISTS idx_service_custom_fields_type ON service.custom_fields(field_type);
    
    -- Grant permissions on the custom_fields table
    -- Customers can see custom field definitions (for filling out forms)
    GRANT SELECT ON service.custom_fields TO customer;
    -- Staff can read custom fields
    GRANT SELECT ON service.custom_fields TO staff;
    -- Admin has full access to manage custom fields
    GRANT ALL ON service.custom_fields TO admin;
END $$;
