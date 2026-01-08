import '../services/email_service.dart';
import '../models/queue_entry.dart';

class EmailTest {
  static final EmailService _emailService = EmailService();

  /// Test email configuration and send a test email
  static Future<void> testEmailConfiguration() async {
    print('🧪 Starting EmailJS Configuration Test...');
    print('=' * 50);

    // Test configuration status
    final config = _emailService.getConfigurationStatus();
    print('📋 Configuration Status:');
    config.forEach((key, value) {
      print('   $key: $value');
    });
    print('=' * 50);

    // Test initialization
    final initResult = await _emailService.testEmailConfiguration();
    if (initResult) {
      print('✅ EmailJS configuration test passed');
    } else {
      print('❌ EmailJS configuration test failed');
      return;
    }

    print('=' * 50);
    print('🧪 Email configuration test completed');
    print('💡 To test actual email sending, use testSendEmail() method');
  }

  /// Send a test email to verify email delivery
  static Future<bool> testSendEmail(String testEmail) async {
    try {
      print('📧 Sending test email to: $testEmail');
      
      // Create a test queue entry
      final testEntry = QueueEntry(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test User',
        ssuId: 'TEST-001',
        email: testEmail,
        phoneNumber: '+639123456789',
        department: 'TEST',
        purpose: 'Email Configuration Test',
        course: 'TEST-COURSE',
        timestamp: DateTime.now(),
        queueNumber: 1,
        referenceNumber: 'TEST-REF-${DateTime.now().millisecondsSinceEpoch}',
      );

      // Send test email
      final result = await _emailService.sendQueueCreatedEmail(testEntry);
      
      if (result) {
        print('✅ Test email sent successfully!');
        print('💡 Check your email inbox (including spam folder)');
        print('💡 Email should arrive within 1-2 minutes');
      } else {
        print('❌ Test email failed to send');
        print('💡 Check EmailJS configuration and console logs');
      }
      
      return result;
    } catch (e) {
      print('❌ Error sending test email: $e');
      return false;
    }
  }

  /// Quick diagnostic of common email issues
  static void diagnoseEmailIssues() {
    print('🔍 Email Diagnostic Report');
    print('=' * 50);
    
    final config = _emailService.getConfigurationStatus();
    
    // Check service configuration
    if (config['service_id'] == 'service_3qmeeng') {
      print('✅ Service ID configured');
    } else {
      print('❌ Service ID not configured properly');
    }
    
    if (config['public_key'] == 'AdW8i4G7rNRLeYvR7') {
      print('✅ Public Key configured');
    } else {
      print('❌ Public Key not configured properly');
    }
    
    if (config['gmail_sender_configured'] == true) {
      print('✅ Gmail sender configured');
    } else {
      print('❌ Gmail sender not configured - update gmailSenderEmail');
    }
    
    print('=' * 50);
    print('💡 Common Solutions:');
    print('   1. Verify EmailJS service is active in dashboard');
    print('   2. Check template IDs match your EmailJS templates');
    print('   3. Ensure Gmail service is connected in EmailJS');
    print('   4. Check EmailJS usage limits (200 emails/month free)');
    print('   5. Verify recipient email is valid');
    print('   6. Check spam/junk folders');
  }
}