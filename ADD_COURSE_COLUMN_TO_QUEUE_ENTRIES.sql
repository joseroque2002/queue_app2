-- Add course column to queue_entries table
-- This script adds a course field to track which course the student belongs to

-- Add the course column to queue_entries table
ALTER TABLE queue_entries 
ADD COLUMN IF NOT EXISTS course VARCHAR(20);

-- Create an index on course for faster lookups
CREATE INDEX IF NOT EXISTS idx_queue_entries_course 
ON queue_entries(course);

-- Create composite index for department and course
CREATE INDEX IF NOT EXISTS idx_queue_entries_department_course 
ON queue_entries(department, course);

-- Add comment to the column for documentation
COMMENT ON COLUMN queue_entries.course IS 'Course code of the student (e.g., BSIT, BSCS)';

-- Add foreign key constraint to courses table (if courses table exists)
DO $$
BEGIN
    -- Check if courses table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'courses'
    ) THEN
        -- Check if the foreign key constraint already exists
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'fk_queue_entries_course' 
            AND table_name = 'queue_entries'
        ) THEN
            -- Add foreign key constraint
            ALTER TABLE queue_entries 
            ADD CONSTRAINT fk_queue_entries_course 
            FOREIGN KEY (course, department) 
            REFERENCES courses(code, department_code);
        END IF;
    END IF;
END $$;

-- Verify the column was added successfully
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'queue_entries' 
AND column_name = 'course';

-- Example query to see queue entries with course information
-- SELECT qe.*, c.name as course_name, d.name as department_name
-- FROM queue_entries qe
-- LEFT JOIN courses c ON qe.course = c.code AND qe.department = c.department_code
-- LEFT JOIN departments d ON qe.department = d.code
-- ORDER BY qe.timestamp DESC;






