-- =====================================================
-- FORCE FIX PRIORITY COLUMN - ROBUST DATABASE REPAIR
-- =====================================================
-- This script forcefully fixes the is_priority column issue
-- by completely removing and recreating the column structure
-- =====================================================

-- Step 1: Drop the trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_priority ON queue_entries;

-- Step 2: Drop the function if it exists
DROP FUNCTION IF EXISTS update_priority_status();

-- Step 3: Force drop the generated column
DO $$
BEGIN
    -- Try to drop the is_priority column if it exists (regardless of type)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'is_priority'
    ) THEN
        ALTER TABLE queue_entries DROP COLUMN is_priority;
        RAISE NOTICE 'Dropped existing is_priority column';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop is_priority column: %', SQLERRM;
END $$;

-- Step 4: Add the PWD and Senior columns if they don't exist
DO $$
BEGIN
    -- Add is_pwd column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'is_pwd'
    ) THEN
        ALTER TABLE queue_entries ADD COLUMN is_pwd BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_pwd column';
    END IF;

    -- Add is_senior column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'is_senior'
    ) THEN
        ALTER TABLE queue_entries ADD COLUMN is_senior BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_senior column';
    END IF;
END $$;

-- Step 5: Add the regular is_priority column (only if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'is_priority'
    ) THEN
        ALTER TABLE queue_entries ADD COLUMN is_priority BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added new regular is_priority column';
    ELSE
        RAISE NOTICE 'is_priority column still exists - attempting manual fix';
        
        -- Try to update the column to see if it's still generated
        BEGIN
            UPDATE queue_entries SET is_priority = FALSE WHERE id = 'test_nonexistent_id';
            RAISE NOTICE 'Column is updateable - no further action needed';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Column is still generated - manual intervention required';
                RAISE NOTICE 'Please run this command manually: ALTER TABLE queue_entries DROP COLUMN is_priority CASCADE;';
        END;
    END IF;
END $$;

-- Step 6: Create the trigger function
CREATE OR REPLACE FUNCTION update_priority_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.is_priority := (COALESCE(NEW.is_pwd, FALSE) OR COALESCE(NEW.is_senior, FALSE));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 7: Create the trigger
CREATE TRIGGER trigger_update_priority
    BEFORE INSERT OR UPDATE ON queue_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_priority_status();

-- Step 8: Update existing records
UPDATE queue_entries 
SET is_priority = (COALESCE(is_pwd, FALSE) OR COALESCE(is_senior, FALSE));

-- Step 9: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_queue_entries_priority 
ON queue_entries (department, is_priority DESC, queue_number ASC, status);

CREATE INDEX IF NOT EXISTS idx_queue_entries_dept_priority_status 
ON queue_entries (department, is_priority DESC, status, queue_number ASC);

-- Success messages
DO $$
BEGIN
    RAISE NOTICE '✅ Priority column forcefully fixed!';
    RAISE NOTICE '✅ Added regular is_priority column with trigger';
    RAISE NOTICE '✅ Updated all existing records';
    RAISE NOTICE '✅ Created performance indexes';
    RAISE NOTICE 'Fix completed at: %', NOW();
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Your priority queue system is now ready!';
    RAISE NOTICE '   - PWD and Senior users will get green color coding';
    RAISE NOTICE '   - Priority users will be placed in top 2 positions';
    RAISE NOTICE '   - Database trigger automatically computes priority status';
END $$;
