-- Check if there are any records in the queue_entries table
-- Run this in your Supabase SQL editor to see what's in the database

-- Check total count of records
SELECT COUNT(*) as total_records FROM queue_entries;

-- Check records by status
SELECT status, COUNT(*) as count 
FROM queue_entries 
GROUP BY status 
ORDER BY count DESC;

-- Check records by department
SELECT department, COUNT(*) as count 
FROM queue_entries 
GROUP BY department 
ORDER BY count DESC;

-- Show sample records (first 5)
SELECT 
    id,
    name,
    email,
    phone_number,
    department,
    purpose,
    queue_number,
    status,
    is_pwd,
    is_senior,
    is_priority,
    timestamp
FROM queue_entries 
ORDER BY timestamp DESC 
LIMIT 5;

-- Check if the table structure is correct
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'queue_entries' 
ORDER BY ordinal_position;


