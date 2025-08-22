-- Create birth data tables in the ethereal schema
-- These tables store birth information for astrocartography calculations

-- Create birth_locations table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'ethereal'
        AND table_name = 'birth_locations'
    ) THEN
        CREATE TABLE ethereal.birth_locations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            latitude DECIMAL(10, 6) NOT NULL,
            longitude DECIMAL(10, 6) NOT NULL,
            city VARCHAR(255) NOT NULL,
            state VARCHAR(255),
            country VARCHAR(255) NOT NULL,
            timezone VARCHAR(100) NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            
            -- Constraints for valid coordinates
            CONSTRAINT chk_birth_locations_latitude CHECK (latitude >= -90 AND latitude <= 90),
            CONSTRAINT chk_birth_locations_longitude CHECK (longitude >= -180 AND longitude <= 180)
        );
        
        -- Create indexes for performance
        CREATE INDEX idx_birth_locations_coordinates ON ethereal.birth_locations(latitude, longitude);
        CREATE INDEX idx_birth_locations_city_country ON ethereal.birth_locations(city, country);
        
        -- Add comments
        COMMENT ON TABLE ethereal.birth_locations IS 'Stores geographic locations for birth data';
        COMMENT ON COLUMN ethereal.birth_locations.latitude IS 'Latitude in decimal degrees (-90 to 90)';
        COMMENT ON COLUMN ethereal.birth_locations.longitude IS 'Longitude in decimal degrees (-180 to 180)';
        COMMENT ON COLUMN ethereal.birth_locations.timezone IS 'IANA timezone identifier (e.g., America/Los_Angeles)';
    END IF;
END $$;

-- Create birth_date_times table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'ethereal'
        AND table_name = 'birth_date_times'
    ) THEN
        CREATE TABLE ethereal.birth_date_times (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            birth_date DATE NOT NULL,
            birth_time TIME NOT NULL,
            hour SMALLINT NOT NULL,
            minute SMALLINT NOT NULL,
            second SMALLINT NOT NULL,
            timezone VARCHAR(100) NOT NULL,
            is_daylight_saving BOOLEAN NOT NULL DEFAULT false,
            utc_offset INTEGER NOT NULL,
            utc_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            
            -- Constraints for valid time components
            CONSTRAINT chk_birth_date_times_hour CHECK (hour >= 0 AND hour <= 23),
            CONSTRAINT chk_birth_date_times_minute CHECK (minute >= 0 AND minute <= 59),
            CONSTRAINT chk_birth_date_times_second CHECK (second >= 0 AND second <= 59),
            CONSTRAINT chk_birth_date_times_utc_offset CHECK (utc_offset >= -12 AND utc_offset <= 14)
        );
        
        -- Create indexes for performance
        CREATE INDEX idx_birth_date_times_birth_date ON ethereal.birth_date_times(birth_date);
        CREATE INDEX idx_birth_date_times_utc_timestamp ON ethereal.birth_date_times(utc_timestamp);
        
        -- Add comments
        COMMENT ON TABLE ethereal.birth_date_times IS 'Stores precise birth date and time information';
        COMMENT ON COLUMN ethereal.birth_date_times.birth_time IS 'Local birth time';
        COMMENT ON COLUMN ethereal.birth_date_times.utc_offset IS 'UTC offset in hours at time of birth';
        COMMENT ON COLUMN ethereal.birth_date_times.utc_timestamp IS 'Birth time converted to UTC';
    END IF;
END $$;

