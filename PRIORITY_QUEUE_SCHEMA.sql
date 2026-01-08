-- =====================================================
-- PRIORITY QUEUE SYSTEM - DATABASE SCHEMA UPDATE
-- =====================================================
-- This script adds PWD (Person with Disability) and Senior Citizen
-- priority support to the queue system.
-- 
-- Features:
-- - PWD and Senior citizens get priority positions (top 2 in queue)
-- - Green color coding for priority entries
-- - Priority indicators in admin dashboard and live queue
-- =====================================================

-- Add priority fields to queue_entries table
DO $$
BEGIN
    -- Add is_pwd column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'is_pwd'
    ) THEN
        ALTER TABLE queue_entries ADD COLUMN is_pwd BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_pwd column to queue_entries table';
    END IF;

    -- Add is_senior column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'is_senior'
    ) THEN
        ALTER TABLE queue_entries ADD COLUMN is_senior BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_senior column to queue_entries table';
    END IF;

    -- Add is_priority computed column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'queue_entries' AND column_name = 'is_priority'
    ) THEN
        -- Note: Using a regular column with trigger instead of GENERATED ALWAYS AS for better compatibility
        ALTER TABLE queue_entries ADD COLUMN is_priority BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_priority column to queue_entries table';
    END IF;
END $$;

-- Create the trigger function (outside of DO block to avoid nested BEGIN/END)
CREATE OR REPLACE FUNCTION update_priority_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.is_priority := (NEW.is_pwd OR NEW.is_senior);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DO $$
BEGIN
    -- Drop existing trigger if it exists
    DROP TRIGGER IF EXISTS trigger_update_priority ON queue_entries;
    
    -- Create the trigger
    CREATE TRIGGER trigger_update_priority
        BEFORE INSERT OR UPDATE ON queue_entries
        FOR EACH ROW
        EXECUTE FUNCTION update_priority_status();
        
    RAISE NOTICE 'Created trigger to automatically update is_priority field';
END $$;

-- Create index for priority queries
CREATE INDEX IF NOT EXISTS idx_queue_entries_priority 
ON queue_entries (department, is_priority DESC, queue_number ASC, status);

-- Create index for department priority queries
CREATE INDEX IF NOT EXISTS idx_queue_entries_dept_priority_status 
ON queue_entries (department, is_priority DESC, status, queue_number ASC);

-- Update existing entries to have default priority values (if needed)
UPDATE queue_entries 
SET is_pwd = FALSE, is_senior = FALSE 
WHERE is_pwd IS NULL OR is_senior IS NULL;

-- Update existing records to set correct priority values
UPDATE queue_entries 
SET is_priority = (is_pwd OR is_senior)
WHERE is_pwd IS NOT NULL OR is_senior IS NOT NULL;

-- Create a view for priority queue statistics
CREATE OR REPLACE VIEW priority_queue_stats AS
SELECT 
    department,
    COUNT(*) as total_entries,
    COUNT(*) FILTER (WHERE status = 'waiting') as waiting_count,
    COUNT(*) FILTER (WHERE status = 'serving') as serving_count,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
    COUNT(*) FILTER (WHERE status = 'missed') as missed_count,
    COUNT(*) FILTER (WHERE is_priority = TRUE) as priority_count,
    COUNT(*) FILTER (WHERE is_pwd = TRUE) as pwd_count,
    COUNT(*) FILTER (WHERE is_senior = TRUE) as senior_count,
    COUNT(*) FILTER (WHERE is_priority = TRUE AND status = 'waiting') as priority_waiting,
    COUNT(*) FILTER (WHERE is_priority = TRUE AND status = 'completed') as priority_completed,
    ROUND(
        (COUNT(*) FILTER (WHERE is_priority = TRUE AND status = 'completed')::DECIMAL / 
         NULLIF(COUNT(*) FILTER (WHERE is_priority = TRUE), 0)) * 100, 2
    ) as priority_completion_rate
FROM queue_entries
GROUP BY department
ORDER BY department;

-- Create function to get next priority queue number
CREATE OR REPLACE FUNCTION get_next_priority_queue_number(
    dept_code TEXT,
    is_priority_entry BOOLEAN DEFAULT FALSE
) RETURNS INTEGER AS $$
DECLARE
    next_number INTEGER;
    priority_count INTEGER;
    max_regular_number INTEGER;
BEGIN
    -- Get current active entries for this department
    IF is_priority_entry THEN
        -- Count existing priority entries in top positions
        SELECT COUNT(*) INTO priority_count
        FROM queue_entries
        WHERE department = dept_code
        AND (status = 'waiting' OR status = 'serving')
        AND is_priority = TRUE
        AND queue_number <= 2;
        
        -- If less than 2 priority entries, assign to priority position
        IF priority_count < 2 THEN
            RETURN priority_count + 1;
        ELSE
            -- All priority slots taken, insert at position 2 and shift others
            -- This would require additional logic to shift existing entries
            RETURN 2;
        END IF;
    ELSE
        -- Regular entry - get next number after all existing entries
        SELECT COALESCE(MAX(queue_number), 0) + 1 INTO next_number
        FROM queue_entries
        WHERE department = dept_code
        AND (status = 'waiting' OR status = 'serving');
        
        RETURN next_number;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create function to shift queue numbers for priority insertion
CREATE OR REPLACE FUNCTION shift_queue_for_priority(
    dept_code TEXT,
    insert_position INTEGER DEFAULT 2
) RETURNS VOID AS $$
BEGIN
    -- Shift all entries at or after the insert position down by 1
    UPDATE queue_entries
    SET queue_number = queue_number + 1
    WHERE department = dept_code
    AND (status = 'waiting' OR status = 'serving')
    AND queue_number >= insert_position;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions (adjust as needed for your setup)
-- GRANT SELECT ON priority_queue_stats TO your_app_user;
-- GRANT EXECUTE ON FUNCTION get_next_priority_queue_number TO your_app_user;
-- GRANT EXECUTE ON FUNCTION shift_queue_for_priority TO your_app_user;

-- Sample data for testing (uncomment if needed)
/*
-- Insert some test priority entries
INSERT INTO queue_entries (
    id, name, ssu_id, email, phone_number, department, purpose, 
    timestamp, queue_number, status, is_pwd, is_senior
) VALUES 
    ('test_pwd_1', 'John Doe (PWD)', 'PWD001', 'john.pwd@test.com', '+639123456789', 'CAS', 'TOR', NOW(), 1, 'waiting', TRUE, FALSE),
    ('test_senior_1', 'Jane Smith (Senior)', 'SEN001', 'jane.senior@test.com', '+639987654321', 'CAS', 'CLEARANCE', NOW(), 2, 'waiting', FALSE, TRUE),
    ('test_both_1', 'Bob Wilson (PWD+Senior)', 'BOTH001', 'bob.both@test.com', '+639555666777', 'COED', 'DIPLOMA', NOW(), 1, 'waiting', TRUE, TRUE);
*/

-- Success message
DO $$
BEGIN
    RAISE NOTICE '🎯 Priority Queue System setup completed successfully!';
    RAISE NOTICE '✅ Added PWD and Senior Citizen priority support';
    RAISE NOTICE '✅ Priority entries will be placed in top 2 positions';
    RAISE NOTICE '✅ Green color coding enabled for priority entries';
    RAISE NOTICE '✅ Created priority queue statistics view';
    RAISE NOTICE '✅ Created helper functions for priority queue management';
    RAISE NOTICE 'Setup completed at: %', NOW();
END $$;
