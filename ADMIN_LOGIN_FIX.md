# Admin Login Fix Guide

## Problem
The admin users are not able to log in to the queue management system. This is likely due to one or more of the following issues:

1. **Database tables not created yet** - The `admin_users` table might not exist in your Supabase database
2. **Row Level Security (RLS) blocking access** - RLS policies might be preventing authentication
3. **Database connection issues** - The app might not be properly connecting to Supabase

## Solution

### Step 1: Create the Database Tables
1. Go to your Supabase project dashboard
2. Navigate to the SQL Editor
3. Copy and paste the contents of `SETUP_DATABASE.sql` into the editor
4. Run the script to create the tables and insert admin users

### Step 2: Verify Admin Users
After running the script, you should have these admin users:
- **CAS**: `admin_cas` / `admin123`
- **COED**: `admin_coed` / `admin123`
- **CONHS**: `admin_conhs` / `admin123`
- **COENG**: `admin_coeng` / `admin123`
- **CIT**: `admin_cit` / `admin123`

### Step 3: Test Database Connection
1. Run your Flutter app
2. Go to the Admin Login screen
3. Click the "Test Database Connection" button
4. Check the console output for any error messages

### Step 4: Try Logging In
Use one of the admin credentials above to log in. For example:
- Username: `admin_cas`
- Password: `admin123`

## Debugging

If you still can't log in:

1. **Check the console output** - Look for error messages when trying to authenticate
2. **Verify table existence** - Check if the `admin_users` table exists in your Supabase database
3. **Check RLS policies** - Ensure that the `anon` role has access to the tables
4. **Verify Supabase credentials** - Make sure your `supabaseUrl` and `supabaseAnonKey` are correct

## Common Issues

### Issue: "Table does not exist"
- **Solution**: Run the `SETUP_DATABASE.sql` script in your Supabase SQL editor

### Issue: "Permission denied"
- **Solution**: The script grants necessary permissions to the `anon` role. Make sure it ran successfully.

### Issue: "Invalid credentials"
- **Solution**: Double-check that you're using the exact username/password combinations from the script

### Issue: "Connection failed"
- **Solution**: Verify your Supabase project is active and the credentials in `supabase_config.dart` are correct

## Testing the Fix

1. Run the database setup script
2. Test the database connection using the button in the app
3. Try logging in with `admin_cas` / `admin123`
4. Check the console for any remaining error messages

If you continue to have issues, check the console output and Supabase logs for more specific error information.


