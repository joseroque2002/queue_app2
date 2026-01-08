# SMS Implementation Guide for Queue App

This guide explains how to implement and use SMS functionality in your queue management app.

## 🚀 What's Been Implemented

### 1. SMS Service (`lib/services/sms_service.dart`)
- **Multiple SMS Providers**: Support for Twilio, AWS SNS, and test mode
- **Message Templates**: Pre-configured messages for different queue events
- **Phone Validation**: Regex-based phone number validation
- **Message Length Handling**: Automatic message splitting for long texts
- **Retry Logic**: Built-in retry mechanism for failed SMS

### 2. Queue Notification Service (`lib/services/queue_notification_service.dart`)
- **Automatic Notifications**: Sends SMS when queue status changes
- **Reminder System**: Periodic reminders for waiting users
- **Bulk Operations**: Send notifications to multiple users at once
- **Integration**: Works seamlessly with your existing queue system

### 3. SMS Configuration (`lib/constants/sms_config.dart`)
- **Provider Settings**: Easy configuration for different SMS services
- **Message Templates**: Customizable notification messages
- **Feature Toggles**: Enable/disable SMS functionality
- **Timing Controls**: Configurable reminder intervals

### 4. Test Widget (`lib/widgets/sms_test_widget.dart`)
- **SMS Testing**: Test SMS functionality before going live
- **Configuration**: Easy provider switching and settings
- **Statistics**: View notification history and stats

## 📱 How to Use

### Step 1: Install Dependencies
Run this command to install the required packages:
```bash
flutter pub get
```

### Step 2: Configure SMS Provider

#### Option A: Twilio (Recommended for Production)
1. Sign up for a Twilio account at [twilio.com](https://twilio.com)
2. Get your Account SID and Auth Token from the Twilio Console
3. Get a Twilio phone number
4. Update `lib/constants/sms_config.dart`:

```dart
// Twilio Configuration
static const String twilioAccountSid = 'YOUR_ACTUAL_ACCOUNT_SID';
static const String twilioAuthToken = 'YOUR_ACTUAL_AUTH_TOKEN';
static const String twilioPhoneNumber = '+1234567890'; // Your actual Twilio number
```

#### Option B: AWS SNS
1. Set up AWS credentials
2. Update the AWS configuration in `sms_config.dart`
3. Note: This is a simplified implementation - consider using AWS SDK for production

#### Option C: Test Mode (Development)
- Use `'test'` as the provider for development
- SMS will be logged to console instead of actually sent

### Step 3: Integrate with Your Queue System

#### Automatic Notifications
The system automatically sends SMS when:
- User joins the queue
- User is called to the counter
- Queue is completed
- Queue is cancelled

#### Manual Integration
Add this to your queue management logic:

```dart
import '../services/queue_notification_service.dart';

final notificationService = QueueNotificationService();

// When user joins queue
await notificationService.notifyQueueJoined(queueEntry);

// When user is called
await notificationService.notifyQueueCalled(queueEntry);

// When queue is completed
await notificationService.notifyQueueCompleted(queueEntry);

// When queue is cancelled
await notificationService.notifyQueueCancelled(queueEntry);
```

### Step 4: Initialize the Service
Add this to your app initialization:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseService().initialize();
  
  // Initialize SMS notifications
  QueueNotificationService().initialize();
  
  runApp(const QueueManagementApp());
}
```

### Step 5: Test the Implementation
Use the `SmsTestWidget` to test SMS functionality:

```dart
// Add this to your navigation or admin panel
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const SmsTestWidget(),
  ),
);
```

## 🔧 Configuration Options

### Message Templates
Customize the SMS messages in `sms_config.dart`:

```dart
static const String queueJoinedMessage = 
    'Hi {name}, you have joined the queue for {department}. Your queue number is {queueNumber}. We will notify you when it\'s your turn.';
```

Available variables:
- `{name}` - User's name
- `{department}` - Department name
- `{queueNumber}` - Queue number
- `{waitTime}` - Current wait time

### Timing Settings
```dart
static const bool enableSmsNotifications = true;        // Master toggle
static const bool enableQueueReminders = true;          // Enable reminders
static const Duration reminderInterval = Duration(minutes: 15); // Reminder frequency
static const Duration retryDelay = Duration(seconds: 5);       // Retry delay
```

### SMS Limits
```dart
static const int maxMessageLength = 160;        // Standard SMS
static const int maxMessageLengthUnicode = 70;  // Unicode SMS
```

## 📊 Features

### 1. Automatic Queue Notifications
- **Queue Joined**: Confirms entry and provides queue number
- **Queue Called**: Notifies user it's their turn
- **Queue Completed**: Confirms service completion
- **Queue Cancelled**: Informs user of cancellation

### 2. Smart Reminder System
- Sends periodic reminders to waiting users
- Configurable reminder intervals
- Prevents spam by tracking last reminder sent
- Automatic cleanup when queue status changes

### 3. Bulk Operations
- Send notifications to multiple users
- Built-in rate limiting to avoid overwhelming SMS services
- Batch processing with progress tracking

### 4. Error Handling
- Automatic retry on failure
- Detailed error logging
- Graceful degradation when SMS fails
- Phone number validation

### 5. Development Tools
- Test mode for development
- SMS statistics and monitoring
- Configuration validation
- Easy provider switching

## 🚨 Important Notes

### Security
- **Never commit real API keys** to version control
- Use environment variables or secure configuration management
- Consider using Supabase Edge Functions for SMS in production

### Cost Considerations
- SMS costs vary by provider (Twilio: ~$0.0075 per SMS)
- Implement rate limiting to control costs
- Monitor usage and set up alerts

### Phone Number Format
- Use international format: `+1234567890`
- Validate phone numbers before sending
- Handle different country codes appropriately

### Testing
- Always test with test mode first
- Use real phone numbers for final testing
- Test with different message lengths and content

## 🔍 Troubleshooting

### Common Issues

1. **SMS not sending**
   - Check API credentials
   - Verify phone number format
   - Check console for error messages
   - Ensure SMS notifications are enabled

2. **Invalid phone numbers**
   - Use international format
   - Remove spaces and special characters
   - Test with known valid numbers

3. **Message too long**
   - Messages are automatically split
   - Check message length limits
   - Use shorter templates if needed

4. **Rate limiting**
   - Implement delays between SMS
   - Use bulk operations sparingly
   - Monitor provider limits

### Debug Mode
Enable debug logging by checking console output:
```dart
// All SMS operations log to console
print('SMS sent successfully via Twilio');
print('Failed to send SMS: $error');
```

## 📈 Next Steps

1. **Test thoroughly** with test mode
2. **Configure production** SMS provider
3. **Set up monitoring** and alerts
4. **Customize messages** for your use case
5. **Implement user preferences** for SMS opt-in/out
6. **Add analytics** to track SMS effectiveness

## 🆘 Support

If you encounter issues:
1. Check the console logs for error messages
2. Verify your SMS provider configuration
3. Test with the `SmsTestWidget`
4. Ensure all dependencies are properly installed

The SMS system is designed to be robust and fail-safe, so your queue app will continue to work even if SMS fails. 