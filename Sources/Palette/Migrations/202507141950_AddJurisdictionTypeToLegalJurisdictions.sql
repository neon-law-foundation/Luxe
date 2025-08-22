-- Add jurisdiction_type enum and column to legal.jurisdictions table

-- Create jurisdiction_type enum if it doesn't exist
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'jurisdiction_type') THEN
        CREATE TYPE legal.jurisdiction_type AS ENUM ('city', 'county', 'state', 'country');
    END IF;
END $$;

-- Add comment for the enum type
COMMENT ON TYPE legal.jurisdiction_type IS 'Type of legal jurisdiction: city, county, state, or country';

-- Add jurisdiction_type column to legal.jurisdictions table
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'legal' 
        AND table_name = 'jurisdictions' 
        AND column_name = 'jurisdiction_type'
    ) THEN
        ALTER TABLE legal.jurisdictions 
        ADD COLUMN jurisdiction_type legal.jurisdiction_type NOT NULL DEFAULT 'state';
    END IF;
EXCEPTION
    WHEN duplicate_column THEN
        -- Column already exists, this is fine
        NULL;
END $$;

-- Add column comment
COMMENT ON COLUMN legal.jurisdictions.jurisdiction_type IS
'Type of jurisdiction (city, county, state, country) with default value of state';
