# Queue Management App - Code Structure

This Flutter app has been organized into a clean, modular structure for better maintainability and scalability.

## Directory Structure

```
lib/
├── main.dart                 # App entry point
├── constants/               # App-wide constants
│   ├── app_colors.dart     # Color definitions
│   └── app_strings.dart    # Text strings
├── models/                 # Data models
│   └── queue_entry.dart    # Queue entry model
├── screens/                # UI screens
│   ├── welcome_screen.dart
│   ├── queue_home_screen.dart
│   ├── information_form_screen.dart
│   ├── view_queue_screen.dart
│   └── admin_screen.dart
├── services/               # Business logic
│   └── queue_service.dart  # Queue management service
└── widgets/                # Reusable UI components
    └── common_widgets.dart # Common widgets
```

## Key Features

### 1. **Modular Screen Organization**
- Each screen is in its own file under `screens/`
- Easy to locate and modify specific screens
- Better code separation and maintainability

### 2. **Constants Management**
- **`app_colors.dart`**: Centralized color definitions
- **`app_strings.dart`**: All text strings in one place
- Easy to maintain consistent theming and support localization

### 3. **Reusable Components**
- **`common_widgets.dart`**: Shared UI components
- Reduces code duplication
- Consistent styling across the app

### 4. **Data Models**
- **`queue_entry.dart`**: Structured data model
- JSON serialization support
- Type-safe data handling

### 5. **Business Logic**
- **`queue_service.dart`**: Singleton service for queue management
- Centralized data operations
- Easy to extend with database integration

## Benefits of This Structure

1. **Maintainability**: Easy to find and modify specific functionality
2. **Scalability**: New features can be added without affecting existing code
3. **Reusability**: Common components can be reused across screens
4. **Testing**: Each module can be tested independently
5. **Team Development**: Multiple developers can work on different modules simultaneously

## Usage Examples

### Using Constants
```dart
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

// Use colors
color: AppColors.primaryBlue

// Use strings
Text(AppStrings.welcomeTitle)
```

### Using Common Widgets
```dart
import '../widgets/common_widgets.dart';

// Use logo widget
CommonWidgets.logoWithBorder()

// Use back button
CommonWidgets.backButton(onPressed: () => Navigator.pop(context))
```

### Using Queue Service
```dart
import '../services/queue_service.dart';

final queueService = QueueService();
final newEntry = queueService.addEntry(
  name: 'John Doe',
  ssuId: '12345',
  // ... other parameters
);
```

## Future Enhancements

1. **State Management**: Add Provider, Bloc, or Riverpod for state management
2. **Database Integration**: Replace in-memory storage with SQLite or Firebase
3. **API Integration**: Add backend API calls
4. **Localization**: Implement multi-language support
5. **Testing**: Add unit and widget tests
6. **Theme Management**: Add dark/light theme support
