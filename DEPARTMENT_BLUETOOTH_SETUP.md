# Department-Specific Bluetooth Device Setup

## Overview

**Yes! Each department dashboard can connect to a different Bluetooth device.** This allows each department to have its own dedicated Bluetooth speaker for queue announcements.

## How It Works

### Department-Specific Storage

Each department's Bluetooth device connection is stored separately:

- **CAS** (College of Arts and Sciences) → `bluetooth_device_CAS`
- **COED** (College of Education) → `bluetooth_device_COED`
- **CONHS** (College of Nursing and Health Sciences) → `bluetooth_device_CONHS`
- **COENG** (College of Engineering) → `bluetooth_device_COENG`
- **CIT** (College of Industrial Technology) → `bluetooth_device_CIT`
- **CGS** (College of Graduating School) → `bluetooth_device_CGS`

### How Announcements Work

When a queue announcement is made:

1. The system identifies which department is making the announcement
2. It looks up the Bluetooth device connected to that specific department
3. It sends the announcement to that department's Bluetooth speaker
4. If no device is connected for that department, it falls back to local TTS

### Example Scenario

```
Department: CAS
├── Connected Device: "CAS Speaker Room 101"
└── Announcements go to: CAS Speaker Room 101

Department: COED  
├── Connected Device: "COED Speaker Room 201"
└── Announcements go to: COED Speaker Room 201

Department: CONHS
├── Connected Device: "CONHS Speaker Room 301"
└── Announcements go to: CONHS Speaker Room 301
```

## Setup Instructions

### Step 1: Login to Department Dashboard

1. Open the app
2. Login as an admin for a specific department (e.g., CAS admin)
3. You'll see the dashboard for that department

### Step 2: Access Bluetooth Settings

1. Click on **"Bluetooth Speaker"** in the menu
2. You'll see: "Bluetooth Speaker - [Department Name]"
3. This screen is specific to your department

### Step 3: Connect Your Department's Speaker

1. Tap **"Scan for Devices"**
2. Find your department's Bluetooth speaker in the list
3. Tap the device to connect
4. Wait for connection confirmation
5. Test with the **"Test"** button

### Step 4: Repeat for Other Departments

1. Logout and login as admin for another department
2. Repeat steps 2-3 to connect that department's speaker
3. Each department maintains its own connection independently

## Visual Indicators

### In Bluetooth Settings Screen

- **Department Name**: Shown in the title bar
- **Info Card**: Explains that this device is specific to the current department
- **Connected Device Card**: Shows which speaker is connected for this department
- **Green Indicator**: Confirms connection status

### In Dashboard

- When announcements are made, they automatically use the department's connected device
- No need to manually select which speaker to use

## Benefits

✅ **Independent Operation**: Each department operates independently  
✅ **No Conflicts**: Departments don't interfere with each other  
✅ **Flexible Setup**: Different speakers for different locations  
✅ **Easy Management**: Each admin manages only their department's speaker  
✅ **Automatic**: Announcements automatically use the correct speaker  

## Technical Details

### Storage

Device connections are saved using SharedPreferences:
```dart
'bluetooth_device_CAS' → Device ID
'bluetooth_device_COED' → Device ID
'bluetooth_device_CONHS' → Device ID
// etc.
```

### Service Architecture

```dart
BluetoothTtsService
├── _departmentDevices['CAS'] → BluetoothDevice
├── _departmentDevices['COED'] → BluetoothDevice
├── _departmentDevices['CONHS'] → BluetoothDevice
└── ... (one device per department)
```

### Announcement Flow

```dart
announceQueueNumber('CAS', 42, name: 'John')
  ↓
Check: _departmentDevices['CAS']
  ↓
If connected → Send to CAS speaker
If not → Fallback to local TTS
```

## Troubleshooting

### Device Not Connecting

1. Make sure you're logged in as the correct department admin
2. Check that the Bluetooth speaker is in pairing mode
3. Try disconnecting and reconnecting
4. Restart the app if needed

### Wrong Speaker Playing

1. Check which department you're logged into
2. Verify the connected device in Bluetooth settings
3. Make sure you connected the correct speaker for your department

### Multiple Departments Sharing One Speaker

If multiple departments need to use the same physical speaker:
- You can connect the same Bluetooth device to multiple departments
- However, announcements will only play on the speaker connected to the department making the announcement
- For shared speakers, consider using a single department account or a different setup

## Best Practices

1. **Label Your Speakers**: Name your Bluetooth speakers clearly (e.g., "CAS Room 101", "COED Room 201")
2. **Test After Setup**: Always test the connection after setting up
3. **Regular Checks**: Periodically verify connections are still active
4. **Documentation**: Keep a record of which speaker is connected to which department

## Example Setup

```
Physical Setup:
├── CAS Office (Room 101)
│   └── Bluetooth Speaker: "CAS-Speaker-101"
│       └── Connected to: CAS Dashboard
│
├── COED Office (Room 201)
│   └── Bluetooth Speaker: "COED-Speaker-201"
│       └── Connected to: COED Dashboard
│
└── CONHS Office (Room 301)
    └── Bluetooth Speaker: "CONHS-Speaker-301"
        └── Connected to: CONHS Dashboard
```

When CAS admin calls queue number 42:
→ Announcement plays on "CAS-Speaker-101" only

When COED admin calls queue number 15:
→ Announcement plays on "COED-Speaker-201" only

Each department's announcements are completely independent!








