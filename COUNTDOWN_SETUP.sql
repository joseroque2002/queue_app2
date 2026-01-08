-- Add countdown columns to existing queue_entries table
ALTER TABLE queue_entries 
ADD COLUMN IF NOT EXISTS countdown_start TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS countdown_duration INTEGER DEFAULT 30;

-- Update existing records to have default countdown duration
UPDATE queue_entries 
SET countdown_duration = 30 
WHERE countdown_duration IS NULL;

-- Add index for better performance on countdown queries
CREATE INDEX IF NOT EXISTS idx_queue_entries_countdown_start 
ON queue_entries(countdown_start);

-- Verify the changes
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'queue_entries' 
AND column_name IN ('countdown_start', 'countdown_duration')
ORDER BY column_name;
