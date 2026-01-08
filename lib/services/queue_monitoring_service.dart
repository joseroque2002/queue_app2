import 'dart:async';
import '../services/supabase_service.dart';
import '../services/email_service.dart';
import '../models/queue_entry.dart';

class QueueMonitoringService {
  static final QueueMonitoringService _instance = QueueMonitoringService._internal();
  factory QueueMonitoringService() => _instance;
  QueueMonitoringService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final EmailService _emailService = EmailService();
  
  Timer? _monitoringTimer;
  Map<String, Set<String>> _notifiedUsers = {}; // department -> set of user IDs
  
  // Start monitoring queue positions for all departments
  void startMonitoring() {
    print('🔍 Starting queue monitoring service...');
    
    // Check every 30 seconds
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkAllDepartmentQueues();
    });
    
    print('✅ Queue monitoring service started');
  }
  
  // Stop monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    print('🛑 Queue monitoring service stopped');
  }
  
  // Check all department queues for top 5 notifications
  Future<void> _checkAllDepartmentQueues() async {
    try {
      // Get all active queue entries grouped by department
      final allEntries = await _supabaseService.getAllActiveQueueEntries();
      
      // Group by department
      final Map<String, List<QueueEntry>> departmentQueues = {};
      for (final entry in allEntries) {
        if (!departmentQueues.containsKey(entry.department)) {
          departmentQueues[entry.department] = [];
        }
        departmentQueues[entry.department]!.add(entry);
      }
      
      // Check each department
      for (final department in departmentQueues.keys) {
        await _checkDepartmentQueue(department, departmentQueues[department]!);
      }
      
    } catch (e) {
      print('❌ Error in queue monitoring: $e');
    }
  }
  
  // Check specific department queue for top 5 notifications
  Future<void> _checkDepartmentQueue(String department, List<QueueEntry> entries) async {
    try {
      // Sort entries by priority and queue number
      entries.sort((a, b) {
        // Priority users first
        if (a.isPriority && !b.isPriority) return -1;
        if (!a.isPriority && b.isPriority) return 1;
        // Then by queue number
        return a.queueNumber.compareTo(b.queueNumber);
      });
      
      // Get waiting entries only
      final waitingEntries = entries.where((e) => e.status == 'waiting').toList();
      
      // Initialize department notification set if not exists
      if (!_notifiedUsers.containsKey(department)) {
        _notifiedUsers[department] = <String>{};
      }
      
      // Check only position 5 user (not 1-4)
      if (waitingEntries.length >= 5) {
        final position5User = waitingEntries[4]; // Index 4 = position 5
        
        // Check if user hasn't been notified yet for top 5
        if (!_notifiedUsers[department]!.contains(position5User.id)) {
          await _sendTop5Notification(position5User, 5);
          _notifiedUsers[department]!.add(position5User.id);
          
          print('📧 Sent top 5 notification to ${position5User.name} (Position 5, Queue #${position5User.queueNumber})');
        }
      }
      
    } catch (e) {
      print('❌ Error checking department queue $department: $e');
    }
  }
  
  // Send top 5 notification email
  Future<void> _sendTop5Notification(QueueEntry entry, int position) async {
    try {
      final success = await _emailService.sendTopFiveEmail(entry);
      
      if (success) {
        print('✅ Top 5 email sent successfully to ${entry.email}');
      } else {
        print('❌ Failed to send top 5 email to ${entry.email}');
      }
      
    } catch (e) {
      print('❌ Error sending top 5 notification: $e');
    }
  }
  
  // Manual trigger for specific department
  Future<void> checkDepartmentNow(String department) async {
    try {
      final entries = await _supabaseService.getActiveQueueEntriesByDepartment(department);
      await _checkDepartmentQueue(department, entries);
    } catch (e) {
      print('❌ Error in manual department check: $e');
    }
  }
  
  // Reset notifications for a department (useful after queue reset)
  void resetDepartmentNotifications(String department) {
    _notifiedUsers[department]?.clear();
    print('🔄 Reset notifications for department: $department');
  }
  
  // Reset all notifications
  void resetAllNotifications() {
    _notifiedUsers.clear();
    print('🔄 Reset all notifications');
  }
  
  // Get notification status
  Map<String, int> getNotificationStatus() {
    final status = <String, int>{};
    for (final department in _notifiedUsers.keys) {
      status[department] = _notifiedUsers[department]!.length;
    }
    return status;
  }
}