# Department/College Management System

This document describes the department/college management system that has been added to the queue management application.

## Overview

The department system allows the queue management application to handle multiple departments/colleges, each with their own admins and queue management capabilities. The system is designed to be flexible and scalable.

## Features

### 1. Department Model (`lib/models/department.dart`)
- **Department Entity**: Represents a college/department with the following properties:
  - `id`: Unique identifier
  - `code`: Short department code (e.g., 'CAS', 'COED')
  - `name`: Full department name (e.g., 'College of Arts and Sciences')
  - `description`: Detailed description of the department
  - `isActive`: Boolean flag to enable/disable departments
  - `createdAt`: Creation timestamp
  - `updatedAt`: Last update timestamp

### 2. Department Service (`lib/services/department_service.dart`)
- **Centralized Management**: Single service to manage all department operations
- **Default Departments**: Automatically initializes with 6 default departments:
  - CAS - College of Arts and Sciences
  - COED - College of Education
  - CONHS - College of Nursing and Health Sciences
  - COENG - College of Engineering
  - CIT - College of Industrial Technology
  - CGS - College of Graduating School

- **Key Methods**:
  - `getAllDepartments()`: Get all departments
  - `getActiveDepartments()`: Get only active departments
  - `getDepartmentByCode(code)`: Find department by code
  - `addDepartment()`: Add new department
  - `updateDepartment()`: Update existing department
  - `deleteDepartment()`: Soft delete (deactivate) department
  - `searchDepartments()`: Search departments by name/code

### 3. Enhanced Admin Service (`lib/services/admin_service.dart`)
- **Department Integration**: Admin service now works with the department service
- **Automatic Admin Creation**: Creates default admin accounts for each department
- **Department Validation**: Validates department codes when creating admins
- **Permission System**: Basic permission system for department management
- **Statistics**: Provides admin statistics by department

### 4. Enhanced Queue Service (`lib/services/queue_service.dart`)
- **Department Validation**: Validates department codes when adding queue entries
- **Department Statistics**: Provides detailed queue statistics by department
- **Department Information**: Methods to get department names and details

### 5. Department Management Screen (`lib/screens/department_management_screen.dart`)
- **Admin Interface**: Full admin interface for managing departments
- **Department Overview**: Statistics showing total, active, and inactive departments
- **CRUD Operations**: Add, edit, and deactivate departments
- **Admin Count**: Shows number of admins per department
- **Permission-Based Access**: Only certain admins can modify departments

### 6. Enhanced User Interfaces

#### Information Form Screen
- **Dynamic Department Dropdown**: Loads departments from the service
- **Department Names**: Shows both code and full name in dropdown
- **Validation**: Ensures selected department is active

#### View Queue Screen
- **Dynamic Layout**: Automatically adjusts to number of departments
- **Department Names**: Shows both code and full name for each department
- **Flexible Grid**: Supports any number of departments in a 2-column layout

#### Admin Screen
- **Department Management**: New menu item for department management
- **Department Context**: All operations are department-specific
- **Enhanced Navigation**: Easy access to department management features

## Database Schema

### Departments Table
```sql
CREATE TABLE departments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Foreign Key Relationships
- `queue_entries.department` → `departments.code`
- `admin_users.department` → `departments.code`

### Department Statistics View
```sql
CREATE VIEW department_stats AS
SELECT 
    d.code,
    d.name,
    d.is_active,
    COUNT(DISTINCT qe.id) as total_queue_entries,
    COUNT(DISTINCT CASE WHEN qe.status = 'waiting' THEN qe.id END) as waiting_count,
    -- ... more statistics
FROM departments d
LEFT JOIN queue_entries qe ON d.code = qe.department
LEFT JOIN admin_users au ON d.code = au.department
GROUP BY d.code, d.name, d.is_active;
```

## Usage

### For Administrators

1. **Access Department Management**:
   - Login as admin
   - Navigate to "Departments" in the admin menu
   - View department overview and statistics

2. **Add New Department**:
   - Click "Add Department" button
   - Enter department code (e.g., 'CBAA')
   - Enter full name (e.g., 'College of Business Administration and Accountancy')
   - Add description
   - Save

3. **Manage Existing Departments**:
   - Edit department information
   - Activate/deactivate departments
   - View admin count per department

### For Users

1. **Queue Registration**:
   - Select department from dropdown (shows code and name)
   - System validates department is active
   - Queue entry is created with department association

2. **Live Queue Display**:
   - View queues for all active departments
   - See department codes and full names
   - Real-time updates for all departments

## Configuration

### Default Departments
The system comes with 6 pre-configured departments. To modify:

1. Edit `DepartmentService.initializeDefaultDepartments()`
2. Update the default departments list
3. Run the application to initialize

### Permissions
Currently, department modification is restricted to CAS admins. To change:

1. Edit `AdminService.canModifyDepartments`
2. Implement your permission logic
3. Consider adding role-based permissions

## API Integration

### Supabase Integration
The system is designed to work with Supabase. To set up:

1. Run the SQL commands in `DEPARTMENT_SCHEMA.sql`
2. Update your Supabase policies as needed
3. Ensure proper permissions for department operations

### Local Development
For local development, the system uses in-memory storage through the service classes.

## Future Enhancements

### Planned Features
1. **Role-Based Permissions**: More granular permission system
2. **Department Hierarchies**: Support for sub-departments
3. **Department-Specific Settings**: Custom settings per department
4. **Reporting**: Advanced reporting by department
5. **Import/Export**: Bulk department management

### Extensibility
The system is designed to be extensible:
- Add new department properties by extending the Department model
- Implement custom validation rules in DepartmentService
- Add department-specific business logic as needed

## Troubleshooting

### Common Issues

1. **Department Not Found**: Ensure department code exists and is active
2. **Permission Denied**: Check admin permissions for department operations
3. **Foreign Key Errors**: Ensure departments exist before creating queue entries or admins

### Debug Information
Enable debug logging to see department operations:
```dart
print('Department operation: ${operation}');
```

## Migration Guide

### From Hardcoded Departments
If upgrading from a system with hardcoded departments:

1. Run the department initialization
2. Verify all existing queue entries have valid department codes
3. Update any hardcoded department references
4. Test all department-related functionality

### Database Migration
1. Backup your existing data
2. Run `DEPARTMENT_SCHEMA.sql`
3. Verify foreign key constraints
4. Test department operations

## Support

For issues or questions about the department system:
1. Check the troubleshooting section
2. Review the code comments in service files
3. Verify database schema is correctly applied
4. Test with the default departments first

## Conclusion

The department/college management system provides a flexible foundation for managing multiple departments in the queue system. It maintains backward compatibility while adding powerful new features for department-specific operations and administration.
