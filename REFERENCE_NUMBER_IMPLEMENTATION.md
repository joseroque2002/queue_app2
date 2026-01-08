# Reference Number Implementation

## ✅ **What Was Added**

### 1. **Database Column** ✅
- Added `reference_number` column to `queue_entries` table
- Type: `VARCHAR(50) UNIQUE`
- Indexed for fast lookups
- Allows NULL for backward compatibility

### 2. **QueueEntry Model** ✅
- Added `referenceNumber` field (nullable String)
- Included in JSON serialization/deserialization
- Added to `copyWith()` method

### 3. **Reference Number Generation** ✅
- Automatic generation when creating queue entries
- Format: `REF-YYYYMMDD-DEPT-QQQQ-HHMMSS`
- Example: `REF-20240115-CAS-0001-143025`
- Components:
  - `REF-` prefix
  - Date: YYYYMMDD
  - Department code (e.g., CAS, COED)
  - Queue number (4 digits, zero-padded)
  - Time: HHMMSS

### 4. **Print Ticket/Receipt** ✅
- Reference number prominently displayed on printed tickets
- Shown in a highlighted box below the header
- Format: "Reference Number" label with the number below
- Easy to read and reference

### 5. **Excel Export** ✅
- Added "Reference Number" as the first column in Excel exports
- Makes it easy to identify and track records
- Shows "N/A" if reference number is missing (for old records)

### 6. **Records View** ✅
- Reference number displayed in record cards
- Shown with receipt icon
- Blue color for visibility
- Format: "Ref: REF-20240115-CAS-0001-143025"

## 📋 **SQL Script**

**File**: `ADD_REFERENCE_NUMBER_COLUMN.sql`

This script:
1. Adds the `reference_number` column (UNIQUE constraint)
2. Creates an index for fast lookups
3. Adds documentation comment
4. Verifies the column was added

### How to Apply:

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy and paste the contents of `ADD_REFERENCE_NUMBER_COLUMN.sql`
4. Run the script
5. Verify the column was added successfully

## 🎨 **Reference Number Format**

### Format Structure:
```
REF-YYYYMMDD-DEPT-QQQQ-HHMMSS
```

### Example:
```
REF-20240115-CAS-0001-143025
```

**Breakdown:**
- `REF-` - Prefix
- `20240115` - Date (January 15, 2024)
- `CAS` - Department code
- `0001` - Queue number (4 digits)
- `143025` - Time (14:30:25)

### Benefits:
✅ **Unique**: Combination of date, department, queue number, and time ensures uniqueness  
✅ **Readable**: Easy to understand and reference  
✅ **Traceable**: Can identify when and where the entry was created  
✅ **Sortable**: Chronological order by date/time

## 📊 **Display Locations**

### 1. **Print Ticket/Receipt**
- Position: Below header, above queue number
- Style: Highlighted box with label
- Format: "Reference Number" label + number

### 2. **Excel Export**
- Position: First column
- Header: "Reference Number"
- Format: Full reference number string

### 3. **Records View**
- Position: In record card details
- Style: Blue text with receipt icon
- Format: "Ref: REF-20240115-CAS-0001-143025"

## 🔧 **Files Modified**

1. ✅ `ADD_REFERENCE_NUMBER_COLUMN.sql` - NEW: Database migration script
2. ✅ `lib/models/queue_entry.dart` - Added referenceNumber field
3. ✅ `lib/services/supabase_service.dart` - Added generation function
4. ✅ `lib/services/print_service.dart` - Added to printed tickets
5. ✅ `lib/services/excel_export_service.dart` - Added to Excel exports
6. ✅ `lib/screens/records_view_screen.dart` - Added to record display

## ✨ **Benefits**

✅ **Unique Identification**: Each queue entry has a unique reference number  
✅ **Easy Tracking**: Users can reference their queue entry by number  
✅ **Receipt Proof**: Reference number serves as proof of queue entry  
✅ **Database Integrity**: UNIQUE constraint prevents duplicates  
✅ **Fast Lookups**: Indexed column for quick searches  
✅ **Professional**: Standard practice for queue/ticket systems

## 🚀 **Usage Examples**

### When Creating Queue Entry:
```
User submits form
→ System generates: REF-20240115-CAS-0001-143025
→ Stored in database
→ Displayed on receipt
```

### On Printed Receipt:
```
═══════════════════════════
        Queue Ticket       
═══════════════════════════

Reference Number
REF-20240115-CAS-0001-143025

Queue Number: #001
...
```

### In Excel Export:
```
Reference Number | Queue Number | Name | ...
REF-20240115-CAS-0001-143025 | 001 | Juan Dela Cruz | ...
```

## ⚠️ **Important Notes**

- **Automatic Generation**: Reference numbers are automatically generated when entries are created
- **Unique Constraint**: Database ensures no duplicate reference numbers
- **Backward Compatibility**: Existing records without reference numbers will show "N/A" in Excel
- **Format Consistency**: All reference numbers follow the same format for easy parsing
- **Indexed**: Fast lookups by reference number in the database

## 📝 **Next Steps**

1. **Run the SQL Script**:
   - Execute `ADD_REFERENCE_NUMBER_COLUMN.sql` in your Supabase SQL Editor
   - Verify the column was added successfully

2. **Test the Feature**:
   - Create a new queue entry
   - Verify reference number is generated
   - Check printed receipt shows reference number
   - Export to Excel and verify reference number column
   - View records and verify reference number display

3. **Update Existing Records (Optional)**:
   - If you want to add reference numbers to existing records, you can run an UPDATE query
   - However, this is optional as new entries will automatically have reference numbers