-- Create birth_data table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'ethereal'
        AND table_name = 'birth_data'
    ) THEN
        CREATE TABLE ethereal.birth_data (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL,
            location_id UUID NOT NULL,
            date_time_id UUID NOT NULL,
            notes TEXT,
            is_verified BOOLEAN DEFAULT false,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp NOT NULL,
            
            -- Foreign key constraints
            CONSTRAINT fk_birth_data_user
                FOREIGN KEY (user_id)
                REFERENCES auth.users(id)
                ON DELETE CASCADE,
            CONSTRAINT fk_birth_data_location
                FOREIGN KEY (location_id)
                REFERENCES ethereal.birth_locations(id)
                ON DELETE RESTRICT,
            CONSTRAINT fk_birth_data_date_time
                FOREIGN KEY (date_time_id)
                REFERENCES ethereal.birth_date_times(id)
                ON DELETE RESTRICT,
                
            -- Ensure one birth record per user
            CONSTRAINT uq_birth_data_user_id UNIQUE (user_id)
        );
        
        -- Create indexes for performance
        CREATE INDEX idx_birth_data_user_id ON ethereal.birth_data(user_id);
        CREATE INDEX idx_birth_data_location_id ON ethereal.birth_data(location_id);
        CREATE INDEX idx_birth_data_date_time_id ON ethereal.birth_data(date_time_id);
        
        -- Add comments
        COMMENT ON TABLE ethereal.birth_data IS 'Main table linking users to their birth information';
        COMMENT ON COLUMN ethereal.birth_data.is_verified IS 'Whether the birth data has been verified by the user';
        COMMENT ON COLUMN ethereal.birth_data.notes IS 'Optional notes about birth circumstances';
    END IF;
END $$;

-- Create updated_at trigger for birth_locations
DO $$ BEGIN
    CREATE OR REPLACE FUNCTION ethereal.update_birth_locations_updated_at()
    RETURNS TRIGGER AS $func$
    BEGIN
        NEW.updated_at = current_timestamp;
        RETURN NEW;
    END;
    $func$ LANGUAGE plpgsql;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_birth_locations_updated_at'
    ) THEN
        CREATE TRIGGER update_birth_locations_updated_at
            BEFORE UPDATE ON ethereal.birth_locations
            FOR EACH ROW
            EXECUTE FUNCTION ethereal.update_birth_locations_updated_at();
    END IF;
END $$;

-- Create updated_at trigger for birth_date_times
DO $$ BEGIN
    CREATE OR REPLACE FUNCTION ethereal.update_birth_date_times_updated_at()
    RETURNS TRIGGER AS $func$
    BEGIN
        NEW.updated_at = current_timestamp;
        RETURN NEW;
    END;
    $func$ LANGUAGE plpgsql;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_birth_date_times_updated_at'
    ) THEN
        CREATE TRIGGER update_birth_date_times_updated_at
            BEFORE UPDATE ON ethereal.birth_date_times
            FOR EACH ROW
            EXECUTE FUNCTION ethereal.update_birth_date_times_updated_at();
    END IF;
END $$;

-- Create updated_at trigger for birth_data
DO $$ BEGIN
    CREATE OR REPLACE FUNCTION ethereal.update_birth_data_updated_at()
    RETURNS TRIGGER AS $func$
    BEGIN
        NEW.updated_at = current_timestamp;
        RETURN NEW;
    END;
    $func$ LANGUAGE plpgsql;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_birth_data_updated_at'
    ) THEN
        CREATE TRIGGER update_birth_data_updated_at
            BEFORE UPDATE ON ethereal.birth_data
            FOR EACH ROW
            EXECUTE FUNCTION ethereal.update_birth_data_updated_at();
    END IF;
END $$;

-- Row Level Security (RLS) for birth_locations
ALTER TABLE ethereal.birth_locations ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for birth_locations
DO $$ BEGIN
    -- Customer can view all birth locations (they're not sensitive)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_locations' AND policyname = 'birth_locations_customer_select'
    ) THEN
        CREATE POLICY birth_locations_customer_select ON ethereal.birth_locations
            FOR SELECT TO customer
            USING (true);
    END IF;

    -- Staff can view all birth locations
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_locations' AND policyname = 'birth_locations_staff_select'
    ) THEN
        CREATE POLICY birth_locations_staff_select ON ethereal.birth_locations
            FOR SELECT TO staff
            USING (true);
    END IF;

    -- Admin can do everything with birth locations
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_locations' AND policyname = 'birth_locations_admin_all'
    ) THEN
        CREATE POLICY birth_locations_admin_all ON ethereal.birth_locations
            FOR ALL TO admin
            USING (true);
    END IF;
END $$;

