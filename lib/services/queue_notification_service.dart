import 'dart:async';
import '../models/queue_entry.dart';
import 'sms_service.dart';
import 'supabase_service.dart';
import 'email_notification_service.dart';

class QueueNotificationService {
  static final QueueNotificationService _instance =
      QueueNotificationService._internal();
  factory QueueNotificationService() => _instance;
  QueueNotificationService._internal();

  final SmsService _smsService = SmsService();
  final SupabaseService _supabaseService = SupabaseService();
  final EmailNotificationService _emailService = EmailNotificationService();

  Timer? _reminderTimer;
  final Map<String, DateTime> _lastReminderSent = {};

  // Initialize the notification service
  void initialize() {
    _startReminderTimer();
  }

  // Dispose resources
  void dispose() {
    _reminderTimer?.cancel();
    _lastReminderSent.clear();
  }

  // Send notification when user joins queue
  Future<bool> notifyQueueJoined(QueueEntry entry) async {
    try {
      bool smsSuccess = false;
      bool emailSuccess = false;

      // Send SMS notification
      if (_smsService.isValidPhoneNumber(entry.phoneNumber)) {
        final estimatedWait = await _calculateEstimatedWaitTime(entry);
        smsSuccess = await _smsService.sendWelcomeMessage(
          entry,
          estimatedWait,
        );
        
        if (smsSuccess) {
          print(
            'Welcome SMS sent to ${entry.name} with estimated wait: ${_formatDuration(estimatedWait)}',
          );
          _lastReminderSent[entry.id] = DateTime.now();
        }
      } else {
        print('Invalid phone number for ${entry.name}: ${entry.phoneNumber}');
      }

      // Send Email notification
      if (_emailService.isValidEmail(entry.email)) {
        emailSuccess = await _emailService.sendQueueJoinedEmail(entry);
        
        if (emailSuccess) {
          print('Welcome email sent to ${entry.name} at ${entry.email}');
        }
      } else {
        print('Invalid email address for ${entry.name}: ${entry.email}');
      }

      // Return true if at least one notification was sent successfully
      return smsSuccess || emailSuccess;
    } catch (e) {
      print('Error sending notifications: $e');
      return false;
    }
  }

  // Send notification when user is called
  Future<bool> notifyQueueCalled(QueueEntry entry) async {
    try {
      bool smsSuccess = false;
      bool emailSuccess = false;

      // Send SMS notification
      if (_smsService.isValidPhoneNumber(entry.phoneNumber)) {
        smsSuccess = await _smsService.sendQueueCalledNotification(entry);
        
        if (smsSuccess) {
          print('Queue called SMS sent to ${entry.name}');
          _lastReminderSent.remove(entry.id);
        }
      }

      // Send Email notification
      if (_emailService.isValidEmail(entry.email)) {
        emailSuccess = await _emailService.sendQueueCalledEmail(entry);
        
        if (emailSuccess) {
          print('Queue called email sent to ${entry.name}');
        }
      }

      return smsSuccess || emailSuccess;
    } catch (e) {
      print('Error sending queue called notification: $e');
      return false;
    }
  }

  // Send notification when queue is completed
  Future<bool> notifyQueueCompleted(QueueEntry entry) async {
    try {
      if (!_smsService.isValidPhoneNumber(entry.phoneNumber)) {
        print('Invalid phone number for ${entry.name}: ${entry.phoneNumber}');
        return false;
      }

      final success = await _smsService.sendQueueCompletedNotification(entry);

      if (success) {
        print('Queue completed notification sent to ${entry.name}');
        // Remove from reminder tracking
        _lastReminderSent.remove(entry.id);
      }

      return success;
    } catch (e) {
      print('Error sending queue completed notification: $e');
      return false;
    }
  }

  // Send notification when queue is cancelled
  Future<bool> notifyQueueCancelled(QueueEntry entry) async {
    try {
      if (!_smsService.isValidPhoneNumber(entry.phoneNumber)) {
        print('Invalid phone number for ${entry.name}: ${entry.phoneNumber}');
        return false;
      }

      final success = await _smsService.sendQueueCancelledNotification(entry);

      if (success) {
        print('Queue cancelled notification sent to ${entry.name}');
        // Remove from reminder tracking
        _lastReminderSent.remove(entry.id);
      }

      return success;
    } catch (e) {
      print('Error sending queue cancelled notification: $e');
      return false;
    }
  }

  Future<bool> notifyQueueMissed(QueueEntry entry) async {
    try {
      if (!_smsService.isValidPhoneNumber(entry.phoneNumber)) {
        print('Invalid phone number for ${entry.name}: ${entry.phoneNumber}');
        return false;
      }

      final success = await _smsService.sendQueueMissedNotification(entry);

      if (success) {
        print('Queue missed notification sent to ${entry.name}');
        // Remove from reminder tracking
        _lastReminderSent.remove(entry.id);
      }

      return success;
    } catch (e) {
      print('Error sending queue missed notification: $e');
      return false;
    }
  }

