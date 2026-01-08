-- ALTER TABLE script to add student_type column to queue_entries table
-- This adds a field to track whether the person is a "Student" or "Graduated"
-- This script is idempotent - safe to run multiple times

-- Drop the constraint if it exists (to allow re-running the script)
ALTER TABLE queue_entries 
DROP CONSTRAINT IF EXISTS check_student_type;

-- Add the student_type column (if it doesn't exist)
ALTER TABLE queue_entries 
ADD COLUMN IF NOT EXISTS student_type VARCHAR(50) DEFAULT 'Student';

-- Add a check constraint to ensure only valid values
ALTER TABLE queue_entries 
ADD CONSTRAINT check_student_type 
CHECK (student_type IN ('Student', 'Graduated'));

-- Update existing records to have default value if they don't have one
UPDATE queue_entries 
SET student_type = 'Student' 
WHERE student_type IS NULL;

-- Add comment to the column for documentation
COMMENT ON COLUMN queue_entries.student_type IS 'Indicates whether the person is a Student or Graduated';

-- Verify the column was added successfully
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'queue_entries' 
AND column_name = 'student_type';

