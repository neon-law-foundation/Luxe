-- Rename the address table to addresses for proper naming convention
-- The table was accidentally created as singular "address" but should be plural "addresses"

DO $$ BEGIN
    -- Rename the table from address to addresses
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'directory' AND tablename = 'address') THEN
        ALTER TABLE directory.address RENAME TO addresses;
        
        -- Update any existing indexes to reflect the new table name
        ALTER INDEX IF EXISTS idx_address_entity_id RENAME TO idx_addresses_entity_id;
        ALTER INDEX IF EXISTS idx_address_person_id RENAME TO idx_addresses_person_id;
        ALTER INDEX IF EXISTS idx_address_is_verified RENAME TO idx_addresses_is_verified;
        
        -- Update any existing constraints to reflect the new table name
        ALTER TABLE directory.addresses RENAME CONSTRAINT address_pkey TO addresses_pkey;
        ALTER TABLE directory.addresses RENAME CONSTRAINT fk_address_entity TO fk_addresses_entity;
        ALTER TABLE directory.addresses RENAME CONSTRAINT fk_address_person TO fk_addresses_person;
        ALTER TABLE directory.addresses RENAME CONSTRAINT chk_address_entity_or_person_exclusive TO chk_addresses_entity_or_person_exclusive;
        
        -- Update trigger name
        DROP TRIGGER IF EXISTS update_directory_address_updated_at ON directory.addresses;
        CREATE TRIGGER update_directory_addresses_updated_at
            BEFORE UPDATE ON directory.addresses
            FOR EACH ROW 
            EXECUTE FUNCTION update_updated_at_column();
            
        -- Update RLS policies
        DROP POLICY IF EXISTS address_customer_read ON directory.addresses;
        DROP POLICY IF EXISTS address_staff_all ON directory.addresses;
        DROP POLICY IF EXISTS address_admin_all ON directory.addresses;
        
        CREATE POLICY addresses_customer_read ON directory.addresses
            FOR SELECT TO customer USING (true);
            
        CREATE POLICY addresses_staff_all ON directory.addresses
            FOR ALL TO staff USING (true);
            
        CREATE POLICY addresses_admin_all ON directory.addresses
            FOR ALL TO admin USING (true);
            
        -- Update foreign key references from other tables
        -- Update mail.letters foreign key constraint
        ALTER TABLE mail.letters DROP CONSTRAINT IF EXISTS fk_letter_sender_address;
        ALTER TABLE mail.letters ADD CONSTRAINT fk_letter_sender_address 
            FOREIGN KEY (sender_address_id) REFERENCES directory.addresses(id);
            
        -- Update mail.mailboxes foreign key constraint  
        ALTER TABLE mail.mailboxes DROP CONSTRAINT IF EXISTS fk_mailbox_address;
        ALTER TABLE mail.mailboxes ADD CONSTRAINT fk_mailbox_address 
            FOREIGN KEY (directory_address_id) REFERENCES directory.addresses(id);
        
        -- Update table and column comments
        COMMENT ON TABLE directory.addresses IS 'Addresses for entities and people in the directory';
        COMMENT ON COLUMN directory.addresses.id IS 'Unique identifier for the address';
        COMMENT ON COLUMN directory.addresses.entity_id IS 'Foreign key to directory.entities (XOR with person_id)';
        COMMENT ON COLUMN directory.addresses.person_id IS 'Foreign key to directory.people (XOR with entity_id)';
        COMMENT ON COLUMN directory.addresses.street IS 'Street address';
        COMMENT ON COLUMN directory.addresses.city IS 'City name';
        COMMENT ON COLUMN directory.addresses.state IS 'State or province';
        COMMENT ON COLUMN directory.addresses.zip IS 'ZIP or postal code';
        COMMENT ON COLUMN directory.addresses.country IS 'Country name';
        COMMENT ON COLUMN directory.addresses.is_verified IS 'Whether the address has been verified';
        COMMENT ON COLUMN directory.addresses.created_at IS 'Timestamp when the address was created';
        COMMENT ON COLUMN directory.addresses.updated_at IS 'Timestamp when the address was last updated';
    END IF;
END $$;
