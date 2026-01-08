-- =====================================================
-- FIX PRIORITY COLUMN - DATABASE REPAIR SCRIPT
-- =====================================================
-- This script fixes the is_priority column issue by removing
-- the GENERATED ALWAYS constraint and replacing it with a trigger
-- =====================================================

-- Step 1: Create or replace the trigger function first
CREATE OR REPLACE FUNCTION update_priority_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.is_priority := (NEW.is_pwd OR NEW.is_senior);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Handle column and trigger creation
DO $$
BEGIN
    -- Check if is_priority column exists and is a generated column
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' 
        AND column_name = 'is_priority'
        AND is_generated = 'ALWAYS'
    ) THEN
        -- Drop the generated column
        ALTER TABLE queue_entries DROP COLUMN is_priority;
        RAISE NOTICE 'Dropped generated is_priority column';
    END IF;

    -- Add regular is_priority column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'is_priority'
    ) THEN
        ALTER TABLE queue_entries ADD COLUMN is_priority BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added regular is_priority column';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error occurred: %', SQLERRM;
        RAISE NOTICE 'You may need to manually drop the is_priority column and re-run this script';
END $$;

-- Step 3: Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_priority ON queue_entries;

-- Step 4: Create the trigger
CREATE TRIGGER trigger_update_priority
    BEFORE INSERT OR UPDATE ON queue_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_priority_status();

-- Step 5: Update existing records
DO $$
BEGIN
    -- Update existing records to set correct priority values
    UPDATE queue_entries 
    SET is_priority = (is_pwd OR is_senior)
    WHERE is_pwd IS NOT NULL OR is_senior IS NOT NULL;

    RAISE NOTICE 'Updated existing records with correct priority values';
    RAISE NOTICE 'Created trigger to automatically update is_priority field';
END $$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Priority column fix completed successfully!';
    RAISE NOTICE '✅ is_priority is now a regular column with automatic trigger updates';
    RAISE NOTICE '✅ Existing records have been updated';
    RAISE NOTICE 'Fix completed at: %', NOW();
END $$;