-- Row Level Security (RLS) for birth_date_times
ALTER TABLE ethereal.birth_date_times ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for birth_date_times
DO $$ BEGIN
    -- Customer can only view their own birth date times (through birth_data)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_date_times' AND policyname = 'birth_date_times_customer_select'
    ) THEN
        CREATE POLICY birth_date_times_customer_select ON ethereal.birth_date_times
            FOR SELECT TO customer
            USING (
                EXISTS (
                    SELECT 1 FROM ethereal.birth_data bd
                    JOIN auth.users u ON u.id = bd.user_id
                    WHERE bd.date_time_id = birth_date_times.id
                    AND u.username = current_setting('app.current_user_username', true)
                )
            );
    END IF;

    -- Staff can view all birth date times
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_date_times' AND policyname = 'birth_date_times_staff_select'
    ) THEN
        CREATE POLICY birth_date_times_staff_select ON ethereal.birth_date_times
            FOR SELECT TO staff
            USING (true);
    END IF;

    -- Admin can do everything with birth date times
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_date_times' AND policyname = 'birth_date_times_admin_all'
    ) THEN
        CREATE POLICY birth_date_times_admin_all ON ethereal.birth_date_times
            FOR ALL TO admin
            USING (true);
    END IF;
END $$;

-- Row Level Security (RLS) for birth_data
ALTER TABLE ethereal.birth_data ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for birth_data
DO $$ BEGIN
    -- Customer can view only their own birth data
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_data' AND policyname = 'birth_data_customer_select'
    ) THEN
        CREATE POLICY birth_data_customer_select ON ethereal.birth_data
            FOR SELECT TO customer
            USING (
                EXISTS (
                    SELECT 1 FROM auth.users u
                    WHERE u.id = birth_data.user_id
                    AND u.username = current_setting('app.current_user_username', true)
                )
            );
    END IF;

    -- Customer can insert only their own birth data
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_data' AND policyname = 'birth_data_customer_insert'
    ) THEN
        CREATE POLICY birth_data_customer_insert ON ethereal.birth_data
            FOR INSERT TO customer
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM auth.users u
                    WHERE u.id = birth_data.user_id
                    AND u.username = current_setting('app.current_user_username', true)
                )
            );
    END IF;

    -- Customer can update only their own birth data
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_data' AND policyname = 'birth_data_customer_update'
    ) THEN
        CREATE POLICY birth_data_customer_update ON ethereal.birth_data
            FOR UPDATE TO customer
            USING (
                EXISTS (
                    SELECT 1 FROM auth.users u
                    WHERE u.id = birth_data.user_id
                    AND u.username = current_setting('app.current_user_username', true)
                )
            )
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM auth.users u
                    WHERE u.id = birth_data.user_id
                    AND u.username = current_setting('app.current_user_username', true)
                )
            );
    END IF;

    -- Customer can delete only their own birth data
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_data' AND policyname = 'birth_data_customer_delete'
    ) THEN
        CREATE POLICY birth_data_customer_delete ON ethereal.birth_data
            FOR DELETE TO customer
            USING (
                EXISTS (
                    SELECT 1 FROM auth.users u
                    WHERE u.id = birth_data.user_id
                    AND u.username = current_setting('app.current_user_username', true)
                )
            );
    END IF;

    -- Staff can view all birth data
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_data' AND policyname = 'birth_data_staff_select'
    ) THEN
        CREATE POLICY birth_data_staff_select ON ethereal.birth_data
            FOR SELECT TO staff
            USING (true);
    END IF;

    -- Admin can do everything with birth data
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'ethereal' AND tablename = 'birth_data' AND policyname = 'birth_data_admin_all'
    ) THEN
        CREATE POLICY birth_data_admin_all ON ethereal.birth_data
            FOR ALL TO admin
            USING (true);
    END IF;
END $$;

-- Grant table permissions
DO $$ BEGIN
    -- Grant permissions to customer role
    GRANT SELECT ON ethereal.birth_locations TO customer;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ethereal.birth_date_times TO customer;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ethereal.birth_data TO customer;
    
    -- Grant permissions to staff role
    GRANT SELECT ON ethereal.birth_locations TO staff;
    GRANT SELECT ON ethereal.birth_date_times TO staff;
    GRANT SELECT ON ethereal.birth_data TO staff;
    
    -- Grant permissions to admin role
    GRANT ALL ON ethereal.birth_locations TO admin;
    GRANT ALL ON ethereal.birth_date_times TO admin;
    GRANT ALL ON ethereal.birth_data TO admin;
EXCEPTION
    WHEN undefined_object THEN
        -- Roles might not exist in test environment
        NULL;
END $$;
