-- Update queue_entries table schema to match the provided structure
-- This script ensures course is NOT NULL and adds all necessary indexes

-- First, update existing NULL course values to a default value (if any exist)
-- You may want to set a default course code here
UPDATE public.queue_entries 
SET course = 'N/A' 
WHERE course IS NULL;

-- Make course column NOT NULL
DO $$
BEGIN
    -- Check if course column exists and is nullable
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' 
        AND column_name = 'course'
        AND is_nullable = 'YES'
    ) THEN
        -- First, ensure no NULL values exist
        UPDATE public.queue_entries 
        SET course = 'N/A' 
        WHERE course IS NULL;
        
        -- Then make it NOT NULL
        ALTER TABLE public.queue_entries 
        ALTER COLUMN course SET NOT NULL;
        
        RAISE NOTICE 'Course column updated to NOT NULL';
    ELSE
        RAISE NOTICE 'Course column already NOT NULL or does not exist';
    END IF;
END $$;

-- Ensure is_pregnant column exists (from previous migration)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' 
        AND column_name = 'is_pregnant'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD COLUMN is_pregnant BOOLEAN NOT NULL DEFAULT FALSE;
        
        CREATE INDEX IF NOT EXISTS idx_queue_entries_is_pregnant 
        ON public.queue_entries(is_pregnant) 
        TABLESPACE pg_default;
        
        RAISE NOTICE 'is_pregnant column added';
    ELSE
        RAISE NOTICE 'is_pregnant column already exists';
    END IF;
END $$;

-- Create/update indexes for course
CREATE INDEX IF NOT EXISTS idx_queue_entries_course 
ON public.queue_entries USING btree (course) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_queue_entries_department_course 
ON public.queue_entries USING btree (department, course) 
TABLESPACE pg_default;

-- Create/update priority display index
CREATE INDEX IF NOT EXISTS idx_queue_entries_priority_display 
ON public.queue_entries USING btree (
  department,
  is_priority DESC,
  queue_number,
  status
) TABLESPACE pg_default;

-- Verify the course column constraint
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'queue_entries' 
AND column_name = 'course';






