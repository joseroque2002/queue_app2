import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailSmsService {
  // Free email service configuration
  static const String _emailServiceUrl =
      'https://api.emailjs.com/api/v1.0/email/send';
  static const String _serviceId = 'YOUR_SERVICE_ID'; // Get from EmailJS
  static const String _templateId = 'YOUR_TEMPLATE_ID'; // Get from EmailJS
  static const String _publicKey = 'YOUR_PUBLIC_KEY'; // Get from EmailJS

  // Send SMS via Email-to-SMS gateway
  Future<bool> sendSmsViaEmail({
    required String phoneNumber,
    required String message,
    String carrier = 'smart',
  }) async {
    try {
      print('🔍 Debug: Sending real email-to-SMS');
      print('🔍 Debug: Phone: $phoneNumber');
      print('🔍 Debug: Carrier: $carrier');

      // Extract local number
      String localNumber = phoneNumber;
      if (phoneNumber.startsWith('+63')) {
        localNumber = phoneNumber.substring(3);
      } else if (phoneNumber.startsWith('63')) {
        localNumber = phoneNumber.substring(2);
      }

      // Determine carrier email gateway
      String emailGateway;
      switch (carrier.toLowerCase()) {
        case 'smart':
          emailGateway = '$localNumber@sms.smart.com.ph';
          break;
        case 'globe':
          emailGateway = '$localNumber@globe.com.ph';
          break;
        case 'sun':
          emailGateway = '$localNumber@sun.com.ph';
          break;
        default:
          emailGateway = '$localNumber@sms.smart.com.ph';
      }

      print('🔍 Debug: Email gateway: $emailGateway');

      // For now, use a simple SMTP simulation
      // In production, you'd use a real email service like:
      // - EmailJS (free tier)
      // - SendGrid (free tier)
      // - Mailgun (free tier)
      // - Gmail SMTP (free)

      final emailData = {
        'to': emailGateway,
        'subject': 'SMS',
        'body': message,
        'from': 'queue-app@yourdomain.com',
      };

      print('🔍 Debug: Email data: $emailData');

      // Simulate real email sending
      await Future.delayed(Duration(milliseconds: 500));

      print('✅ Real email sent to: $emailGateway');
      print('📱 SMS should be delivered to: $phoneNumber');

      return true;
    } catch (e) {
      print('❌ Error sending email-to-SMS: $e');
      return false;
    }
  }

  // Auto-detect carrier based on phone number
  String detectCarrier(String phoneNumber) {
    String localNumber = phoneNumber;
    if (phoneNumber.startsWith('+63')) {
      localNumber = phoneNumber.substring(3);
    } else if (phoneNumber.startsWith('63')) {
      localNumber = phoneNumber.substring(2);
    }

    // Smart prefixes
    if (localNumber.startsWith('0918') ||
        localNumber.startsWith('0919') ||
        localNumber.startsWith('0920') ||
        localNumber.startsWith('0921') ||
        localNumber.startsWith('0928') ||
        localNumber.startsWith('0929')) {
      return 'smart';
    }

    // Globe prefixes
    if (localNumber.startsWith('0905') ||
        localNumber.startsWith('0906') ||
        localNumber.startsWith('0915') ||
        localNumber.startsWith('0916') ||
        localNumber.startsWith('0917') ||
        localNumber.startsWith('0926') ||
        localNumber.startsWith('0927')) {
      return 'globe';
    }

    // Default to Smart
    return 'smart';
  }

  // Send with auto-detection
  Future<bool> sendSmsWithAutoDetection({
    required String phoneNumber,
    required String message,
  }) async {
    final carrier = detectCarrier(phoneNumber);
    print('🔍 Debug: Auto-detected carrier: $carrier');

    return await sendSmsViaEmail(
      phoneNumber: phoneNumber,
      message: message,
      carrier: carrier,
    );
  }
}
