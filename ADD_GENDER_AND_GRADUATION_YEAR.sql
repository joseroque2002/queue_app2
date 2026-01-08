-- =====================================================
-- ADD GENDER AND GRADUATION YEAR COLUMNS
-- =====================================================
-- This script adds gender and graduation_year fields to the queue_entries table
-- 
-- Features:
-- - Gender field (Male, Female, Other, Prefer not to say)
-- - Graduation year field (only relevant if student_type = 'Graduated')
-- =====================================================

-- Add gender column to queue_entries table
DO $$
BEGIN
    -- Add gender column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'gender'
    ) THEN
        ALTER TABLE queue_entries ADD COLUMN gender TEXT;
        RAISE NOTICE 'Added gender column to queue_entries table';
    END IF;

    -- Add graduation_year column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'graduation_year'
    ) THEN
        ALTER TABLE queue_entries ADD COLUMN graduation_year INTEGER;
        RAISE NOTICE 'Added graduation_year column to queue_entries table';
    END IF;

    -- Add age column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'age'
    ) THEN
        ALTER TABLE queue_entries ADD COLUMN age INTEGER;
        RAISE NOTICE 'Added age column to queue_entries table';
    END IF;
END $$;

-- Add index for graduation_year for better query performance
CREATE INDEX IF NOT EXISTS idx_queue_entries_graduation_year 
ON queue_entries(graduation_year);

-- Add index for gender for better query performance
CREATE INDEX IF NOT EXISTS idx_queue_entries_gender 
ON queue_entries(gender);

-- Add index for age for better query performance
CREATE INDEX IF NOT EXISTS idx_queue_entries_age 
ON queue_entries(age);

-- Verify the changes
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'queue_entries' 
AND column_name IN ('gender', 'graduation_year', 'age')
ORDER BY column_name;

-- Show sample of updated table structure
SELECT 
    id,
    name,
    student_type,
    gender,
    age,
    graduation_year
FROM queue_entries 
LIMIT 5;

