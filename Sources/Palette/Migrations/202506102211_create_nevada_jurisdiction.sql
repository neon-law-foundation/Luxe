-- Create Nevada jurisdiction record

-- Insert Nevada jurisdiction record
INSERT INTO legal.jurisdictions (name, code) VALUES ('Nevada', 'NV')
ON CONFLICT (code) DO NOTHING;
