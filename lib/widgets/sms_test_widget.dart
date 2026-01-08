import 'package:flutter/material.dart';
import '../services/sms_service.dart';
import '../services/queue_notification_service.dart';
import '../constants/sms_config.dart';
import '../models/queue_entry.dart';

class SmsTestWidget extends StatefulWidget {
  const SmsTestWidget({super.key});

  @override
  State<SmsTestWidget> createState() => _SmsTestWidgetState();
}

class _SmsTestWidgetState extends State<SmsTestWidget> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedProvider = SmsConfig.defaultProvider;
  String _selectedCarrier = 'Smart';
  bool _isLoading = false;
  String _testResult = '';
  bool _smsEnabled = SmsConfig.enableSmsNotifications;

  @override
  void initState() {
    super.initState();
    // Pre-fill with a test message
    _messageController.text =
        '🧪 Test SMS from Queue App - ${DateTime.now().toString().substring(11, 19)}';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Simple SMS test
  Future<void> _testSms() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _testResult = '❌ Please enter a phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = '🔄 Testing SMS...';
    });

    try {
      // Add +63 prefix to phone number
      final phoneNumber = '+63${_phoneController.text}';

      // Debug logging
      print('🔍 Debug: Original input: ${_phoneController.text}');
      print('🔍 Debug: Formatted phone: $phoneNumber');
      print('🔍 Debug: Twilio from number: ${SmsConfig.twilioPhoneNumber}');

      final success = await SmsService().sendSms(
        phoneNumber: phoneNumber,
        message: _messageController.text,
        provider: _selectedProvider,
        carrier: _selectedCarrier,
      );

      setState(() {
        _testResult = success
            ? '✅ SMS sent successfully! Check your phone.'
            : '❌ SMS failed to send. Check console for details.';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Test queue notification
  Future<void> _testQueueNotification() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _testResult = '❌ Please enter a phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = '🔄 Testing queue notification...';
    });

    try {
      // Add +63 prefix to phone number
      final phoneNumber = '+63${_phoneController.text}';

      // Create a test queue entry
      final testEntry = QueueEntry(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test User',
        ssuId: 'TEST123',
        email: 'test@example.com',
        phoneNumber: phoneNumber,
        department: 'CAS',
        purpose: 'TEST',
        timestamp: DateTime.now(),
        queueNumber: 999,
        status: 'waiting',
      );

      final success = await QueueNotificationService().notifyQueueJoined(
        testEntry,
      );

      setState(() {
        _testResult = success
            ? '✅ Queue notification sent successfully! Check your phone.'
            : '❌ Queue notification failed. Check console for details.';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Test Top 5 notification
  Future<void> _testTop5Notification() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _testResult = '❌ Please enter a phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = '🔄 Testing Top 5 notification...';
    });

    try {
      // Add +63 prefix to phone number
      final phoneNumber = '+63${_phoneController.text}';

      final testEntry = QueueEntry(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test User',
        ssuId: 'TEST123',
        email: 'test@example.com',
        phoneNumber: phoneNumber,
        department: 'CAS',
        purpose: 'TEST',
        timestamp: DateTime.now(),
        queueNumber: 999,
        status: 'waiting',
      );

      final success = await SmsService().sendTop5Notification(testEntry);

      setState(() {
        _testResult = success
            ? '✅ Top 5 notification sent successfully! Check your phone.'
            : '❌ Top 5 notification failed. Check console for details.';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Test welcome message
  Future<void> _testWelcomeMessage() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _testResult = '❌ Please enter a phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = '🔄 Testing welcome message...';
    });

    try {
      // Add +63 prefix to phone number
      final phoneNumber = '+63${_phoneController.text}';

      final testEntry = QueueEntry(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test User',
        ssuId: 'TEST123',
        email: 'test@example.com',
        phoneNumber: phoneNumber,
        department: 'CAS',
        purpose: 'TEST',
        timestamp: DateTime.now(),
        queueNumber: 999,
        status: 'waiting',
      );

      final success = await SmsService().sendWelcomeMessage(
        testEntry,
        const Duration(minutes: 15),
      );

      setState(() {
        _testResult = success
            ? '✅ Welcome message sent successfully! Check your phone.'
            : '❌ Welcome message failed. Check console for details.';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Test missed notification
  Future<void> _testMissedNotification() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _testResult = '❌ Please enter a phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = '🔄 Testing missed notification...';
    });

    try {
      // Add +63 prefix to phone number
      final phoneNumber = '+63${_phoneController.text}';

      final testEntry = QueueEntry(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test User',
        ssuId: 'TEST123',
        email: 'test@example.com',
        phoneNumber: phoneNumber,
        department: 'CAS',
        purpose: 'TEST',
        timestamp: DateTime.now(),
        queueNumber: 999,
        status: 'waiting',
      );

      final success = await SmsService().sendQueueMissedNotification(testEntry);

      setState(() {
        _testResult = success
            ? '✅ Missed notification sent successfully! Check your phone.'
            : '❌ Missed notification failed. Check console for details.';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Test almost there message
  Future<void> _testAlmostThere() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _testResult = '❌ Please enter a phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = '🔄 Testing almost there message...';
    });

    try {
      // Add +63 prefix to phone number
      final phoneNumber = '+63${_phoneController.text}';

      final testEntry = QueueEntry(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test User',
        ssuId: 'TEST123',
        email: 'test@example.com',
        phoneNumber: phoneNumber,
        department: 'CAS',
        purpose: 'TEST',
        timestamp: DateTime.now(),
        queueNumber: 999,
        status: 'waiting',
      );

      final success = await SmsService().sendAlmostThereMessage(testEntry);

      setState(() {
        _testResult = success
            ? '✅ Almost there message sent successfully! Check your phone.'
            : '❌ Almost there message failed. Check console for details.';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Test & Configuration'),
        backgroundColor: const Color(0xFF263277),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SMS Configuration Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMS Configuration Status',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusRow(
                      'SMS Enabled',
                      _smsEnabled ? '✅ Enabled' : '❌ Disabled',
                    ),
                    _buildStatusRow(
                      'Default Provider',
                      SmsConfig.defaultProvider == 'email_sms'
                          ? 'Email-to-SMS (FREE) ✅'
                          : SmsConfig.defaultProvider,
                    ),
                    _buildStatusRow(
                      'Twilio Account SID',
                      SmsConfig.twilioAccountSid.isNotEmpty
                          ? '✅ Configured'
                          : '❌ Not Configured',
                    ),
                    _buildStatusRow(
                      'Twilio Auth Token',
                      SmsConfig.twilioAuthToken.isNotEmpty
                          ? '✅ Configured'
                          : '❌ Not Configured',
                    ),
                    _buildStatusRow(
                      'Twilio Phone Number',
                      SmsConfig.twilioPhoneNumber.isNotEmpty
                          ? '✅ Configured'
                          : '❌ Not Configured',
                    ),
                    _buildStatusRow(
                      'Max Retries',
                      SmsConfig.maxRetries.toString(),
                    ),
                    _buildStatusRow(
                      'Retry Delay',
                      '${SmsConfig.retryDelay.inSeconds}s',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Simple SMS Test
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔧 Simple SMS Test',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Test if your SMS service is working with a simple message',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone number input
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (e.g., 912345678)',
                        hintText: 'Enter number without +63 prefix',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 16),

                    // Provider selection
                    DropdownButtonFormField<String>(
                      value: _selectedProvider,
                      decoration: const InputDecoration(
                        labelText: 'SMS Provider',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.settings),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'email_sms',
                          child: Text('Email-to-SMS (FREE)'),
                        ),
                        DropdownMenuItem(
                          value: 'twilio',
                          child: Text('Twilio'),
                        ),
                        DropdownMenuItem(
                          value: 'aws_sns',
                          child: Text('AWS SNS'),
                        ),
                        DropdownMenuItem(
                          value: 'test',
                          child: Text('Test Mode'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedProvider = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Carrier selection (for Email-to-SMS)
                    if (_selectedProvider == 'email_sms')
                      Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedCarrier,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Network Provider',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.cell_tower),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Smart',
                                child: Text('Smart'),
                              ),
                              DropdownMenuItem(
                                value: 'Globe',
                                child: Text('Globe'),
                              ),
                              DropdownMenuItem(
                                value: 'TM',
                                child: Text('TM'),
                              ),
                              DropdownMenuItem(
                                value: 'Sun',
                                child: Text('Sun'),
                              ),
                              DropdownMenuItem(
                                value: 'TNT',
                                child: Text('TNT'),
                              ),
                              DropdownMenuItem(
                                value: 'DITO',
                                child: Text('DITO'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCarrier = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // Message input
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.message),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    // Test button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testSms,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          _isLoading ? 'Testing...' : 'Send Test SMS',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Result display
                    if (_testResult.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _testResult.startsWith('✅')
                              ? Colors.green.withOpacity(0.1)
                              : _testResult.startsWith('❌')
                              ? Colors.red.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _testResult.startsWith('✅')
                                ? Colors.green
                                : _testResult.startsWith('❌')
                                ? Colors.red
                                : Colors.blue,
                          ),
                        ),
                        child: Text(
                          _testResult,
                          style: TextStyle(
                            color: _testResult.startsWith('✅')
                                ? Colors.green.shade700
                                : _testResult.startsWith('❌')
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Queue Notification Tests
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Queue Notification Tests',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Test specific queue notification types',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Test buttons
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testQueueNotification,
                          icon: const Icon(Icons.queue),
                          label: const Text('Test Join'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testTop5Notification,
                          icon: const Icon(Icons.local_fire_department),
                          label: const Text('Test Top 5'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testWelcomeMessage,
                          icon: const Icon(Icons.waving_hand),
                          label: const Text('Test Welcome'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : _testMissedNotification,
                          icon: const Icon(Icons.timer_off),
                          label: const Text('Test Missed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testAlmostThere,
                          icon: const Icon(Icons.trending_up),
                          label: const Text('Test Almost There'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Troubleshooting Guide
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔍 Troubleshooting Guide',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildTroubleshootingItem(
                      '❌ No SMS received',
                      'Check phone number format (e.g., 912345678 - no +63 prefix needed)',
                    ),
                    _buildTroubleshootingItem(
                      '❌ Twilio error',
                      'Verify Account SID and Auth Token in sms_config.dart',
                    ),
                    _buildTroubleshootingItem(
                      '❌ Invalid phone number',
                      'Phone number should not start with + or 63 (e.g., 9202617059)',
                    ),
                    _buildTroubleshootingItem(
                      '❌ SMS disabled',
                      'Check enableSmsNotifications in sms_config.dart',
                    ),
                    _buildTroubleshootingItem(
                      '❌ Network error',
                      'Check internet connection and firewall settings',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: value.contains('❌')
                  ? Colors.red
                  : value.contains('✅')
                  ? Colors.green
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