  // Send reminder notifications to waiting users
  Future<void> sendReminders() async {
    try {
      // Get all waiting queue entries
      final waitingEntries = await _getWaitingQueueEntries();

      for (int i = 0; i < waitingEntries.length; i++) {
        final entry = waitingEntries[i];
        final position = i + 1; // Position in queue (1-based)

        // Check if enough time has passed since last reminder
        final lastReminder = _lastReminderSent[entry.id];
        final timeSinceLastReminder = lastReminder != null
            ? DateTime.now().difference(lastReminder)
            : Duration.zero;

        // Send Top 5 notification immediately when someone enters Top 5
        if (position <= 5 &&
            !_lastReminderSent.containsKey('${entry.id}_top5')) {
          try {
            await _smsService.sendTop5Notification(entry);
            _lastReminderSent['${entry.id}_top5'] = DateTime.now();
            print(
              '🚀 Top 5 notification sent to ${entry.name} at position $position',
            );
          } catch (e) {
            print('Failed to send Top 5 notification: $e');
          }
        }

        // Send "Almost there" message when user is in positions 6-10
        if (position > 5 &&
            position <= 10 &&
            !_lastReminderSent.containsKey('${entry.id}_almost')) {
          try {
            await _smsService.sendAlmostThereMessage(entry);
            _lastReminderSent['${entry.id}_almost'] = DateTime.now();
            print(
              '🎉 Almost there message sent to ${entry.name} at position $position',
            );
          } catch (e) {
            print('Failed to send almost there message: $e');
          }
        }

        // Send regular reminders for Top 5 users every 8 minutes (more frequent)
        if (position <= 5 && timeSinceLastReminder >= Duration(minutes: 8)) {
          final waitTime = DateTime.now().difference(entry.timestamp);

          if (waitTime.inMinutes >= 8) {
            // Shorter interval for Top 5
            await _smsService.sendQueueReminder(entry, waitTime);
            _lastReminderSent[entry.id] = DateTime.now();

            // Add delay to avoid overwhelming the SMS service
            await Future.delayed(Duration(milliseconds: 500));
          }
        }

        // Send regular reminders for others every 20 minutes (less frequent)
        if (position > 10 && timeSinceLastReminder >= Duration(minutes: 20)) {
          final waitTime = DateTime.now().difference(entry.timestamp);

          if (waitTime.inMinutes >= 20) {
            await _smsService.sendQueueReminder(entry, waitTime);
            _lastReminderSent[entry.id] = DateTime.now();

            // Add delay to avoid overwhelming the SMS service
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
      }
    } catch (e) {
      print('Error sending reminders: $e');
    }
  }

  // Get all waiting queue entries
  Future<List<QueueEntry>> _getWaitingQueueEntries() async {
    try {
      final allEntries = await _supabaseService.getAllQueueEntries();
      return allEntries.where((entry) => entry.status == 'waiting').toList();
    } catch (e) {
      print('Error fetching waiting queue entries: $e');
      return [];
    }
  }

  // Start the reminder timer
  void _startReminderTimer() {
    _reminderTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      sendReminders();
    });
  }

  // Send bulk notifications for multiple queue events
  Future<Map<String, bool>> sendBulkNotifications(
    List<QueueEntry> entries,
    String notificationType,
  ) async {
    final results = <String, bool>{};

    for (final entry in entries) {
      bool success = false;

      switch (notificationType) {
        case 'joined':
          success = await notifyQueueJoined(entry);
          break;
        case 'called':
          success = await notifyQueueCalled(entry);
          break;
        case 'completed':
          success = await notifyQueueCompleted(entry);
          break;
        case 'cancelled':
          success = await notifyQueueCancelled(entry);
          break;
        default:
          print('Unknown notification type: $notificationType');
          success = false;
      }

      results[entry.id] = success;

      // Add delay between notifications
      await Future.delayed(Duration(milliseconds: 200));
    }

    return results;
  }

  // Test SMS functionality
  Future<bool> testSms(String phoneNumber) async {
    try {
      final testMessage =
          'This is a test SMS from your queue app. If you receive this, SMS is working correctly!';
      return await _smsService.sendSms(
        phoneNumber: phoneNumber,
        message: testMessage,
        provider: 'test', // Use test provider for development
      );
    } catch (e) {
      print('Error testing SMS: $e');
      return false;
    }
  }

  // Get notification statistics
  Map<String, dynamic> getNotificationStats() {
    return {
      'total_reminders_sent': _lastReminderSent.length,
      'active_reminders': _lastReminderSent.keys.toList(),
      'reminder_timestamps': _lastReminderSent,
    };
  }

  // Clear reminder history for a specific entry
  void clearReminderHistory(String entryId) {
    _lastReminderSent.remove(entryId);
  }

  // Clear all reminder history
  void clearAllReminderHistory() {
    _lastReminderSent.clear();
  }

  // Calculate estimated wait time based on queue position
  Future<Duration> _calculateEstimatedWaitTime(QueueEntry entry) async {
    try {
      final allWaitingEntries = await _getWaitingQueueEntries();
      final userPosition = allWaitingEntries.indexWhere(
        (e) => e.id == entry.id,
      );

      if (userPosition == -1) return Duration(seconds: 10); // Default fallback

      // Estimate: 2 seconds per person ahead + 5 seconds base time
      final estimatedSeconds = (userPosition * 2) + 5;
      return Duration(seconds: estimatedSeconds);
    } catch (e) {
      print('Error calculating wait time: $e');
      return Duration(seconds: 10); // Default fallback
    }
  }

  // Format duration in user-friendly way
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
