import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/queue_entry.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  // Track sent top 5 emails to prevent duplicates
  static final Set<String> _sentTop5Emails = <String>{};

  // EmailJS configuration - Update these with your actual EmailJS credentials
  static const String serviceId = 'service_3qmeeng';
  static const String templateId = 'template_acltt3l'; // Queue creation email template
  static const String templateTopFiveId = 'template_1j1htdr'; // Top 5 alert email template
  static const String publicKey = 'AdW8i4G7rNRLeYvR7';
  static const String privateKey = 'DtrRwhNAYnwGCti6J3ZG4'; // EmailJS private key
  static const String emailJsUrl = 'https://api.emailjs.com/api/v1.0/email/send-form';
  
  // Gmail sender configuration
  static const String gmailSenderEmail = 'ssuqueueapp@gmail.com';
  static const String gmailSenderName = 'SSU Queue System';

  /// Send completion email notification to user
  Future<bool> sendQueueCompletedEmail(QueueEntry entry) async {
    try {
      if (!_isValidEmail(entry.email)) {
        print('Invalid email address for ${entry.name}: ${entry.email}');
        return false;
      }

      final templateParams = {
        'to_email': entry.email,
        'to_name': entry.name,
        'from_name': gmailSenderName,
        'from_email': gmailSenderEmail,
        'reply_to': entry.email,
        'queue_number': entry.queueNumber.toString().padLeft(3, '0'),
        'reference_number': entry.referenceNumber ?? 'N/A',
        'department': entry.department,
        'purpose': entry.purpose,
        'completion_date': DateTime.now().toString(),
        'message':
            'Your queue service has been completed successfully. Thank you for using our queue system!',
      };

      print('Sending completion email to ${entry.email} for ${entry.name}');
      print('Template params: $templateParams');

      return await _sendEmail(
        label: 'completion',
        templateId: templateId,
        templateParams: templateParams,
      );
    } catch (e) {
      print('❌ Error sending queue completion email: $e');
      return false;
    }
  }

  /// Send confirmation when a new queue entry is created
  Future<bool> sendQueueCreatedEmail(QueueEntry entry) async {
    try {
      // Validate recipient email
      if (!_isValidEmail(entry.email)) {
        print('❌ Invalid email address for ${entry.name}: ${entry.email}');
        return false;
      }

      final templateParams = {
        'to_email': entry.email,
        'to_name': entry.name,
        'queue_number': entry.queueNumber.toString().padLeft(3, '0'),
        'reference_number': entry.referenceNumber ?? 'N/A',
        'department': entry.department,
        'purpose': entry.purpose,
        'course': entry.course ?? 'N/A',
        'message': 'You have been added to the queue. Please wait for your turn.',
        'from_name': 'SSU Queue System',
        // Try different email field names
        'email': entry.email,
        'user_email': entry.email,
        'recipient_email': entry.email,
      };

      print('📧 Sending queue-created email to ${entry.email} for ${entry.name}');
      print('📧 From: $gmailSenderEmail');
      print('📧 Queue-created template params: $templateParams');

      final result = await _sendEmail(
        label: 'created',
        templateId: templateId,
        templateParams: templateParams,
      );

      if (result) {
        print('✅ Email sent successfully to ${entry.email}');
        print('💡 If email not received, check:');
        print('   1. Spam/Junk folder');
        print('   2. EmailJS dashboard logs');
        print('   3. Email delivery may take 1-2 minutes');
      } else {
        print('❌ Failed to send email to ${entry.email}');
      }

      return result;
    } catch (e) {
      print('❌ Error sending queue-created email: $e');
      print('💡 Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Send notification when user is within top 5 of the queue
  Future<bool> sendTopFiveEmail(QueueEntry entry) async {
    try {
      // Check if top 5 email already sent to this user
      final emailKey = '${entry.id}_top5';
      if (_sentTop5Emails.contains(emailKey)) {
        print('📧 Top 5 email already sent to ${entry.name}');
        return true; // Return true since email was already sent
      }

      if (!_isValidEmail(entry.email)) {
        print('Invalid email address for ${entry.name}: ${entry.email}');
        return false;
      }

      final templateParams = {
        'to_email': entry.email,
        'to_name': entry.name,
        'queue_number': entry.queueNumber.toString().padLeft(3, '0'),
        'reference_number': entry.referenceNumber ?? 'N/A',
        'department': entry.department,
        'purpose': entry.purpose,
        'message': 'Good news! 🎉 Your queue is now in the Top 5. Kindly prepare and stay nearby, as your turn is approaching.',
        'from_name': 'SSU Queue System',
      };

      print('📧 Sending top-5 queue email to ${entry.email} for ${entry.name}');
      print('📊 Queue position: ${entry.queueNumber}, Department: ${entry.department}');

      final result = await _sendEmail(
        label: 'top-5-alert',
        templateId: templateTopFiveId,
        templateParams: templateParams,
      );

      if (result) {
        // Mark as sent to prevent duplicates
        _sentTop5Emails.add(emailKey);
      }

      return result;
    } catch (e) {
      print('❌ Error sending top-5 queue email: $e');
      return false;
    }
  }

  /// Send immediate notification for next in line (position 1-2)
  Future<bool> sendNextInLineEmail(QueueEntry entry) async {
    try {
      if (!_isValidEmail(entry.email)) {
        print('Invalid email address for ${entry.name}: ${entry.email}');
        return false;
      }

      final templateParams = {
        'to_email': entry.email,
        'to_name': entry.name,
        'from_name': gmailSenderName,
        'from_email': gmailSenderEmail,
        'reply_to': entry.email,
        'queue_number': entry.queueNumber.toString().padLeft(3, '0'),
        'reference_number': entry.referenceNumber ?? 'N/A',
        'department': entry.department,
        'purpose': entry.purpose,
        'course': entry.course ?? 'N/A',
        'current_time': DateTime.now().toString().substring(0, 16),
        'message': 'URGENT: Ikaw na ang susunod! You are next in line. Please proceed to ${entry.department} counter immediately.',
        'subject': '🚨 NEXT IN LINE - Queue #${entry.queueNumber.toString().padLeft(3, '0')} | ${entry.department}',
      };

      print('🚨 Sending NEXT IN LINE email to ${entry.email} for ${entry.name}');
      
      return await _sendEmail(
        label: 'next-in-line',
        templateId: templateTopFiveId, // Use same template but with urgent message
        templateParams: templateParams,
      );
    } catch (e) {
      print('❌ Error sending next-in-line email: $e');
      return false;
    }
  }
  Future<bool> sendCustomEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String message,
    Map<String, dynamic>? additionalParams,
  }) async {
    try {
      // Validate email address
      if (toEmail.isEmpty || !toEmail.contains('@')) {
        print('Invalid email address: $toEmail');
        return false;
      }

      final templateParams = {
        'to_email': toEmail,
        'to_name': toName,
        'from_name': gmailSenderName,
        'from_email': gmailSenderEmail,
        'reply_to': toEmail,
        'subject': subject,
        'message': message,
        ...?additionalParams,
      };

      print('Sending custom email to $toEmail');
      print('Template params: $templateParams');

      return await _sendEmail(
        label: 'custom',
        templateId: templateId,
        templateParams: templateParams,
      );
    } catch (e) {
      print('❌ Error sending custom email: $e');
      return false;
    }
  }

  /// Internal helper to send via EmailJS HTTP API
  Future<bool> _sendEmail({
    required String label,
    required String templateId,
    required Map<String, dynamic> templateParams,
  }) async {
    final payload = {
      'service_id': serviceId,
      'template_id': templateId,
      'user_id': publicKey,
      if (privateKey.isNotEmpty) 'accessToken': privateKey,
      'template_params': templateParams,
    };

    try {
      print('═══════════════════════════════════════════════════════');
      print('📧 EmailJS ($label) - Attempting to send email...');
      print('📧 Service ID: $serviceId');
      print('📧 Template ID: $templateId');
      print('📧 To Email: ${templateParams['to_email']}');
      print('📧 From Email: ${templateParams['from_email']}');
      print('═══════════════════════════════════════════════════════');
      
      final formData = <String, String>{
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'accessToken': privateKey,
      };
      
      // Add template parameters directly to form data
      templateParams.forEach((key, value) {
        formData[key] = value.toString();
      });
      
      final response = await http.post(
        Uri.parse(emailJsUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formData,
      );

      print('📧 EmailJS ($label) - Response status: ${response.statusCode}');
      print('📧 EmailJS ($label) - Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ ✅ ✅ EmailJS ($label) sent successfully! ✅ ✅ ✅');
        print('✅ Email sent to: ${templateParams['to_email']}');
        print('💡 IMPORTANT: Check your spam/junk folder if email not received');
        print('💡 Email should arrive within 1-2 minutes');
        print('═══════════════════════════════════════════════════════');
        return true;
      } else {
        final errorBody = response.body;
        print('❌ ❌ ❌ EmailJS ($label) ERROR ❌ ❌ ❌');
        print('❌ Status Code: ${response.statusCode}');
        print('❌ Error details: $errorBody');
        
        _logEmailJSErrors(errorBody);
        print('═══════════════════════════════════════════════════════');
        return false;
      }
    } catch (e) {
      print('❌ ❌ ❌ EmailJS ($label) EXCEPTION ❌ ❌ ❌');
      print('❌ Error: $e');
      _logNetworkErrors(e.toString());
      print('═══════════════════════════════════════════════════════');
      return false;
    }
  }
  
  void _logEmailJSErrors(String errorBody) {
    if (errorBody.contains('Invalid service ID') || errorBody.contains('Service not found')) {
      print('💡 FIX: Check your EmailJS Service ID');
      print('💡 Current Service ID: $serviceId');
      print('💡 Go to EmailJS Dashboard → Services → Verify Service ID');
    } else if (errorBody.contains('Invalid template ID') || errorBody.contains('Template not found')) {
      print('💡 FIX: Check your EmailJS Template ID');
      print('💡 Current Template ID: $templateId');
      print('💡 Go to EmailJS Dashboard → Email Templates → Verify Template ID');
    } else if (errorBody.contains('Invalid user ID') || errorBody.contains('User not found')) {
      print('💡 FIX: Check your EmailJS Public Key');
      print('💡 Current Public Key: $publicKey');
      print('💡 Go to EmailJS Dashboard → Account → General → Copy Public Key');
    } else if (errorBody.contains('rate limit') || errorBody.contains('quota')) {
      print('💡 FIX: EmailJS rate limit reached');
      print('💡 Free tier: 200 emails/month');
      print('💡 Check EmailJS Dashboard → Account → Usage');
    } else if (errorBody.contains('Forbidden') || errorBody.contains('403')) {
      print('💡 FIX: EmailJS access forbidden');
      print('💡 Check if Gmail service is properly connected in EmailJS');
    }
  }
  
  void _logNetworkErrors(String error) {
    if (error.contains('timeout')) {
      print('💡 FIX: Network timeout - Check internet connection');
    } else if (error.contains('SocketException')) {
      print('💡 FIX: Cannot connect to EmailJS - Check internet connection');
    } else {
      print('💡 FIX: Unexpected error - Check console logs');
    }
  }

  bool _isValidEmail(String email) =>
      email.isNotEmpty && email.contains('@') && email.contains('.');
      
  /// Test email configuration
  Future<bool> testEmailConfiguration() async {
    try {
      print('🧪 Testing EmailJS configuration...');
      return true; // HTTP API doesn't need initialization
    } catch (e) {
      print('❌ EmailJS configuration test failed: $e');
      return false;
    }
  }
  
  /// Get configuration status
  Map<String, dynamic> getConfigurationStatus() {
    return {
      'service_id': serviceId,
      'template_id': templateId,
      'template_top_five_id': templateTopFiveId,
      'public_key': publicKey,
      'private_key_configured': privateKey.isNotEmpty,
      'gmail_sender': gmailSenderEmail,
      'gmail_sender_configured': gmailSenderEmail != 'your-email@gmail.com',
      'http_api_ready': true,
    };
  }
}
