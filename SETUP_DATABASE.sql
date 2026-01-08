-- Database Setup Script for Queue Management System
-- Run this script in your Supabase SQL editor

-- Drop existing tables if they exist
DROP TABLE IF EXISTS queue_entries CASCADE;
DROP TABLE IF EXISTS admin_users CASCADE;

-- Create queue_entries table
CREATE TABLE public.queue_entries (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  ssu_id TEXT NOT NULL,
  email TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  department TEXT NOT NULL,
  purpose TEXT NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  queue_number INTEGER NOT NULL,
  status TEXT DEFAULT 'waiting',
  countdown_start TIMESTAMP WITH TIME ZONE,
  countdown_duration INTEGER DEFAULT 30
);

-- Create admin_users table
CREATE TABLE public.admin_users (
  id TEXT PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  department TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_queue_entries_department ON queue_entries(department);
CREATE INDEX idx_queue_entries_status ON queue_entries(status);
CREATE INDEX idx_queue_entries_queue_number ON queue_entries(queue_number);
CREATE INDEX idx_queue_entries_countdown_start ON queue_entries(countdown_start);
CREATE INDEX idx_admin_users_username ON admin_users(username);
CREATE INDEX idx_admin_users_department ON admin_users(department);

-- Insert default admin users
INSERT INTO public.admin_users (id, username, password, department, name) VALUES 
('admin_cas_001', 'admin_cas', 'admin123', 'CAS', 'CAS Administrator'),
('admin_coed_001', 'admin_coed', 'admin123', 'COED', 'COED Administrator'),
('admin_conhs_001', 'admin_conhs', 'admin123', 'CONHS', 'CONHS Administrator'),
('admin_coeng_001', 'admin_coeng', 'admin123', 'COENG', 'COENG Administrator'),
('admin_cit_001', 'admin_cit', 'admin123', 'CIT', 'CIT Administrator');

-- Grant necessary permissions to the anon role
GRANT ALL ON public.queue_entries TO anon;
GRANT ALL ON public.admin_users TO anon;
GRANT USAGE ON SCHEMA public TO anon;

-- Verify the tables were created correctly
SELECT table_name, column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name IN ('queue_entries', 'admin_users')
ORDER BY table_name, ordinal_position;

-- Verify admin users were inserted
SELECT * FROM public.admin_users;
