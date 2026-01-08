-- ALTER TABLE script to add reference_number column to queue_entries table
-- This adds a unique reference number for each queue entry (for receipts/tickets)
-- This script is idempotent - safe to run multiple times

-- Add the reference_number column
ALTER TABLE queue_entries 
ADD COLUMN IF NOT EXISTS reference_number VARCHAR(50) UNIQUE;

-- Create an index on reference_number for faster lookups
CREATE INDEX IF NOT EXISTS idx_queue_entries_reference_number 
ON queue_entries(reference_number);

-- Add comment to the column for documentation
COMMENT ON COLUMN queue_entries.reference_number IS 'Unique reference number for the queue entry (displayed on receipt/ticket)';

-- Verify the column was added successfully
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'queue_entries' 
AND column_name = 'reference_number';


