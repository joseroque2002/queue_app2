-- Department Management Schema for Queue System
-- This file contains SQL commands to create and manage department tables

-- Create departments table
CREATE TABLE IF NOT EXISTS public.departments (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    code CHARACTER VARYING(10) NOT NULL,
    name CHARACTER VARYING(255) NOT NULL,
    description TEXT NULL DEFAULT ''::text,
    is_active BOOLEAN NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT NOW(),
    CONSTRAINT departments_pkey PRIMARY KEY (id),
    CONSTRAINT departments_code_key UNIQUE (code)
) TABLESPACE pg_default;

-- Create index on department code for faster lookups
CREATE INDEX IF NOT EXISTS idx_departments_code ON public.departments USING btree (code) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_departments_active ON public.departments USING btree (is_active) TABLESPACE pg_default;

-- Insert default departments
INSERT INTO public.departments (code, name, description, is_active) VALUES
('CAS', 'College of Arts and Sciences', 'Liberal arts, sciences, and humanities programs', TRUE),
('COED', 'College of Education', 'Teacher education and educational programs', TRUE),
('CONHS', 'College of Nursing and Health Sciences', 'Nursing and health-related programs', TRUE),
('COENG', 'College of Engineering', 'Engineering and technology programs', TRUE),
('CIT', 'College of Industrial Technology', 'Industrial technology and technical programs', TRUE),
('CGS', 'College of Graduating School', 'Graduate studies and advanced degree programs', TRUE),
('CIN', 'College of Institute Medicine', 'Medical and healthcare institute programs', TRUE)
ON CONFLICT (code) DO NOTHING;

-- Update existing queue_entries table to reference departments table
-- First, ensure all existing departments in queue_entries are added to departments table
DO $$
DECLARE
    existing_dept TEXT;
BEGIN
    -- Insert any existing department values from queue_entries that don't exist in departments
    FOR existing_dept IN 
        SELECT DISTINCT department 
        FROM queue_entries 
        WHERE department IS NOT NULL 
        AND department NOT IN (SELECT code FROM public.departments)
    LOOP
        INSERT INTO public.departments (code, name, description, is_active)
        VALUES (existing_dept, 'Auto-created from existing queue entries', 'Auto-created department', TRUE)
        ON CONFLICT (code) DO NOTHING;
    END LOOP;
END $$;

-- Now add the foreign key constraint if it doesn't exist
DO $$
BEGIN
    -- Check if the foreign key constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_queue_entries_department' 
        AND table_name = 'queue_entries'
    ) THEN
        -- Add foreign key constraint
        ALTER TABLE public.queue_entries 
        ADD CONSTRAINT fk_queue_entries_department 
        FOREIGN KEY (department) REFERENCES public.departments(code);
    END IF;
END $$;

-- Update existing admin_users table to reference departments table
-- First, ensure all existing departments in admin_users are added to departments table
DO $$
DECLARE
    existing_dept TEXT;
BEGIN
    -- Insert any existing department values from admin_users that don't exist in departments
    -- Handle 'ALL' special case for master admin - create a special department entry
    IF NOT EXISTS (SELECT 1 FROM public.departments WHERE code = 'ALL') THEN
        INSERT INTO public.departments (code, name, description, is_active)
        VALUES ('ALL', 'All Departments', 'Master admin access to all departments', TRUE)
        ON CONFLICT (code) DO NOTHING;
    END IF;
    
    -- Insert any other existing department values from admin_users that don't exist in departments
    FOR existing_dept IN 
        SELECT DISTINCT department 
        FROM admin_users 
        WHERE department IS NOT NULL 
        AND department != 'ALL'
        AND department NOT IN (SELECT code FROM public.departments)
    LOOP
        INSERT INTO public.departments (code, name, description, is_active)
        VALUES (existing_dept, 'Auto-created from existing admin users', 'Auto-created department', TRUE)
        ON CONFLICT (code) DO NOTHING;
    END LOOP;
END $$;

