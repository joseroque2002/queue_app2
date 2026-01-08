# Priority Queue System Implementation

## Overview
Successfully implemented a priority queue system for PWD (Person with Disability) and Senior Citizens (60+ years old) in the queue management application.

## Features Implemented

### 1. **Priority Queue Logic**
- PWD and Senior Citizens get priority positions in the top 2 spots of each department queue
- Priority entries are automatically assigned to positions 1-2
- When priority slots are full, new priority entries shift existing queue positions
- Regular entries are assigned after all priority entries

### 2. **User Interface Enhancements**

#### Information Form (`lib/screens/information_form_screen.dart`)
- Added PWD and Senior Citizen checkboxes in a dedicated "Priority Queue" section
- Green-themed priority section with clear instructions
- Dynamic feedback showing priority status when selected
- Updated success message to display priority information

#### Live Queue Display (`lib/screens/view_queue_screen.dart`)
- **Green color coding** for all priority entries (PWD/Senior)
- Priority icons: 
  - 🦽 for PWD
  - 👴 for Senior Citizens  
  - 🦽 for both PWD & Senior
- Visual distinction from regular blue entries

#### Admin Dashboard (`lib/screens/admin_screen.dart`)
- Green background for priority queue entries
- Priority icons in queue number badges
- Priority type information in person details
- Priority status in queue list items

### 3. **Data Model Updates**

#### QueueEntry Model (`lib/models/queue_entry.dart`)
```dart
final bool isPwd;           // Person with Disability flag
final bool isSenior;        // Senior Citizen flag  
final bool isPriority;      // Computed: isPwd || isSenior
String get priorityType;    // Returns "PWD", "Senior", "PWD & Senior", or "Regular"
String get priorityColor;   // Returns green for priority, blue for regular
```

### 4. **Backend Services**

#### SupabaseService (`lib/services/supabase_service.dart`)
- Updated `addQueueEntry()` to accept `isPwd` and `isSenior` parameters
- Implemented `_getNextQueueNumberWithPriority()` for smart queue positioning
- Added `_shiftQueueForPriority()` to handle queue reorganization
- Priority logic ensures top 2 positions are reserved for PWD/Senior

#### Print Service (`lib/services/print_service.dart`)
- Enhanced ticket printing with priority indicators
- Shows priority type and special messaging for priority users
- Updated all print methods (console, thermal, text formats)

### 5. **Database Schema**

#### New Fields Added (`PRIORITY_QUEUE_SCHEMA.sql`)
```sql
ALTER TABLE queue_entries ADD COLUMN is_pwd BOOLEAN DEFAULT FALSE;
ALTER TABLE queue_entries ADD COLUMN is_senior BOOLEAN DEFAULT FALSE;
ALTER TABLE queue_entries ADD COLUMN is_priority BOOLEAN GENERATED ALWAYS AS (is_pwd OR is_senior) STORED;
```

#### Database Features
- Computed `is_priority` column for efficient queries
- Optimized indexes for priority-based sorting
- Priority queue statistics view
- Helper functions for queue management

### 6. **Priority Queue Rules**

1. **Position Assignment:**
   - Priority entries: Positions 1-2 (top of queue)
   - Regular entries: Position 3+ (after priority entries)

2. **Priority Hierarchy:**
   - PWD + Senior: Highest priority
   - PWD only: High priority  
   - Senior only: High priority
   - Regular: Standard priority

3. **Queue Behavior:**
   - Maximum 2 priority positions per department
   - When priority slots full, new priority entries shift queue
   - Maintains chronological order within priority levels

### 7. **Visual Indicators**

#### Color Scheme
- 🟢 **Green**: Priority entries (PWD/Senior)
- 🔵 **Blue**: Regular entries
- 🟠 **Orange**: Current/serving entries
- 🔴 **Red**: Missed entries

#### Icons
- 🦽 `Icons.accessible_rounded`: PWD
- 👴 `Icons.elderly_rounded`: Senior Citizen
- 🦽 `Icons.accessible_forward_rounded`: PWD + Senior

### 8. **User Experience**

#### For Priority Users
- Clear priority section in registration form
- Immediate feedback about priority status
- Priority indicators on printed tickets
- Green visual coding throughout system
- Special messaging about priority access

#### For Staff/Admins
- Easy identification of priority entries
- Priority information in all admin views
- Green color coding for quick recognition
- Priority type details in person information

## Files Modified

### Core Models
- `lib/models/queue_entry.dart` - Added priority fields and helper methods

### User Interface
- `lib/screens/information_form_screen.dart` - Priority checkboxes and UI
- `lib/screens/view_queue_screen.dart` - Green color coding and icons
- `lib/screens/admin_screen.dart` - Priority indicators and information

### Services
- `lib/services/supabase_service.dart` - Priority queue logic
- `lib/services/print_service.dart` - Priority ticket information

### Database
- `PRIORITY_QUEUE_SCHEMA.sql` - Database schema updates

## Implementation Benefits

1. **Accessibility Compliance**: Supports PWD and Senior Citizens as required by law
2. **Clear Visual Feedback**: Green color coding makes priority status obvious
3. **Efficient Queue Management**: Smart positioning algorithm ensures priority access
4. **Comprehensive Coverage**: Priority indicators throughout entire system
5. **Database Optimized**: Efficient queries with proper indexing
6. **User-Friendly**: Clear UI with helpful messaging and icons

## Usage Instructions

### For Users
1. Fill out the registration form
2. Check "Person with Disability" if applicable
3. Check "Senior Citizen" if 60+ years old
4. Submit form - priority users automatically get top 2 positions
5. Printed ticket shows priority status

### For Admins
- Priority entries appear with green background
- Priority icons show in queue number badges
- Priority type information displayed in person details
- Easy to identify and serve priority customers first

## Technical Notes

- Priority queue logic handles edge cases (full priority slots, queue shifting)
- Database constraints ensure data integrity
- Computed columns optimize query performance
- Color coding follows accessibility guidelines
- Icons provide universal visual language

The priority queue system is now fully operational and provides excellent support for PWD and Senior Citizens while maintaining an efficient queue management system for all users.



