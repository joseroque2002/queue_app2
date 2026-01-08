# Bluetooth TTS Implementation Guide

## Overview

This implementation adds Bluetooth-connected text-to-speech (TTS) functionality to all dashboards in the queue management system. Each department can have its own Bluetooth speaker device that announces queue numbers and calls.

## Features

### 1. Bluetooth TTS Service (`lib/services/bluetooth_tts_service.dart`)
- **Department-Specific Devices**: Each department (CAS, COED, CONHS, COENG, CIT, CGS) can have its own Bluetooth speaker
- **Automatic Connection**: Saves and restores Bluetooth device connections per department
- **Fallback to Local TTS**: If Bluetooth device is not connected, uses device's built-in TTS
- **Queue Announcements**: Automatically announces when someone is next in queue

### 2. Bluetooth Device Management Screen (`lib/screens/bluetooth_device_screen.dart`)
- **Device Scanning**: Scan for available Bluetooth devices
- **Device Connection**: Connect/disconnect Bluetooth speakers for each department
- **Connection Status**: Visual indicator showing connected device
- **Test Functionality**: Test announcements on connected device

### 3. Integration Points

#### Admin Dashboard (`lib/screens/admin_screen.dart`)
- **Automatic Announcements**: When someone becomes next in queue, automatically announces
- **Call Announcements**: When countdown starts, announces "Calling [name], queue number [number]"
- **Bluetooth Menu**: Added "Bluetooth Speaker" menu item to access device settings

#### View Queue Screen (`lib/screens/view_queue_screen.dart`)
- **Next Person Announcements**: Automatically announces when someone becomes the next person in queue for any department

## Announcement Messages

The system announces:
- **Next in Queue**: "Attention [name], you're next. Queue number [number], please be ready."
- **Calling**: "Calling [name], queue number [number]. Please proceed to the counter."

## Setup Instructions

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Android Permissions
Bluetooth permissions have been added to `android/app/src/main/AndroidManifest.xml`:
- `BLUETOOTH` (for Android 10 and below)
- `BLUETOOTH_ADMIN` (for Android 10 and below)
- `BLUETOOTH_SCAN` (for Android 12+)
- `BLUETOOTH_CONNECT` (for Android 12+)

### 3. Connect Bluetooth Devices

1. Open the Admin Dashboard
2. Click on "Bluetooth Speaker" in the menu
3. Tap "Scan for Devices"
4. Select your Bluetooth speaker from the list
5. Wait for connection confirmation
6. Test the connection using the "Test" button

### 4. Per-Department Configuration

Each department can have its own Bluetooth device:
- CAS (College of Arts and Sciences)
- COED (College of Education)
- CONHS (College of Nursing and Health Sciences)
- COENG (College of Engineering)
- CIT (College of Industrial Technology)
- CGS (College of Graduating School)

## How It Works

1. **Initialization**: The Bluetooth TTS service initializes when the app starts
2. **Device Connection**: Admin connects a Bluetooth speaker for their department
3. **Automatic Announcements**: 
   - When someone becomes next in queue → Announces "you're next"
   - When countdown starts → Announces "calling [name]"
4. **Fallback**: If no Bluetooth device is connected, uses device's built-in TTS

## Technical Details

### Dependencies Added
- `flutter_blue_plus: ^1.32.0` - Bluetooth functionality
- `flutter_tts: ^4.1.0` - Text-to-speech
- `shared_preferences: ^2.2.2` - Store device connections

### Service Architecture
- **Singleton Pattern**: `BluetoothTtsService` uses singleton pattern for global access
- **State Management**: Tracks connected devices per department
- **Error Handling**: Graceful fallback to local TTS on errors

## Usage Examples

### Manual Announcement
```dart
await BluetoothTtsService().announceQueueNumber(
  'CAS',
  42,
  name: 'John Doe',
);
```

### Calling Announcement
```dart
await BluetoothTtsService().announceCalling(
  'CAS',
  42,
  name: 'John Doe',
);
```

## Windows Build Issues

**Note**: The `flutter_tts` plugin may have CMake build errors on Windows. If you encounter this:

1. **Option 1**: Build for Android/iOS/macOS/Linux instead (recommended for production)
2. **Option 2**: The service will gracefully handle TTS initialization failures and continue working with Bluetooth-only functionality
3. **Option 3**: For Windows development, you can temporarily comment out TTS calls or use platform channels to call Windows native TTS APIs

The Bluetooth functionality will still work on Windows, but TTS fallback may not be available.

## Troubleshooting

### CMake Error on Windows
If you see: `CMake Error at flutter/ephemeral/.plugin_symlinks/flutter_tts/windows/CMakeLists.txt`

**Solution**: The service handles this gracefully. TTS initialization will fail silently, but Bluetooth connections will still work. For full TTS support, build for Android/iOS/macOS/Linux.

### Bluetooth Not Working
1. Ensure Bluetooth is enabled on the device
2. Check if Bluetooth permissions are granted
3. Verify the Bluetooth speaker is in pairing mode
4. Try disconnecting and reconnecting the device

### No Sound
1. Check if Bluetooth device is connected (green indicator in settings)
2. Verify device volume is turned up
3. Test with the "Test" button
4. Check if fallback TTS works (disconnect Bluetooth and test)
5. On Windows, TTS may not be available - use Bluetooth speakers directly

### Device Not Found
1. Ensure Bluetooth speaker is in pairing/discoverable mode
2. Try scanning again
3. Check if device is already connected to another device
4. Restart Bluetooth on both devices

## Future Enhancements

- Volume control per department
- Custom announcement messages per department
- Multiple Bluetooth devices per department (for larger areas)
- Announcement scheduling and queuing
- Voice selection and language options