-- Now add the foreign key constraint if it doesn't exist
DO $$
BEGIN
    -- Check if the foreign key constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_admin_users_department' 
        AND table_name = 'admin_users'
    ) THEN
        -- Add foreign key constraint
        ALTER TABLE public.admin_users 
        ADD CONSTRAINT fk_admin_users_department 
        FOREIGN KEY (department) REFERENCES public.departments(code);
    END IF;
END $$;

-- Create department_admins table for many-to-many relationship (if needed in future)
-- Note: admin_id uses TEXT to match admin_users.id type
CREATE TABLE IF NOT EXISTS public.department_admins (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    department_code CHARACTER VARYING(10) NOT NULL REFERENCES public.departments(code) ON DELETE CASCADE,
    admin_id TEXT NOT NULL REFERENCES public.admin_users(id) ON DELETE CASCADE,
    role CHARACTER VARYING(50) NULL DEFAULT 'admin',
    assigned_at TIMESTAMP WITH TIME ZONE NULL DEFAULT NOW(),
    CONSTRAINT department_admins_pkey PRIMARY KEY (id),
    CONSTRAINT department_admins_department_code_admin_id_key UNIQUE (department_code, admin_id)
) TABLESPACE pg_default;

-- Create indexes for department_admins
CREATE INDEX IF NOT EXISTS idx_department_admins_dept ON public.department_admins USING btree (department_code) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_department_admins_admin ON public.department_admins USING btree (admin_id) TABLESPACE pg_default;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_departments_updated_at ON public.departments;
CREATE TRIGGER update_departments_updated_at
    BEFORE UPDATE ON public.departments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Drop existing view if it exists (to avoid conflicts with column changes)
DROP VIEW IF EXISTS public.department_stats CASCADE;

-- Create view for department statistics
CREATE VIEW public.department_stats AS
SELECT 
    d.code,
    d.name,
    d.is_active,
    COUNT(DISTINCT qe.id) as total_queue_entries,
    COUNT(DISTINCT CASE WHEN qe.status = 'waiting' THEN qe.id END) as waiting_count,
    COUNT(DISTINCT CASE WHEN qe.status = 'current' THEN qe.id END) as current_count,
    COUNT(DISTINCT CASE WHEN qe.status = 'done' THEN qe.id END) as completed_count,
    COUNT(DISTINCT CASE WHEN qe.status = 'missed' THEN qe.id END) as missed_count,
    COUNT(DISTINCT CASE WHEN qe.status = 'cancelled' THEN qe.id END) as cancelled_count,
    COUNT(DISTINCT au.id) as admin_count
FROM public.departments d
LEFT JOIN public.queue_entries qe ON d.code = qe.department
LEFT JOIN public.admin_users au ON d.code = au.department
GROUP BY d.code, d.name, d.is_active
ORDER BY d.code;

-- Grant necessary permissions (adjust as needed for your setup)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON public.departments TO your_app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON public.department_admins TO your_app_user;
-- GRANT SELECT ON public.department_stats TO your_app_user;

-- Example queries for department management:

-- Get all active departments
-- SELECT * FROM public.departments WHERE is_active = TRUE ORDER BY code;

-- Get department statistics
-- SELECT * FROM public.department_stats;

-- Get queue entries for a specific department
-- SELECT qe.*, d.name as department_name 
-- FROM public.queue_entries qe 
-- JOIN public.departments d ON qe.department = d.code 
-- WHERE d.code = 'CAS' AND qe.status IN ('waiting', 'current');

-- Get admins for a specific department
-- SELECT au.*, d.name as department_name 
-- FROM public.admin_users au 
-- JOIN public.departments d ON au.department = d.code 
-- WHERE d.code = 'CAS';

-- Add a new department
-- INSERT INTO public.departments (code, name, description) 
-- VALUES ('CBAA', 'College of Business Administration and Accountancy', 'Business and accounting programs');

-- Deactivate a department
-- UPDATE public.departments SET is_active = FALSE WHERE code = 'OLD_DEPT';

-- Update department information
-- UPDATE public.departments 
-- SET name = 'Updated College Name', description = 'Updated description' 
-- WHERE code = 'CAS';
