-- =====================================================
-- MANUAL PRIORITY COLUMN FIX - STEP BY STEP
-- =====================================================
-- Run these commands ONE BY ONE in your Supabase SQL editor
-- =====================================================

-- STEP 1: Drop the generated column with CASCADE
-- This removes the column and any dependencies
ALTER TABLE queue_entries DROP COLUMN is_priority CASCADE;

-- STEP 2: Add PWD column if needed
ALTER TABLE queue_entries ADD COLUMN IF NOT EXISTS is_pwd BOOLEAN DEFAULT FALSE;

-- STEP 3: Add Senior column if needed  
ALTER TABLE queue_entries ADD COLUMN IF NOT EXISTS is_senior BOOLEAN DEFAULT FALSE;

-- STEP 4: Add regular priority column
ALTER TABLE queue_entries ADD COLUMN is_priority BOOLEAN DEFAULT FALSE;

-- STEP 5: Create the trigger function
CREATE OR REPLACE FUNCTION update_priority_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.is_priority := (COALESCE(NEW.is_pwd, FALSE) OR COALESCE(NEW.is_senior, FALSE));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- STEP 6: Create the trigger
CREATE TRIGGER trigger_update_priority
    BEFORE INSERT OR UPDATE ON queue_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_priority_status();

-- STEP 7: Update existing records
UPDATE queue_entries 
SET is_priority = (COALESCE(is_pwd, FALSE) OR COALESCE(is_senior, FALSE));

-- STEP 8: Create performance indexes
CREATE INDEX IF NOT EXISTS idx_queue_entries_priority 
ON queue_entries (department, is_priority DESC, queue_number ASC, status);

-- STEP 9: Verify the fix worked
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default,
    is_generated
FROM information_schema.columns 
WHERE table_name = 'queue_entries' 
AND column_name IN ('is_pwd', 'is_senior', 'is_priority')
ORDER BY column_name;

-- Success message
SELECT '✅ Priority queue system is now ready!' as status;



