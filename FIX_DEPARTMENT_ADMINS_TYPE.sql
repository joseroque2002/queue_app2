-- Fix department_admins table to use TEXT instead of UUID for admin_id
-- This script fixes the type mismatch between department_admins.admin_id (UUID) 
-- and admin_users.id (TEXT)

-- Drop the department_admins table if it exists with wrong type
DROP TABLE IF EXISTS department_admins CASCADE;

-- Recreate department_admins table with correct TEXT type for admin_id
CREATE TABLE IF NOT EXISTS department_admins (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    department_code VARCHAR(10) NOT NULL REFERENCES departments(code) ON DELETE CASCADE,
    admin_id TEXT NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'admin',
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(department_code, admin_id)
);

-- Create indexes for department_admins
CREATE INDEX IF NOT EXISTS idx_department_admins_dept ON department_admins(department_code);
CREATE INDEX IF NOT EXISTS idx_department_admins_admin ON department_admins(admin_id);

-- Verify the table was created correctly
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'department_admins'
ORDER BY ordinal_position;

-- Note: If you had existing data in department_admins, you'll need to re-insert it
-- after running this script, as the table was dropped and recreated.






