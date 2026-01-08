# Supabase Setup Guide

## Prerequisites
1. Create a Supabase account at [https://supabase.com](https://supabase.com)
2. Create a new project

## Database Setup

### 1. Create Tables

Run these SQL commands in your Supabase SQL editor:

#### Queue Entries Table
```sql
CREATE TABLE queue_entries (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  ssu_id TEXT NOT NULL,
  email TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  department TEXT NOT NULL,
  purpose TEXT NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  queue_number INTEGER NOT NULL,
  status TEXT DEFAULT 'waiting'
);

-- Create indexes for better performance
CREATE INDEX idx_queue_entries_department ON queue_entries(department);
CREATE INDEX idx_queue_entries_status ON queue_entries(status);
CREATE INDEX idx_queue_entries_queue_number ON queue_entries(queue_number);
```

#### Admin Users Table
```sql
CREATE TABLE admin_users (
  id TEXT PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  department TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_admin_users_username ON admin_users(username);
CREATE INDEX idx_admin_users_department ON admin_users(department);
```

### 2. Insert Default Admin Users

```sql
INSERT INTO admin_users (id, username, password, department, name) VALUES
('admin_cas_001', 'admin_cas', 'admin123', 'CAS', 'CAS Administrator'),
('admin_coed_001', 'admin_coed', 'admin123', 'COED', 'COED Administrator'),
('admin_conhs_001', 'admin_conhs', 'admin123', 'CONHS', 'CONHS Administrator'),
('admin_coeng_001', 'admin_coeng', 'admin123', 'COENG', 'COENG Administrator'),
('admin_cit_001', 'admin_cit', 'admin123', 'CIT', 'CIT Administrator');
```

## App Configuration

### 1. Supabase Credentials Already Configured

The app has been configured with your Supabase credentials:
- **Project URL**: `https://imnnlmqcapiivnrsdwqq.supabase.co`
- **Anon Key**: Already set in the code

### 2. Get Your Credentials (for reference)

1. Go to your Supabase project dashboard
2. Click on "Settings" in the sidebar
3. Click on "API"
4. Copy the "Project URL" and "anon public" key

## Security Notes

- The anon key is safe to use in client-side code
- In production, consider implementing proper authentication
- The current setup uses plain text passwords - consider hashing in production
- Enable Row Level Security (RLS) if needed for multi-tenant scenarios

## Testing

1. Run `flutter pub get` to install dependencies
2. The Supabase configuration is already set up
3. Run the app and test the queue functionality
4. Check Supabase dashboard to see data being stored

## Troubleshooting

- Ensure your Supabase project is active
- Check that the tables are created correctly
- Verify the API keys are correct
- Check the Flutter console for any error messages
