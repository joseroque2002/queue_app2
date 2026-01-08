-- SQL Script to Add CGS (College of Graduating School) to Supabase Tables
-- Run these commands in your Supabase SQL Editor

-- ============================================================================
-- 1. CREATE DEPARTMENTS TABLE (if it doesn't exist)
-- ============================================================================

CREATE TABLE IF NOT EXISTS departments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_departments_code ON departments(code);
CREATE INDEX IF NOT EXISTS idx_departments_active ON departments(is_active);

-- ============================================================================
-- 2. INSERT CGS DEPARTMENT (and other departments if they don't exist)
-- ============================================================================

INSERT INTO departments (code, name, description, is_active) VALUES
('CAS', 'College of Arts and Sciences', 'Liberal arts, sciences, and humanities programs', TRUE),
('COED', 'College of Education', 'Teacher education and educational programs', TRUE),
('CONHS', 'College of Nursing and Health Sciences', 'Nursing and health-related programs', TRUE),
('COENG', 'College of Engineering', 'Engineering and technology programs', TRUE),
('CIT', 'College of Industrial Technology', 'Industrial technology and technical programs', TRUE),
('CGS', 'College of Graduating School', 'Graduate studies and advanced degree programs', TRUE)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- ============================================================================
-- 3. ALTER EXISTING TABLES TO ADD FOREIGN KEY CONSTRAINTS
-- ============================================================================

-- Add foreign key constraint to queue_entries table (if it exists)
DO $$
BEGIN
    -- Check if queue_entries table exists
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'queue_entries') THEN
        -- Check if the foreign key constraint doesn't already exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'fk_queue_entries_department' 
            AND table_name = 'queue_entries'
        ) THEN
            -- Add foreign key constraint
            ALTER TABLE queue_entries 
            ADD CONSTRAINT fk_queue_entries_department 
            FOREIGN KEY (department) REFERENCES departments(code);
            
            RAISE NOTICE 'Added foreign key constraint to queue_entries table';
        ELSE
            RAISE NOTICE 'Foreign key constraint already exists on queue_entries table';
        END IF;
    ELSE
        RAISE NOTICE 'queue_entries table does not exist yet';
    END IF;
END $$;

-- Add foreign key constraint to admin_users table (if it exists)
DO $$
BEGIN
    -- Check if admin_users table exists
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'admin_users') THEN
        -- Check if the foreign key constraint doesn't already exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'fk_admin_users_department' 
            AND table_name = 'admin_users'
        ) THEN
            -- Add foreign key constraint
            ALTER TABLE admin_users 
            ADD CONSTRAINT fk_admin_users_department 
            FOREIGN KEY (department) REFERENCES departments(code);
            
            RAISE NOTICE 'Added foreign key constraint to admin_users table';
        ELSE
            RAISE NOTICE 'Foreign key constraint already exists on admin_users table';
        END IF;
    ELSE
        RAISE NOTICE 'admin_users table does not exist yet';
    END IF;
END $$;

-- ============================================================================
-- 4. CREATE CGS ADMIN USER (if admin_users table exists)
-- ============================================================================

DO $$
BEGIN
    -- Check if admin_users table exists
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'admin_users') THEN
        -- Insert CGS admin user
        INSERT INTO admin_users (id, username, password, department, name, created_at) VALUES
        (gen_random_uuid(), 'admin_cgs', 'admin123', 'CGS', 'CGS Admin', NOW())
        ON CONFLICT (username) DO UPDATE SET
            password = EXCLUDED.password,
            department = EXCLUDED.department,
            name = EXCLUDED.name,
            created_at = EXCLUDED.created_at;
        
        RAISE NOTICE 'CGS admin user created/updated successfully';
    ELSE
        RAISE NOTICE 'admin_users table does not exist - CGS admin will be created when table is available';
    END IF;
END $$;

-- ============================================================================
-- 5. CREATE DEPARTMENT STATISTICS VIEW
-- ============================================================================

