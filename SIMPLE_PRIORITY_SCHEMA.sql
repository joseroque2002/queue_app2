-- =====================================================
-- SIMPLE PRIORITY QUEUE SYSTEM - DATABASE SCHEMA
-- =====================================================
-- This adds PWD/Senior priority support with display sorting
-- Queue numbers remain unchanged - priority is handled by sorting
-- =====================================================

-- Add PWD column if it doesn't exist
ALTER TABLE queue_entries ADD COLUMN IF NOT EXISTS is_pwd BOOLEAN DEFAULT FALSE;

-- Add Senior column if it doesn't exist  
ALTER TABLE queue_entries ADD COLUMN IF NOT EXISTS is_senior BOOLEAN DEFAULT FALSE;

-- Add priority column if it doesn't exist
ALTER TABLE queue_entries ADD COLUMN IF NOT EXISTS is_priority BOOLEAN DEFAULT FALSE;

-- Create the trigger function to automatically compute priority
CREATE OR REPLACE FUNCTION update_priority_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.is_priority := (COALESCE(NEW.is_pwd, FALSE) OR COALESCE(NEW.is_senior, FALSE));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_priority ON queue_entries;

-- Create the trigger
CREATE TRIGGER trigger_update_priority
    BEFORE INSERT OR UPDATE ON queue_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_priority_status();

-- Update existing records to set correct priority values
UPDATE queue_entries 
SET is_priority = (COALESCE(is_pwd, FALSE) OR COALESCE(is_senior, FALSE));

-- Create performance indexes for priority sorting
CREATE INDEX IF NOT EXISTS idx_queue_entries_priority_display 
ON queue_entries (department, is_priority DESC, queue_number ASC, status);

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Simple Priority Queue System setup completed!';
    RAISE NOTICE '✅ PWD and Senior users will be displayed in top positions';
    RAISE NOTICE '✅ Original queue numbers are preserved';
    RAISE NOTICE '✅ Priority is handled by display sorting (is_priority DESC, queue_number ASC)';
    RAISE NOTICE 'Setup completed at: %', NOW();
END $$;
