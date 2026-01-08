class SmsConfig {
  // SMS Provider Configuration
  static const String defaultProvider =
      'test'; // 'twilio', 'aws_sns', 'email_sms', 'test'

  // Twilio Configuration
  static const String twilioAccountSid = 'YOUR_TWILIO_ACCOUNT_SID';
  static const String twilioAuthToken = 'YOUR_TWILIO_AUTH_TOKEN';
  static const String twilioPhoneNumber =
      'YOUR_TWILIO_PHONE_NUMBER'; // Your actual Twilio phone number

  // AWS SNS Configuration
  static const String awsAccessKeyId = 'YOUR_AWS_ACCESS_KEY_ID';
  static const String awsSecretAccessKey = 'YOUR_AWS_SECRET_ACCESS_KEY';
  static const String awsRegion = 'us-east-1';

  // Message Templates
  static const String queueJoinedMessage =
      '🎉 Hi {name}! You\'ve successfully joined the {department} queue. Your queue number is #{queueNumber}. We\'ll keep you updated on your status! 📱';

  static const String queueTop5Message =
      '🚀 Great news {name}! You\'re now in the Top 5 for {department} (Queue #{queueNumber}). Please get ready - you\'ll be called soon! ⏰';

  static const String queueReminderMessage =
      '⏳ Hi {name}! You\'re still in the Top 5 for {department} (Queue #{queueNumber}). Please stay ready - your turn is coming up! 🙌';

  static const String queueCalledMessage =
      '🎯 {name}, it\'s your turn! Please proceed to {department} counter now. Queue number: #{queueNumber}. See you there! 👋';

  static const String queueCompletedMessage =
      '✅ Thank you {name}! Your queue number #{queueNumber} has been completed. We hope we served you well. Have a great day! 🌟';

  static const String queueCancelledMessage =
      'ℹ️ Hi {name}, your queue number #{queueNumber} for {department} has been cancelled. If you need assistance, please visit our help desk. 🙏';

  static const String queueWelcomeMessage =
      '👋 Welcome {name}! You\'re queue number #{queueNumber} for {department}. Estimated wait time: {waitTime}. We\'ll keep you posted! 📱';

  static const String queueAlmostThereMessage =
      '🎉 Almost there {name}! You\'re queue number #{queueNumber} for {department}. Just a few more people ahead of you! ⏰';

  static const String queueMissedMessage =
      '⏰ Hi {name}, your queue number #{queueNumber} for {department} has expired. You have been removed from the queue. Please get a new queue number if you still need service. 🔄';

  // SMS Settings
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 5);
  static const bool enableSmsNotifications = true;
  static const bool enableQueueReminders = true;
  static const Duration reminderInterval = Duration(minutes: 15);

  // Phone number validation
  static const String phoneNumberPattern = r'^\+?[1-9]\d{1,14}$';

  // Message length limits
  static const int maxMessageLength = 160; // Standard SMS length
  static const int maxMessageLengthUnicode = 70; // Unicode SMS length
}
