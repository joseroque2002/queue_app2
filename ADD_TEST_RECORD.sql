-- Add a test record to the queue_entries table
-- Run this in your Supabase SQL editor to add a sample record for testing

INSERT INTO queue_entries (
    id,
    name,
    ssu_id,
    email,
    phone_number,
    department,
    purpose,
    timestamp,
    queue_number,
    status,
    countdown_duration,
    is_pwd,
    is_senior,
    is_priority
) VALUES (
    gen_random_uuid(),
    'Test User',
    'TEST001',
    'test@example.com',
    '1234567890',
    'CAS',
    'Testing Excel Export',
    NOW(),
    1,
    'waiting',
    30,
    false,
    false,
    false
);

-- Verify the record was added
SELECT * FROM queue_entries WHERE name = 'Test User';
