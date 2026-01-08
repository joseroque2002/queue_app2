import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/queue_entry.dart';

class EmailNotificationService {
  static final EmailNotificationService _instance = EmailNotificationService._internal();
  factory EmailNotificationService() => _instance;
  EmailNotificationService._internal();

  // EmailJS configuration
  static const String _serviceId = 'service_3qmeeng';
  static const String _templateId = 'template_acltt3l';
  static const String _publicKey = 'AdW8i4G7rNRLeYvR7';
  static const String _emailJsUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  // Send email notification when user joins queue
  Future<bool> sendQueueJoinedEmail(QueueEntry entry) async {
    try {
      final emailData = {
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'to_email': entry.email,
          'to_name': entry.name,
          'queue_number': entry.queueNumber.toString().padLeft(3, '0'),
          'department': entry.department,
          'purpose': entry.purpose,
          'course': entry.course ?? 'N/A',
          'timestamp': _formatDateTime(entry.timestamp),
          'priority_status': entry.isPriority ? 'Priority Queue' : 'Regular Queue',
          'priority_type': entry.isPriority ? entry.priorityType : '',
          'reference_number': entry.referenceNumber ?? '',
        }
      };

      final response = await http.post(
        Uri.parse(_emailJsUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(emailData),
      );

      if (response.statusCode == 200) {
        print('✅ Email notification sent successfully to ${entry.email}');
        return true;
      } else {
        print('❌ Failed to send email: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending email notification: $e');
      return false;
    }
  }

  // Send email notification when user is called
  Future<bool> sendQueueCalledEmail(QueueEntry entry) async {
    try {
      final emailData = {
        'service_id': _serviceId,
        'template_id': 'template_called', // Different template for called notification
        'user_id': _publicKey,
        'template_params': {
          'to_email': entry.email,
          'to_name': entry.name,
          'queue_number': entry.queueNumber.toString().padLeft(3, '0'),
          'department': entry.department,
          'timestamp': _formatDateTime(DateTime.now()),
        }
      };

      final response = await http.post(
        Uri.parse(_emailJsUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(emailData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error sending queue called email: $e');
      return false;
    }
  }

  // Send test email
  Future<bool> sendTestEmail(String email, String name) async {
    try {
      final emailData = {
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'to_email': email,
          'to_name': name,
          'queue_number': '001',
          'department': 'TEST',
          'purpose': 'Testing Email Service',
          'course': 'Test Course',
          'timestamp': _formatDateTime(DateTime.now()),
          'priority_status': 'Test Queue',
          'priority_type': '',
          'reference_number': 'TEST-001',
        }
      };

      final response = await http.post(
        Uri.parse(_emailJsUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(emailData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error sending test email: $e');
      return false;
    }
  }

  // Format DateTime for email display
  String _formatDateTime(DateTime dateTime) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    return '$month $day, $year at $hour:$minute $period';
  }

  // Validate email format
  bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }
}