-- Course Management Schema for Queue System
-- This file contains SQL commands to create and manage course tables

-- Create courses table
CREATE TABLE IF NOT EXISTS courses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code VARCHAR(20) NOT NULL,
    name VARCHAR(255) NOT NULL,
    department_code VARCHAR(10) NOT NULL,
    description TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Ensure unique course code per department
    UNIQUE(code, department_code)
);

-- Create index on course code for faster lookups
CREATE INDEX IF NOT EXISTS idx_courses_code ON courses(code);
CREATE INDEX IF NOT EXISTS idx_courses_department ON courses(department_code);
CREATE INDEX IF NOT EXISTS idx_courses_active ON courses(is_active);
CREATE INDEX IF NOT EXISTS idx_courses_department_active ON courses(department_code, is_active);

-- Add foreign key constraint to departments table
DO $$
BEGIN
    -- Check if the foreign key constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_courses_department' 
        AND table_name = 'courses'
    ) THEN
        -- Add foreign key constraint
        ALTER TABLE courses 
        ADD CONSTRAINT fk_courses_department 
        FOREIGN KEY (department_code) REFERENCES departments(code) ON DELETE CASCADE;
    END IF;
END $$;

-- Add comment to the table for documentation
COMMENT ON TABLE courses IS 'Courses/Programs offered by each department';
COMMENT ON COLUMN courses.code IS 'Course code (e.g., BSIT, BSCS)';
COMMENT ON COLUMN courses.name IS 'Full course name';
COMMENT ON COLUMN courses.department_code IS 'Foreign key to departments table';

-- Insert default courses for each department
INSERT INTO courses (code, name, department_code, description, is_active) VALUES
-- CAS Courses
('BSIT', 'Bachelor of Science in Information Technology', 'CAS', 'Information Technology program', TRUE),
('BSCS', 'Bachelor of Science in Computer Science', 'CAS', 'Computer Science program', TRUE),
('BSMATH', 'Bachelor of Science in Mathematics', 'CAS', 'Mathematics program', TRUE),
('BSBIO', 'Bachelor of Science in Biology', 'CAS', 'Biology program', TRUE),
('BSCHEM', 'Bachelor of Science in Chemistry', 'CAS', 'Chemistry program', TRUE),

-- COED Courses
('BSE', 'Bachelor of Secondary Education', 'COED', 'Secondary Education program', TRUE),
('BEE', 'Bachelor of Elementary Education', 'COED', 'Elementary Education program', TRUE),
('BSPED', 'Bachelor of Special Education', 'COED', 'Special Education program', TRUE),

-- CONHS Courses
('BSN', 'Bachelor of Science in Nursing', 'CONHS', 'Nursing program', TRUE),
('BSMT', 'Bachelor of Science in Medical Technology', 'CONHS', 'Medical Technology program', TRUE),

-- COENG Courses
('BSCE', 'Bachelor of Science in Civil Engineering', 'COENG', 'Civil Engineering program', TRUE),
('BSEE', 'Bachelor of Science in Electrical Engineering', 'COENG', 'Electrical Engineering program', TRUE),
('BSME', 'Bachelor of Science in Mechanical Engineering', 'COENG', 'Mechanical Engineering program', TRUE),
('BSIE', 'Bachelor of Science in Industrial Engineering', 'COENG', 'Industrial Engineering program', TRUE),

-- CIT Courses
('BSIT-CIT', 'Bachelor of Science in Information Technology', 'CIT', 'IT program under CIT', TRUE),
('BSCS-CIT', 'Bachelor of Science in Computer Science', 'CIT', 'CS program under CIT', TRUE),

-- CGS Courses
('MSIT', 'Master of Science in Information Technology', 'CGS', 'Graduate IT program', TRUE),
('MSCS', 'Master of Science in Computer Science', 'CGS', 'Graduate CS program', TRUE),
('MBA', 'Master of Business Administration', 'CGS', 'Business Administration program', TRUE)
ON CONFLICT (code, department_code) DO NOTHING;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_courses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_courses_updated_at ON courses;
CREATE TRIGGER update_courses_updated_at
    BEFORE UPDATE ON courses
    FOR EACH ROW
    EXECUTE FUNCTION update_courses_updated_at();

-- Create view for course statistics
CREATE OR REPLACE VIEW course_stats AS
SELECT 
    c.code,
    c.name,
    c.department_code,
    d.name as department_name,
    c.is_active,
    COUNT(DISTINCT qe.id) as total_queue_entries,
    COUNT(DISTINCT CASE WHEN qe.status = 'waiting' THEN qe.id END) as waiting_count,
    COUNT(DISTINCT CASE WHEN qe.status = 'current' THEN qe.id END) as current_count,
    COUNT(DISTINCT CASE WHEN qe.status = 'completed' THEN qe.id END) as completed_count
FROM courses c
LEFT JOIN departments d ON c.department_code = d.code
LEFT JOIN queue_entries qe ON c.code = qe.course AND c.department_code = qe.department
GROUP BY c.code, c.name, c.department_code, d.name, c.is_active
ORDER BY c.department_code, c.code;

-- Grant necessary permissions (adjust as needed for your setup)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON courses TO your_app_user;
-- GRANT SELECT ON course_stats TO your_app_user;

-- Example queries for course management:

-- Get all active courses
-- SELECT * FROM courses WHERE is_active = TRUE ORDER BY department_code, code;

-- Get courses for a specific department
-- SELECT * FROM courses WHERE department_code = 'CAS' AND is_active = TRUE ORDER BY code;

-- Get course statistics
-- SELECT * FROM course_stats WHERE department_code = 'CAS';

-- Add a new course
-- INSERT INTO courses (code, name, department_code, description) 
-- VALUES ('BSIS', 'Bachelor of Science in Information Systems', 'CAS', 'Information Systems program');

-- Deactivate a course
-- UPDATE courses SET is_active = FALSE WHERE code = 'OLD_COURSE' AND department_code = 'CAS';

-- Update course information
-- UPDATE courses 
-- SET name = 'Updated Course Name', description = 'Updated description' 
-- WHERE code = 'BSIT' AND department_code = 'CAS';






