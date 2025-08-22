DO $$
BEGIN
    -- Update the choices column to store JSON objects instead of arrays
    -- Convert existing array values to objects with 'options' key
    UPDATE standards.questions 
    SET choices = jsonb_build_object('options', choices)
    WHERE jsonb_typeof(choices) = 'array';

    -- Update the default value for new records
    ALTER TABLE standards.questions 
    ALTER COLUMN choices SET DEFAULT '{"options": []}'::JSONB;

    -- Update the comment to reflect the new format
    COMMENT ON COLUMN standards.questions.choices IS 'JSON object with options array for select/radio/multi_select types';
END $$;
