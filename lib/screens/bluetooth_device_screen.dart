import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_tts_service.dart';
import '../services/department_service.dart';

class BluetoothDeviceScreen extends StatefulWidget {
  final String department;

  const BluetoothDeviceScreen({super.key, required this.department});

  @override
  State<BluetoothDeviceScreen> createState() => _BluetoothDeviceScreenState();
}

class _BluetoothDeviceScreenState extends State<BluetoothDeviceScreen> {
  final BluetoothTtsService _bluetoothTtsService = BluetoothTtsService();
  final DepartmentService _departmentService = DepartmentService();
  
  List<BluetoothDevice> _availableDevices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  BluetoothDevice? _connectedDevice;
  bool _isBluetoothEnabled = false;
  bool _isBluetoothSupported = false;
  BluetoothAdapterState? _bluetoothState;

  @override
  void initState() {
    super.initState();
    _loadConnectedDevice();
    _checkBluetoothStatus();
    // Listen to Bluetooth state changes
    FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _bluetoothState = state;
        _isBluetoothEnabled = state == BluetoothAdapterState.on;
      });
    });
  }

  Future<void> _checkBluetoothStatus() async {
    try {
      // Check if Bluetooth is supported
      try {
        _isBluetoothSupported = await FlutterBluePlus.isSupported;
      } catch (e) {
        // Platform doesn't support flutter_blue_plus
        if (e.toString().contains('unsupported') || e.toString().contains('UnsupportedOperation')) {
          _isBluetoothSupported = false;
          setState(() {
            _isBluetoothEnabled = false;
          });
          return;
        } else {
          rethrow;
        }
      }
      
      if (!_isBluetoothSupported) {
        setState(() {
          _isBluetoothEnabled = false;
        });
        return;
      }

      try {
        _bluetoothState = await FlutterBluePlus.adapterState.first;
        _isBluetoothEnabled = _bluetoothState == BluetoothAdapterState.on;
      } catch (e) {
        print('Error checking Bluetooth adapter state: $e');
        _isBluetoothEnabled = false;
      }
      
      setState(() {});
    } catch (e) {
      print('Error checking Bluetooth status: $e');
      if (e.toString().contains('unsupported') || e.toString().contains('UnsupportedOperation')) {
        _isBluetoothSupported = false;
      }
      setState(() {
        _isBluetoothEnabled = false;
      });
    }
  }

  Future<void> _requestEnableBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
      await _checkBluetoothStatus();
      _showSuccessSnackBar('Bluetooth enabled successfully');
    } catch (e) {
      _showErrorSnackBar('Could not enable Bluetooth. Please enable it manually in settings.');
    }
  }

  Future<void> _loadConnectedDevice() async {
    final device = _bluetoothTtsService.getDevice(widget.department);
    if (device != null && _bluetoothTtsService.isConnected(widget.department)) {
      setState(() {
        _connectedDevice = device;
      });
    }
  }

  Future<void> _scanForDevices() async {
    // Check Bluetooth status before scanning
    await _checkBluetoothStatus();
    
    if (!_isBluetoothSupported) {
      _showErrorSnackBar('Bluetooth is not supported on this device');
      return;
    }

    if (!_isBluetoothEnabled) {
      _showErrorSnackBar('Please enable Bluetooth first');
      // Show dialog to enable Bluetooth
      _showEnableBluetoothDialog();
      return;
    }

    setState(() {
      _isScanning = true;
      _availableDevices = [];
    });

    try {
      final devices = await _bluetoothTtsService.scanForDevices();
      setState(() {
        _availableDevices = devices;
        _isScanning = false;
      });
      
      if (devices.isEmpty) {
        _showErrorSnackBar('No Bluetooth devices found. Make sure devices are in pairing mode.');
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      
      String errorMessage = e.toString();
      
      // Handle specific error cases
      if (errorMessage.contains('Bluetooth is not enabled')) {
        _showEnableBluetoothDialog();
      } else if (errorMessage.contains('cancelled') || 
                 errorMessage.contains('Device selection cancelled')) {
        // User cancelled device selection (web platform)
        _showInfoSnackBar('Device selection was cancelled. Please try again and select a device when the browser prompts you.');
      } else if (errorMessage.contains('not supported')) {
        _showErrorSnackBar('Bluetooth is not supported on this platform. Use Android, iOS, macOS, or Linux for Bluetooth functionality.');
      } else {
        // Show user-friendly error message
        String friendlyMessage = 'Unable to scan for devices. ';
        if (errorMessage.contains('web')) {
          friendlyMessage += 'On web, make sure to select a device when the browser prompts you.';
        } else {
          friendlyMessage += 'Please ensure Bluetooth is enabled and devices are in pairing mode.';
        }
        _showErrorSnackBar(friendlyMessage);
      }
    }
  }

  void _showEnableBluetoothDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.orange),
            SizedBox(width: 8),
            Text('Bluetooth Disabled'),
          ],
        ),
        content: const Text(
          'Bluetooth must be enabled to scan for devices.\n\n'
          'Please enable Bluetooth in your device settings and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _requestEnableBluetooth();
            },
            icon: const Icon(Icons.bluetooth),
            label: const Text('Enable Bluetooth'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF263277),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final success = await _bluetoothTtsService.connectToDevice(
        widget.department,
        device,
      );

      if (success) {
        setState(() {
          _connectedDevice = device;
          _isConnecting = false;
        });
        _showSuccessSnackBar('Connected to ${device.platformName}');
        
        // Test announcement
        await _bluetoothTtsService.announceQueueNumber(
          widget.department,
          1,
          name: 'Test',
        );
      } else {
        setState(() {
          _isConnecting = false;
        });
        _showErrorSnackBar('Failed to connect to device');
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
      });
      _showErrorSnackBar('Error connecting: $e');
    }
  }

  Future<void> _disconnectDevice() async {
    try {
      await _bluetoothTtsService.disconnectDevice(widget.department);
      setState(() {
        _connectedDevice = null;
      });
      _showSuccessSnackBar('Disconnected from device');
    } catch (e) {
      _showErrorSnackBar('Error disconnecting: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final department = _departmentService.getDepartmentByCode(widget.department);
    final departmentName = department?.name ?? widget.department;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F2F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bluetooth Speaker',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF263277),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              departmentName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF263277).withOpacity(0.7),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF263277)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bluetooth status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: !_isBluetoothSupported
                    ? Colors.grey.shade100
                    : _isBluetoothEnabled 
                        ? Colors.green.shade50 
                        : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_isBluetoothSupported
                      ? Colors.grey
                      : _isBluetoothEnabled 
                          ? Colors.green 
                          : Colors.orange,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        !_isBluetoothSupported
                            ? Icons.bluetooth_disabled
                            : _isBluetoothEnabled 
                                ? Icons.bluetooth_connected 
                                : Icons.bluetooth_disabled,
                        color: !_isBluetoothSupported
                            ? Colors.grey.shade700
                            : _isBluetoothEnabled 
                                ? Colors.green.shade700 
                                : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        !_isBluetoothSupported
                            ? 'Bluetooth Not Supported'
                            : _isBluetoothEnabled 
                                ? 'Bluetooth Enabled' 
                                : 'Bluetooth Disabled',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: !_isBluetoothSupported
                              ? Colors.grey.shade700
                              : _isBluetoothEnabled 
                                  ? Colors.green.shade700 
                                  : Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (!_isBluetoothSupported) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Bluetooth is not supported on this platform (e.g., Windows desktop). '
                      'Bluetooth functionality is available on Android, iOS, macOS, and Linux.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ] else if (!_isBluetoothEnabled) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Please enable Bluetooth to scan for devices.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _requestEnableBluetooth,
                        icon: const Icon(Icons.bluetooth),
                        label: const Text('Enable Bluetooth'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Info card explaining how announcements work
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.volume_up, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Announcements play through device speakers',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Queue announcements will automatically play through this device\'s speakers using text-to-speech. '
                    'Bluetooth speakers are optional for remote audio output.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),

            // Info card explaining department-specific Bluetooth device (optional)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF263277).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF263277).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bluetooth, color: const Color(0xFF263277)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Optional: Bluetooth Speaker',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF263277),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can optionally connect a Bluetooth speaker for $departmentName to also play announcements remotely. '
                    'Each department can have its own Bluetooth speaker.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF263277),
                    ),
                  ),
                  // Web platform note
                  if (kIsWeb) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.web, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'On web: When scanning, your browser will show a device selection dialog. Please select your Bluetooth speaker when prompted.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Connected device card
            if (_connectedDevice != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bluetooth_connected, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Connected Device for $departmentName',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connectedDevice!.platformName.isNotEmpty
                          ? _connectedDevice!.platformName
                          : 'Unknown Device',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      _connectedDevice!.remoteId.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isConnecting ? null : _disconnectDevice,
                            icon: const Icon(Icons.bluetooth_disabled),
                            label: const Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isConnecting
                                ? null
                                : () async {
                                    await _bluetoothTtsService.announceQueueNumber(
                                      widget.department,
                                      999,
                                      name: 'Test',
                                    );
                                  },
                            icon: const Icon(Icons.volume_up),
                            label: const Text('Test'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Scan button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (!_isBluetoothSupported || _isScanning || _isConnecting || !_isBluetoothEnabled) 
                    ? null 
                    : _scanForDevices,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(
                  !_isBluetoothSupported
                      ? 'Bluetooth Not Supported'
                      : _isScanning 
                          ? 'Scanning...' 
                          : !_isBluetoothEnabled
                              ? 'Enable Bluetooth First'
                              : 'Scan for Devices',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (!_isBluetoothSupported || !_isBluetoothEnabled)
                      ? Colors.grey
                      : const Color(0xFF263277),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Available devices list
            Text(
              'Available Devices',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF263277),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _isScanning
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF263277)),
                          SizedBox(height: 16),
                          Text('Scanning for Bluetooth devices...'),
                        ],
                      ),
                    )
                  : _availableDevices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth_disabled,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No devices found',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap "Scan for Devices" to search',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _availableDevices.length,
                          itemBuilder: (context, index) {
                            final device = _availableDevices[index];
                            final isConnected = _connectedDevice?.remoteId == device.remoteId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isConnected ? Colors.green : Colors.grey.shade300,
                                  width: isConnected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: Icon(
                                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                                  color: isConnected ? Colors.green : const Color(0xFF263277),
                                ),
                                title: Text(
                                  device.platformName.isNotEmpty
                                      ? device.platformName
                                      : 'Unknown Device',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  device.remoteId.toString(),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: _isConnecting && !isConnected
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : isConnected
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : IconButton(
                                            icon: const Icon(Icons.link),
                                            onPressed: () => _connectToDevice(device),
                                          ),
                                onTap: isConnected ? null : () => _connectToDevice(device),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

