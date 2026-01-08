# Database Priority Column Fix

## Issue
The application was failing with the error:
```
PostgrestException(message: cannot insert a non-DEFAULT value into column "is_priority", code: 428C9, details: Column "is_priority" is a generated column., hint: null)
```

## Root Cause
The `is_priority` column was created as a `GENERATED ALWAYS AS (is_pwd OR is_senior) STORED` column, which means:
1. PostgreSQL automatically computes the value
2. Applications cannot insert values into this column directly
3. The Flutter app was trying to send `is_priority` in the JSON payload

## Solution Applied

### 1. **Database Schema Fix**
- Replaced `GENERATED ALWAYS AS` column with a regular `BOOLEAN` column
- Added a database trigger to automatically compute `is_priority` value
- This allows the application to work while maintaining automatic computation

### 2. **Updated Schema (`PRIORITY_QUEUE_SCHEMA.sql`)**
```sql
-- Instead of GENERATED ALWAYS AS column:
ALTER TABLE queue_entries ADD COLUMN is_priority BOOLEAN DEFAULT FALSE;

-- Added trigger function:
CREATE OR REPLACE FUNCTION update_priority_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.is_priority := (NEW.is_pwd OR NEW.is_senior);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Added trigger:
CREATE TRIGGER trigger_update_priority
    BEFORE INSERT OR UPDATE ON queue_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_priority_status();
```

### 3. **Application Code Fix**
- Removed `is_priority` from JSON output in `QueueEntry.toJson()`
- The field is still computed in Dart for UI purposes
- Database trigger handles the database-level computation

### 4. **Quick Fix Script**
Created `FIX_PRIORITY_COLUMN.sql` for immediate database repair:
- Drops the problematic generated column
- Adds regular column with trigger
- Updates existing records

## Files Modified

### Database Scripts
- `PRIORITY_QUEUE_SCHEMA.sql` - Updated main schema
- `FIX_PRIORITY_COLUMN.sql` - Quick fix for existing databases

### Application Code  
- `lib/models/queue_entry.dart` - Removed `is_priority` from JSON output

## How to Apply the Fix

### Option 1: For New Databases
Run the updated `PRIORITY_QUEUE_SCHEMA.sql` script

### Option 2: For Existing Databases with the Issue
Run the `FIX_PRIORITY_COLUMN.sql` script to fix the column

## Benefits of the New Approach

1. **Application Compatibility**: Flutter app can insert records normally
2. **Automatic Computation**: Database still computes priority automatically
3. **Data Integrity**: Trigger ensures `is_priority` is always correct
4. **Performance**: Indexed column for fast priority queries
5. **Flexibility**: Can be easily modified if business rules change

## Testing
After applying the fix:
- ✅ Queue entries can be inserted successfully
- ✅ Priority status is computed automatically
- ✅ Priority queue logic works correctly
- ✅ UI displays priority indicators properly

The database error has been completely resolved while maintaining all priority queue functionality.



