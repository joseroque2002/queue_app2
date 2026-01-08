-- Add is_pregnant column to queue_entries table
-- This allows pregnant women to be marked as priority in the queue system

-- Add is_pregnant column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' 
        AND column_name = 'is_pregnant'
    ) THEN
        ALTER TABLE public.queue_entries 
        ADD COLUMN is_pregnant BOOLEAN NOT NULL DEFAULT FALSE;
        
        -- Create index for better query performance
        CREATE INDEX IF NOT EXISTS idx_queue_entries_is_pregnant 
        ON public.queue_entries(is_pregnant) 
        TABLESPACE pg_default;
        
        RAISE NOTICE 'Column is_pregnant added successfully';
    ELSE
        RAISE NOTICE 'Column is_pregnant already exists';
    END IF;
END $$;

-- Update the is_priority trigger/function to include is_pregnant
-- Note: If you have a trigger that automatically sets is_priority, update it to include is_pregnant
-- Example: is_priority = is_pwd OR is_senior OR is_pregnant

-- Verify the column was added
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'queue_entries' 
AND column_name = 'is_pregnant';






