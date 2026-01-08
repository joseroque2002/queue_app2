// Test SMS Functionality
// This file demonstrates how to test the SMS implementation

import 'lib/services/sms_service.dart';
import 'lib/services/queue_notification_service.dart';
import 'lib/models/queue_entry.dart';

void main() async {
  print('Testing SMS functionality...\n');

  // Test 1: Basic SMS Service
  print('=== Test 1: Basic SMS Service ===');
  final smsService = SmsService();

  // Test with test provider (no actual SMS sent)
  final testResult = await smsService.sendSms(
    phoneNumber: '+1234567890',
    message: 'This is a test SMS from your queue app!',
    provider: 'test',
  );

  print('Test SMS result: $testResult\n');

  // Test 2: Queue Notification Service
  print('=== Test 2: Queue Notification Service ===');
  final notificationService = QueueNotificationService();

  // Create a test queue entry
  final testEntry = QueueEntry(
    id: 'test-123',
    name: 'John Doe',
    ssuId: '2021-12345',
    email: 'john.doe@example.com',
    phoneNumber: '+1234567890',
    department: 'CAS',
    purpose: 'TOR',
    timestamp: DateTime.now(),
    queueNumber: 1,
    status: 'waiting',
  );

  // Test queue joined notification
  final joinedResult = await notificationService.notifyQueueJoined(testEntry);
  print('Queue joined notification: $joinedResult');

  // Test queue called notification
  final calledResult = await notificationService.notifyQueueCalled(testEntry);
  print('Queue called notification: $calledResult');

  // Test queue completed notification
  final completedResult = await notificationService.notifyQueueCompleted(
    testEntry,
  );
  print('Queue completed notification: $completedResult');

  // Test queue cancelled notification
  final cancelledResult = await notificationService.notifyQueueCancelled(
    testEntry,
  );
  print('Queue cancelled notification: $cancelledResult\n');

  // Test 3: Phone Number Validation
  print('=== Test 3: Phone Number Validation ===');
  final validNumbers = [
    '+1234567890',
    '+44 20 7946 0958',
    '+81 3-1234-5678',
    '1234567890',
  ];

  for (final number in validNumbers) {
    final isValid = smsService.isValidPhoneNumber(number);
    print('$number: ${isValid ? "Valid" : "Invalid"}');
  }

  // Test 4: Message Length Handling
  print('\n=== Test 4: Message Length Handling ===');
  final longMessage =
      'This is a very long message that exceeds the standard SMS length limit of 160 characters. It should be automatically split into multiple messages if needed. This is useful for sending detailed notifications to users.';

  final isTooLong = smsService.isMessageTooLong(longMessage);
  print('Message too long: $isTooLong');

  if (isTooLong) {
    final splitMessages = smsService.splitLongMessage(longMessage);
    print('Split into ${splitMessages.length} messages:');
    for (int i = 0; i < splitMessages.length; i++) {
      print('Message ${i + 1}: ${splitMessages[i].length} characters');
    }
  }

  print('\n=== SMS Testing Complete ===');
  print('All tests completed successfully!');
  print('Check the console output above for results.');
  print('\nTo test with real SMS providers:');
  print('1. Update lib/constants/sms_config.dart with your API keys');
  print('2. Change the provider from "test" to "twilio" or "aws_sns"');
  print('3. Use real phone numbers for testing');
}
