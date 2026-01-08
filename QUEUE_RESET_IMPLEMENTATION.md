# Queue Reset Implementation with Purpose-Based Graph Updates

## Overview
The queue management system now supports intelligent reset functionality that:
- Resets queue numbers based on different purposes
- Updates graphs and charts automatically after reset
- Provides department-specific or global reset options
- Maintains reset history and statistics

## Reset Purposes Available

### **1. Routine Resets**
- **Daily**: Reset queue every day (morning reset)
- **Weekly**: Reset queue every week (Monday reset)
- **Monthly**: Reset queue every month (1st of month)

### **2. Special Resets**
- **Emergency**: Emergency situations requiring immediate reset
- **Maintenance**: System maintenance or technical issues
- **Department**: Reset specific department only
- **General**: Manual reset for any reason

## Implementation Methods

### **Core Reset Methods**

#### **1. `resetQueueWithPurpose()`**
```dart
// Reset all departments with daily purpose
final result = await supabaseService.resetQueueWithPurpose(
  purpose: 'daily',
  resetGraphs: true,
);

// Reset specific department with emergency purpose
final result = await supabaseService.resetQueueWithPurpose(
  purpose: 'emergency',
  department: 'CAS',
  resetGraphs: true,
);
```

#### **2. `resetAndGetFreshGraphData()`**
```dart
// Complete reset with fresh graph data
final result = await supabaseService.resetAndGetFreshGraphData(
  purpose: 'weekly',
  department: 'COED',
);
```

#### **3. `resetQueueByStatus()`**
```dart
// Reset only completed entries
await supabaseService.resetQueueByStatus('completed');

// Reset completed entries for specific department
await supabaseService.resetQueueByStatus('completed', department: 'CONHS');
```

#### **4. `resetCompletedEntries()`**
```dart
// Reset completed entries for all departments
await supabaseService.resetCompletedEntries();

// Reset completed entries for specific department
await supabaseService.resetCompletedEntries(department: 'COENG');
```

## Usage Examples

### **Example 1: Daily Morning Reset**
```dart
Future<void> performDailyReset() async {
  try {
    final result = await supabaseService.resetAndGetFreshGraphData(
      purpose: 'daily',
    );
    
    if (result['success']) {
      print('Daily reset completed: ${result['message']}');
      print('Next queue number: ${result['fresh_graph_data']['next_queue_number']}');
      
      // Update your UI graphs here
      updateGraphs(result['fresh_graph_data']);
    }
  } catch (e) {
    print('Daily reset failed: $e');
  }
}
```

### **Example 2: Department-Specific Reset**
```dart
Future<void> resetCASDepartment() async {
  try {
    final result = await supabaseService.resetQueueWithPurpose(
      purpose: 'department',
      department: 'CAS',
      resetGraphs: true,
    );
    
    if (result['success']) {
      print('CAS department reset: ${result['message']}');
      
      // Get fresh data for CAS department
      final freshData = await supabaseService.getGraphDataAfterReset(
        department: 'CAS',
        resetPurpose: 'department',
      );
      
      // Update CAS-specific graphs
      updateCASGraphs(freshData);
    }
  } catch (e) {
    print('CAS reset failed: $e');
  }
}
```

### **Example 3: Emergency Reset**
```dart
Future<void> performEmergencyReset() async {
  try {
    final result = await supabaseService.resetAndGetFreshGraphData(
      purpose: 'emergency',
    );
    
    if (result['success']) {
      // Show emergency reset notification
      showEmergencyResetDialog(result['message']);
      
      // Reset all graphs to zero
      resetAllGraphs();
      
      // Get fresh data and update graphs
      final freshData = result['fresh_graph_data'];
      updateEmergencyGraphs(freshData);
    }
  } catch (e) {
    print('Emergency reset failed: $e');
  }
}
```

## Response Data Structure

### **Reset Response**
```json
{
  "success": true,
  "purpose": "daily",
  "department": null,
  "before_stats": {...},
  "after_stats": {...},
  "message": "Daily queue reset completed for all departments. All queue numbers reset to 001.",
  "graphs_reset": true,
  "reset_type": "Daily queue reset",
  "next_queue_start": 1
}
```

### **Fresh Graph Data**
```json
{
  "timestamp": "2024-01-15T09:00:00.000Z",
  "reset_purpose": "daily",
  "department": "all",
  "queue_status": {
    "waiting": 0,
    "serving": 0,
    "completed": 0,
    "missed": 0
  },
  "total_entries": 0,
  "next_queue_number": 1,
  "reset_category": "routine",
  "reset_frequency": "daily"
}
```

## Graph Update Implementation

### **1. Update Queue Status Chart**
```dart
void updateQueueStatusChart(Map<String, dynamic> graphData) {
  final statusData = graphData['queue_status'];
  
  // Update pie chart or bar chart
  chartController.updateData([
    ChartData('Waiting', statusData['waiting'], Colors.orange),
    ChartData('Serving', statusData['serving'], Colors.blue),
    ChartData('Completed', statusData['completed'], Colors.green),
    ChartData('Missed', statusData['missed'], Colors.red),
  ]);
}
```

### **2. Update Department Statistics**
```dart
void updateDepartmentStats(Map<String, dynamic> graphData) {
  if (graphData['department_specific'] == true) {
    final deptName = graphData['department_name'];
    final nextNumber = graphData['next_queue_number'];
    
    // Update department-specific displays
    updateDepartmentDisplay(deptName, nextNumber);
  }
}
```

### **3. Reset All Graphs**
```dart
void resetAllGraphs() {
  // Reset queue status chart
  chartController.resetData();
  
  // Reset department displays
  resetDepartmentDisplays();
  
  // Reset counters
  resetCounters();
  
  // Show reset confirmation
  showResetConfirmation();
}
```

## Admin Screen Integration

### **Reset Button Implementation**
```dart
ElevatedButton(
  onPressed: () => _showResetOptions(),
  child: Text('Reset Queue'),
),

// Reset options dialog
void _showResetOptions() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reset Queue Options'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('Daily Reset'),
            subtitle: Text('Reset all queues for new day'),
            onTap: () => _performReset('daily'),
          ),
          ListTile(
            title: Text('Department Reset'),
            subtitle: Text('Reset only this department'),
            onTap: () => _performReset('department'),
          ),
          ListTile(
            title: Text('Emergency Reset'),
            subtitle: Text('Emergency situation reset'),
            onTap: () => _performReset('emergency'),
          ),
        ],
      ),
    ),
  );
}
```

## Benefits

✅ **Purpose-Based Reset**: Different reset types for different scenarios
✅ **Automatic Graph Updates**: Charts refresh automatically after reset
✅ **Department Isolation**: Reset specific departments without affecting others
✅ **Reset History**: Track when and why resets occurred
✅ **Flexible Options**: Multiple reset methods for different needs
✅ **Data Integrity**: Maintains statistics before and after reset

## Best Practices

1. **Use appropriate reset purposes** for different scenarios
2. **Always check reset success** before updating UI
3. **Update graphs immediately** after successful reset
4. **Provide user feedback** for reset operations
5. **Log reset activities** for audit purposes
6. **Consider department-specific resets** for maintenance

This implementation provides a robust and flexible queue reset system that automatically handles graph updates based on the reset purpose! 🎯

