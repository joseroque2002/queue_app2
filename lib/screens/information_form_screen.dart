import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/department_service.dart';
import '../services/purpose_service.dart';
import '../services/course_service.dart';
import '../models/queue_entry.dart';
import '../services/print_service.dart';
import '../services/queue_notification_service.dart';
import '../services/bluetooth_tts_service.dart';
// import 'package:printing/printing.dart'; // Commented out - package not available

class InformationFormScreen extends StatefulWidget {
  const InformationFormScreen({super.key});

  @override
  State<InformationFormScreen> createState() => _InformationFormScreenState();
}

class _InformationFormScreenState extends State<InformationFormScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ssuIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customPurposeController = TextEditingController();

  String _selectedDepartment = '';
  String _selectedPurpose = '';
  String? _selectedCourse;
  bool _isOthersPurpose = false;
  bool _isLoading = false;
  bool _showSuccess = false;
  QueueEntry? _assignedEntry;
  bool _isPwd = false; // Person with Disability
  bool _isSenior = false; // Senior Citizen
  bool _isPregnant = false; // Pregnant
  String _studentType = 'Student'; // Student or Graduated
  String? _selectedGender; // Gender selection
  String? _age; // Age input
  String? _graduationYear; // Graduation year (for graduated students)
  bool _emailSent = false; // Track if email notification was sent

  bool _showCourseSelection = false;
  final ScrollController _courseScrollController = ScrollController();

  List<String> _departments = [];
  List<String> _purposes = [];
  List<String> _courses = [];

  final SupabaseService _supabaseService = SupabaseService();
  final DepartmentService _departmentService = DepartmentService();
  final PurposeService _purposeService = PurposeService();
  final CourseService _courseService = CourseService();
  final QueueNotificationService _notificationService =
      QueueNotificationService();
  final BluetoothTtsService _bluetoothTtsService = BluetoothTtsService();

  @override
  void initState() {
    super.initState();

    // Initialize departments from service
    _departmentService.initializeDefaultDepartments();
    _departments = _departmentService.getDepartmentCodes();
    if (_departments.isNotEmpty) {
      _selectedDepartment = _departments.first;
    }

    // Initialize purposes from service
    _purposeService.initializeDefaultPurposes();
    _purposes = _purposeService.getPurposeNames();
    if (_purposes.isNotEmpty) {
      _selectedPurpose = _purposes.first;
    }

    // Initialize courses from service
    _initializeCourses();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _nameController.dispose();
    _ssuIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _customPurposeController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(
        const Duration(milliseconds: 1500),
      ); // Simulate processing

      // Check if queue is full
      try {
        final isQueueFull = await _supabaseService.isQueueFull();
        if (isQueueFull) {
          throw Exception('Queue is full. Please try again later.');
        }
      } catch (e) {
        if (e.toString().contains('SocketException') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('ClientException')) {
          throw Exception('Unable to connect to the queue system.\n\n'
              '📡 Network Connection Error\n\n'
              'Please check:\n'
              '• Your internet connection\n'
              '• WiFi or mobile data is enabled\n'
              '• The device is not in airplane mode\n\n'
              'If you\'re connected but still seeing this error, '
              'the queue system may be temporarily unavailable. '
              'Please try again in a few moments or contact the administrator.');
        }
        rethrow;
      }

      // Add +63 prefix to phone number
      final phoneNumber = '+63${_phoneController.text}';

      // Use custom purpose text if "Others" is selected, otherwise use selected purpose
      final purposeText = _isOthersPurpose && _customPurposeController.text.isNotEmpty
          ? _customPurposeController.text.trim()
          : _selectedPurpose;

      final entry = await _supabaseService.addQueueEntry(
        name: _nameController.text,
        ssuId: _ssuIdController.text,
        email: _emailController.text,
        phoneNumber: phoneNumber,
        department: _selectedDepartment,
        purpose: purposeText,
        course: _selectedCourse ?? '',
        isPwd: _isPwd,
        isSenior: _isSenior,
        isPregnant: _isPregnant,
        studentType: _studentType,
        gender: _selectedGender ?? '',
        age: _age != null && _age!.isNotEmpty
            ? int.tryParse(_age!)
            : null,
        graduationYear: _graduationYear != null && _graduationYear!.isNotEmpty
            ? int.tryParse(_graduationYear!)
            : null,
      );

      if (entry == null) {
        throw Exception('Unable to connect to the queue system.\n\n'
            'Please check:\n'
            '• Your internet connection\n'
            '• WiFi or mobile data is enabled\n\n'
            'If the problem persists, please contact the administrator.');
      }

      // Email notification is automatically sent by addQueueEntry
      // Set status to true (email sending happens in background)
      _emailSent = true; // Email is sent automatically in addQueueEntry

      // Send SMS notification that user has joined the queue
      try {
        await _notificationService.notifyQueueJoined(entry);
      } catch (e) {
        print('SMS notification failed: $e');
        // Don't fail the form submission if SMS fails
      }

      // Announce queue number via TTS
      try {
        await _bluetoothTtsService.announceQueueJoined(
          entry.department,
          entry.queueNumber,
          name: entry.name,
        );
      } catch (e) {
        print('TTS announcement failed: $e');
        // Don't fail the form submission if TTS fails
      }

      setState(() {
        _assignedEntry = entry;
        _showSuccess = true;
        _isLoading = false;
      });

      // Show print preview automatically after assigning
      if (mounted) {
        await _showPrintPreview(entry);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        
        // Show dialog for network errors, snackbar for others
        if (errorMessage.contains('Network Connection Error') ||
            errorMessage.contains('Unable to connect')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.red.shade700, size: 28),
                  const SizedBox(width: 12),
                  const Text('Connection Error'),
                ],
              ),
              content: Text(
                errorMessage,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _showPrintPreview(QueueEntry entry) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: Colors.white,
          child: SizedBox(
            width: 420,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF263277),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.print_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Print Preview',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Ticket Preview - Scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                    children: [
                      // Ticket Header
                      Text(
                        'QUEUE TICKET',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF263277),
                              letterSpacing: 1.2,
                            ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        height: 2,
                        color: Colors.grey.shade300,
                      ),
                      
                      // Reference Number - Prominently displayed at the top
                      if (entry.referenceNumber != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.shade600,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'REFERENCE NUMBER',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                entry.referenceNumber!,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                  letterSpacing: 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Priority Badge if applicable
                      if (entry.isPriority) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.shade400,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.priority_high_rounded,
                                color: Colors.green.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PRIORITY: ${entry.priorityType}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF263277).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Queue Number',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '#${entry.queueNumber.toString().padLeft(3, '0')}',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    color: const Color(0xFF263277),
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Customer Details
                      _buildDetailRow('Name', entry.name, context),
                      const SizedBox(height: 10),
                      _buildDetailRow('SSU ID', entry.ssuId, context),
                      const SizedBox(height: 10),
                      _buildDetailRow('Email', entry.email, context),
                      const SizedBox(height: 10),
                      _buildDetailRow('Phone', entry.phoneNumber, context),
                      if (entry.gender != null && entry.gender!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildDetailRow('Gender', entry.gender!, context),
                      ],
                      if (entry.age != null) ...[
                        const SizedBox(height: 10),
                        _buildDetailRow('Age', entry.age.toString(), context),
                      ],
                      
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        height: 1,
                        color: Colors.grey.shade300,
                      ),
                      
                      // Department and Purpose
                      _buildDetailRow(
                        'Department',
                        _departmentService.getDepartmentByCode(entry.department)?.name ?? entry.department,
                        context,
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow('Purpose', entry.purpose, context),
                      if (entry.course != null && entry.course!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          'Course',
                          _courseService.getCourseByCode(entry.course!)?.name ?? entry.course!,
                          context,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        'Student Type',
                        entry.studentType == 'Graduated' && entry.graduationYear != null
                            ? '${entry.studentType} (${entry.graduationYear})'
                            : entry.studentType,
                        context,
                      ),
                      
                      if (entry.isPriority) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.flash_on_rounded,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You have priority access! You will be served in the top 2 positions.',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // Footer
                      Text(
                        'Please wait for your number to be called',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateTime.now().toString().substring(0, 19),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade500,
                              fontSize: 10,
                            ),
                      ),
                    ],
                      ),
                    ),
                  ),
                ),
                // Print Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await PrintService.printTicket(entry: entry);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Print Ticket'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF263277),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _ssuIdController.clear();
    _emailController.clear();
    _phoneController.clear();
    _customPurposeController.clear();
    _selectedDepartment = _departments.isNotEmpty ? _departments.first : '';
    _selectedPurpose = _purposes.isNotEmpty ? _purposes.first : '';
    _selectedCourse = null;
    _loadCoursesForDepartment(_selectedDepartment);
    setState(() {
      _showSuccess = false;
      _assignedEntry = null;
      _isPwd = false;
      _isSenior = false;
      _isPregnant = false;
      _studentType = 'Student';
      _emailSent = false;
      _isOthersPurpose = false;
    });
  }

  Future<void> _initializeCourses() async {
    try {
      // Load courses from database
      await _courseService.initializeDefaultCourses();
      // Then load courses for the selected department
      if (mounted) {
        _loadCoursesForDepartment(_selectedDepartment);
      }
    } catch (e) {
      print('Error initializing courses: $e');
      // Try to load anyway
      if (mounted) {
        _loadCoursesForDepartment(_selectedDepartment);
      }
    }
  }

  void _loadAllCourses() {
    if (!mounted) return;
    
      setState(() {
      // Load all active courses from all departments
      final allCourses = _courseService.getActiveCourses();
      _courses = allCourses.map((course) => course.code).toList();
      print('Loaded ${_courses.length} courses for dropdown');
      if (_courses.isEmpty) {
        print('Warning: No courses found in database. Make sure courses are added via admin panel.');
      }
      // Don't auto-select a course when showing all courses
      if (_selectedCourse != null && !_courses.contains(_selectedCourse)) {
        _selectedCourse = null;
      }
    });
  }

  void _loadCoursesForDepartment(String departmentCode) {
    if (departmentCode.isEmpty) {
      _loadAllCourses();
      return;
    }
    
    setState(() {
      _courses = _courseService.getCourseCodesByDepartment(departmentCode);
      if (_selectedCourse != null && !_courses.contains(_selectedCourse)) {
        _selectedCourse = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2F8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              controller: _courseScrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF263277),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Header
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF263277),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                                  color: const Color(
                                    0xFF263277,
                                  ).withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 40,
                        child: ClipOval(
                          child: Image.asset(
                            'assets/queue_logo.jpg',
                            height: 80,
                            width: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF263277), Color(0xFF4A90E2)],
                      ).createShader(bounds),
                      child: Text(
                        'Queue Registration',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Roboto',
                              fontSize: 28,
                              letterSpacing: 0.5,
                              height: 1.2,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Enter your information to join the queue',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        letterSpacing: 0.3,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

                    const SizedBox(height: 24),

              // Success card
              if (_showSuccess && _assignedEntry != null)
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 48,
                          ),

                          const SizedBox(height: 16),

                          Text(
                            'Queue Number Assigned!',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Queue #${_assignedEntry!.queueNumber.toString().padLeft(3, '0')}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                                  'Department: ${_departmentService.getDepartmentByCode(_assignedEntry!.department)?.name ?? _assignedEntry!.department}\nPurpose: ${_assignedEntry!.purpose}${_assignedEntry!.course != null && _assignedEntry!.course!.isNotEmpty ? '\nCourse: ${_courseService.getCourseByCode(_assignedEntry!.course!)?.name ?? _assignedEntry!.course}' : ''}${_assignedEntry!.isPriority ? '\n🚀 Priority: ${_assignedEntry!.priorityType}' : ''}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          // Email notification status
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _emailSent ? Icons.email : Icons.email_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _emailSent
                                        ? '📧 Confirmation email sent to ${_assignedEntry!.email}\nCheck your Gmail inbox (including spam folder)'
                                        : '📧 Email notification will be sent to ${_assignedEntry!.email}\nPlease check your Gmail inbox',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (_assignedEntry != null) {
                                      await PrintService.printTicket(
                                        entry: _assignedEntry!,
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                          foregroundColor:
                                              Colors.green.shade600,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                    ),
                                  ),
                                  child: const Text('Print Ticket'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _resetForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                          foregroundColor:
                                              Colors.green.shade600,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                    ),
                                  ),
                                  child: const Text('Add Another'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Form
              if (!_showSuccess)
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Name field
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 20,
                                letterSpacing: 0.3,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                labelStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // SSU ID field
                            TextFormField(
                              controller: _ssuIdController,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 20,
                                letterSpacing: 0.3,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                labelText: 'SSU ID',
                                labelStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                      prefixIcon: const Icon(
                                        Icons.badge_outlined,
                                      ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your SSU ID';
                                }
                                return null;
                              },
                            ),

                                  const SizedBox(height: 14),

                            // Email field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 20,
                                letterSpacing: 0.3,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                      prefixIcon: const Icon(
                                        Icons.email_outlined,
                                      ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email address';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),

                                  const SizedBox(height: 14),

                            // Phone field
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 20,
                                letterSpacing: 0.3,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                      labelText:
                                          'Phone Number (e.g., 912345678)',
                                labelStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                hintText: 'Enter number without +63',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 20,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                      prefixIcon: const Icon(
                                        Icons.phone_outlined,
                                      ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                if (value.startsWith('+') ||
                                    value.startsWith('63')) {
                                  return 'Please enter number without +63 prefix';
                                }
                                return null;
                              },
                            ),

                                  const SizedBox(height: 14),

                            // Department dropdown
                            DropdownButtonFormField<String>(
                                    value: _selectedDepartment.isEmpty
                                        ? null
                                        : _selectedDepartment,
                              decoration: InputDecoration(
                                labelText: 'Department',
                                      prefixIcon: const Icon(
                                        Icons.business_outlined,
                                      ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                                    menuMaxHeight: 300,
                                    isExpanded: true,
                                    items: _departments.map((departmentCode) {
                                      final dept = _departmentService
                                          .getDepartmentByCode(departmentCode);
                                return DropdownMenuItem(
                                        value: departmentCode,
                                        child:                                         Text(
                                          dept != null
                                              ? '$departmentCode - ${dept.name}'
                                              : departmentCode,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 20,
                                            color: Colors.black,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedDepartment = value;
                                    _selectedCourse = null;
                                    _showCourseSelection = true;
                                  });
                                  _loadCoursesForDepartment(value);
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a department';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // Course Selection Checklist (appears after department selection)
                            if (_showCourseSelection) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.checklist_rounded,
                                          color: Colors.blue.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Select Your Course',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxHeight: 200),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: _courses.map((course) {
                                            final courseName = _courseService
                                                .getCourseByCode(course)
                                                ?.name ?? course;
                                            final isSelected = _selectedCourse == course;
                                            
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedCourse = course;
                                                  });
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: isSelected 
                                                        ? Colors.blue.shade100
                                                        : Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: isSelected 
                                                          ? Colors.blue.shade400
                                                          : Colors.grey.shade300,
                                                      width: isSelected ? 2 : 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        isSelected 
                                                            ? Icons.check_circle
                                                            : Icons.radio_button_unchecked,
                                                        color: isSelected 
                                                            ? Colors.blue.shade600
                                                            : Colors.grey.shade400,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              course,
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 14,
                                                                color: isSelected 
                                                                    ? Colors.blue.shade700
                                                                    : Colors.black87,
                                                              ),
                                                            ),
                                                            if (courseName != course)
                                                              Text(
                                                                courseName,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.grey.shade600,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                                  const SizedBox(height: 14),

                            // Course dropdown (shown for all departments) - REQUIRED
                              DropdownButtonFormField<String>(
                                value: _selectedCourse,
                                decoration: InputDecoration(
                                  labelText: 'Course *',
                                  prefixIcon: const Icon(
                                    Icons.book_outlined,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  helperText: _courses.isEmpty 
                                      ? 'No courses available' 
                                      : 'Select your course',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a course';
                                  }
                                  return null;
                                },
                                menuMaxHeight: 300,
                                isExpanded: true,
                                selectedItemBuilder: (BuildContext context) {
                                  if (_courses.isEmpty) {
                                    return [const Text(
                                      'No courses available',
                                      style: TextStyle(fontSize: 20),
                                    )];
                                  }
                                  return _courses.map((course) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        course,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 20,
                                          color: Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList();
                                },
                                items: _courses.isEmpty
                                    ? [
                                        const DropdownMenuItem(
                                          value: null,
                                          enabled: false,
                                          child: Text(
                                            'No courses available',
                                            style: TextStyle(fontSize: 20),
                                          ),
                                        )
                                      ]
                                    : _courses.map((course) {
                                  final courseName = _courseService
                                      .getCourseByCode(course)
                                      ?.name ?? course;
                                  return DropdownMenuItem(
                                    value: course,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          course,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 20,
                                            color: Colors.black,
                                          ),
                                        ),
                                        if (courseName != course)
                                          Text(
                                            courseName,
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCourse = value;
                                  });
                                },
                              ),

                                  const SizedBox(height: 14),

                            // Gender dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 20,
                                letterSpacing: 0.3,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                labelStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              menuMaxHeight: 200,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Male',
                                  child: Text(
                                    'Male',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 20,
                                      letterSpacing: 0.3,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Female',
                                  child: Text(
                                    'Female',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 20,
                                      letterSpacing: 0.3,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Other',
                                  child: Text(
                                    'Other',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 20,
                                      letterSpacing: 0.3,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Prefer not to say',
                                  child: Text(
                                    'Prefer not to say',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 20,
                                      letterSpacing: 0.3,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select gender';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Age field
                            TextFormField(
                              controller: TextEditingController(text: _age),
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 20,
                                letterSpacing: 0.3,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Age',
                                labelStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                hintText: 'Enter your age',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 20,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                prefixIcon: const Icon(
                                  Icons.cake_outlined,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _age = value;
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your age';
                                }
                                final age = int.tryParse(value);
                                if (age == null) {
                                  return 'Please enter a valid age';
                                }
                                if (age < 1 || age > 120) {
                                  return 'Please enter a valid age (1-120)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Student Type dropdown
                            DropdownButtonFormField<String>(
                              value: _studentType,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 20,
                                letterSpacing: 0.3,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Student Type',
                                labelStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                prefixIcon: const Icon(
                                  Icons.school_outlined,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              menuMaxHeight: 200,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Student',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Student',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 20,
                                          letterSpacing: 0.3,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Graduated',
                                  child: Row(
                                    children: [
                                      Icon(Icons.school, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Graduated',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 20,
                                          letterSpacing: 0.3,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _studentType = value!;
                                  // Clear graduation year if switching to Student
                                  if (_studentType == 'Student') {
                                    _graduationYear = null;
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select student type';
                                }
                                return null;
                              },
                            ),
                            
                            // Graduation Year field (only show if Graduated)
                            if (_studentType == 'Graduated') ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: TextEditingController(text: _graduationYear),
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 20,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Graduation Year',
                                  labelStyle: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 15,
                                    letterSpacing: 0.3,
                                    color: Colors.black,
                                  ),
                                  hintText: 'e.g., 2020, 2021, 2022',
                                  hintStyle: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 20,
                                    letterSpacing: 0.3,
                                    color: Colors.black,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  _graduationYear = value;
                                },
                                validator: (value) {
                                  if (_studentType == 'Graduated') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter graduation year';
                                    }
                                    final year = int.tryParse(value);
                                    if (year == null) {
                                      return 'Please enter a valid year';
                                    }
                                    final currentYear = DateTime.now().year;
                                    if (year < 1900 || year > currentYear) {
                                      return 'Please enter a valid year (1900-$currentYear)';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],

                                  const SizedBox(height: 14),

                            // Purpose dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedPurpose,
                              decoration: InputDecoration(
                                labelText: 'Purpose',
                                prefixIcon: const Icon(
                                  Icons.description_outlined,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                                    menuMaxHeight: 200,
                                    isExpanded: true,
                              items: [
                                ..._purposes.map((purpose) {
                                  return DropdownMenuItem(
                                    value: purpose,
                                    child: Text(
                                      purpose,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        color: Colors.black,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                const DropdownMenuItem(
                                  value: 'Others',
                                  child: Text(
                                    'Others',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedPurpose = value!;
                                  _isOthersPurpose = value == 'Others';
                                  if (!_isOthersPurpose) {
                                    _customPurposeController.clear();
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a purpose';
                                }
                                return null;
                              },
                            ),

                            // Custom purpose text field (shown when "Others" is selected)
                            if (_isOthersPurpose) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _customPurposeController,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 20,
                                  letterSpacing: 0.3,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Others',
                                  labelStyle: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 18,
                                    letterSpacing: 0.3,
                                    color: Colors.black,
                                  ),
                                  hintText: '(Specify your requested documents)',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 16,
                                    letterSpacing: 0.3,
                                    color: Colors.grey.shade600,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.edit_outlined,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                maxLines: 2,
                                validator: (value) {
                                  if (_isOthersPurpose) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please specify your requested documents';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],


                                  const SizedBox(height: 16),

                                  // Priority Section
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.priority_high_rounded,
                                              color: Colors.green.shade700,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Priority Queue',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade700,
                                                fontSize: 17,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Check if you qualify for priority processing:',
                                          style: TextStyle(
                                            color: Colors.green.shade600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // PWD Checkbox
                                        CheckboxListTile(
                                          value: _isPwd,
                                          onChanged: (value) {
                                            setState(() {
                                              _isPwd = value ?? false;
                                            });
                                          },
                                          title: const Text(
                                            'Person with Disability (PWD)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                          ),
                                          subtitle: const Text(
                                            'I am a person with disability',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                          activeColor: Colors.green.shade600,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                        ),

                                        // Senior Checkbox
                                        CheckboxListTile(
                                          value: _isSenior,
                                          onChanged: (value) {
                                            setState(() {
                                              _isSenior = value ?? false;
                                            });
                                          },
                                          title: const Text(
                                            'Senior Citizen',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                          ),
                                          subtitle: const Text(
                                            'I am 60 years old or above',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                          activeColor: Colors.green.shade600,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                        ),

                                        // Pregnant Checkbox
                                        CheckboxListTile(
                                          value: _isPregnant,
                                          onChanged: (value) {
                                            setState(() {
                                              _isPregnant = value ?? false;
                                            });
                                          },
                                          title: const Text(
                                            'Pregnant',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                          ),
                                          subtitle: const Text(
                                            'I am currently pregnant',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                          activeColor: Colors.green.shade600,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                        ),

                                        if (_isPwd || _isSenior || _isPregnant) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.flash_on_rounded,
                                                  color: Colors.green.shade700,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'You will be prioritized in the queue!',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.green.shade700,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
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

                                  const SizedBox(height: 20),

                            // Submit button
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _submitForm,
                                  style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF263277,
                                          ),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                    ),
                                    shadowColor: const Color(
                                      0xFF263277,
                                    ).withOpacity(0.3),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                                  const Icon(
                                                    Icons.queue_rounded,
                                                  ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Join Queue',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
              ),
            );
          },
        ),
      ),
    );
  }
}