CREATE OR REPLACE VIEW department_stats AS
SELECT 
    d.code,
    d.name,
    d.description,
    d.is_active,
    COALESCE(qe_stats.total_queue_entries, 0) as total_queue_entries,
    COALESCE(qe_stats.waiting_count, 0) as waiting_count,
    COALESCE(qe_stats.current_count, 0) as current_count,
    COALESCE(qe_stats.completed_count, 0) as completed_count,
    COALESCE(qe_stats.missed_count, 0) as missed_count,
    COALESCE(admin_stats.admin_count, 0) as admin_count,
    d.created_at,
    d.updated_at
FROM departments d
LEFT JOIN (
    SELECT 
        department,
        COUNT(*) as total_queue_entries,
        COUNT(CASE WHEN status = 'waiting' THEN 1 END) as waiting_count,
        COUNT(CASE WHEN status = 'current' THEN 1 END) as current_count,
        COUNT(CASE WHEN status = 'completed' OR status = 'done' THEN 1 END) as completed_count,
        COUNT(CASE WHEN status = 'missed' THEN 1 END) as missed_count
    FROM queue_entries
    WHERE EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'queue_entries')
    GROUP BY department
) qe_stats ON d.code = qe_stats.department
LEFT JOIN (
    SELECT 
        department,
        COUNT(*) as admin_count
    FROM admin_users
    WHERE EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'admin_users')
    GROUP BY department
) admin_stats ON d.code = admin_stats.department
ORDER BY d.code;

-- ============================================================================
-- 6. CREATE FUNCTION TO UPDATE TIMESTAMPS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for departments table
DROP TRIGGER IF EXISTS update_departments_updated_at ON departments;
CREATE TRIGGER update_departments_updated_at
    BEFORE UPDATE ON departments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 7. VERIFICATION QUERIES
-- ============================================================================

-- Check if CGS department was created successfully
SELECT 'CGS Department Check' as check_type, 
       CASE WHEN EXISTS (SELECT 1 FROM departments WHERE code = 'CGS') 
            THEN '✅ CGS department exists' 
            ELSE '❌ CGS department missing' 
       END as result;

-- Show all departments
SELECT 'All Departments' as info, code, name, is_active FROM departments ORDER BY code;

-- Check if CGS admin exists (if admin_users table exists)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'admin_users') THEN
        RAISE NOTICE 'CGS Admin Check: %', 
            CASE WHEN EXISTS (SELECT 1 FROM admin_users WHERE username = 'admin_cgs') 
                 THEN '✅ CGS admin exists' 
                 ELSE '❌ CGS admin missing' 
            END;
    ELSE
        RAISE NOTICE 'admin_users table does not exist yet';
    END IF;
END $$;

-- Show department statistics
SELECT * FROM department_stats;

-- ============================================================================
-- 8. EXAMPLE QUERIES FOR TESTING
-- ============================================================================

-- Example: Get all queue entries for CGS department
-- SELECT * FROM queue_entries WHERE department = 'CGS';

-- Example: Get CGS admin user
-- SELECT * FROM admin_users WHERE department = 'CGS';

-- Example: Get department statistics for CGS
-- SELECT * FROM department_stats WHERE code = 'CGS';

-- Example: Add a test queue entry for CGS
-- INSERT INTO queue_entries (name, ssu_id, email, phone_number, department, purpose, timestamp, queue_number, status)
-- VALUES ('Test Student', 'CGS001', 'test@cgs.edu', '+639123456789', 'CGS', 'DIPLOMA', NOW(), 1, 'waiting');

-- ============================================================================
-- 9. FINAL SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '🎓 CGS Department setup completed successfully!';
    RAISE NOTICE 'CGS Admin Login: username=admin_cgs, password=admin123';
    RAISE NOTICE 'Department Code: CGS';
    RAISE NOTICE 'Department Name: College of Graduating School';
    RAISE NOTICE 'Setup completed at: %', NOW();
END $$;
