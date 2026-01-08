import 'package:flutter/material.dart';
import '../models/admin_user.dart';
import '../models/course.dart';
import '../services/admin_service.dart';
import '../services/course_service.dart';
import '../services/department_service.dart';

class CourseManagementScreen extends StatefulWidget {
  final AdminUser adminUser;
  final String? departmentCode; // Optional: filter by department

  const CourseManagementScreen({
    super.key,
    required this.adminUser,
    this.departmentCode,
  });

  @override
  State<CourseManagementScreen> createState() =>
      _CourseManagementScreenState();
}

class _CourseManagementScreenState extends State<CourseManagementScreen> {
  final AdminService _adminService = AdminService();
  final CourseService _courseService = CourseService();
  final DepartmentService _departmentService = DepartmentService();

  List<Course> _courses = [];
  List<String> _departments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _loadCourses();
  }

  void _loadDepartments() {
    _departmentService.initializeDefaultDepartments();
    _departments = _departmentService.getDepartmentCodes();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.departmentCode != null) {
        _courses = _courseService.getCoursesByDepartment(widget.departmentCode!);
      } else {
        _courses = _courseService.getAllCourses();
      }
    } catch (e) {
      _showErrorSnackBar('Error loading courses: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showAddCourseDialog() {
    if (!_adminService.isLoggedIn) {
      _showErrorSnackBar('Admin session expired. Please login again.');
      return;
    }

    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedDept = widget.departmentCode ?? _departments.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Course'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show department dropdown for master admin or when no specific department is set
                if (_adminService.isMasterAdmin || widget.departmentCode == null)
                  DropdownButtonFormField<String>(
                    value: selectedDept,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    items: _departments.map((dept) {
                      return DropdownMenuItem(
                        value: dept,
                        child: Text(dept),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDept = value;
                      });
                    },
                  )
                else
                  // Show read-only department for department admins
                  TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    controller: TextEditingController(text: widget.departmentCode),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Course Code (e.g., BSIT)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Course Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty ||
                    selectedDept == null) {
                  _showErrorSnackBar('All fields are required');
                  return;
                }

                try {
                  await _courseService.addCourse(
                    code: codeController.text.trim(),
                    name: nameController.text.trim(),
                    departmentCode: selectedDept!,
                    description: descriptionController.text.trim(),
                  );
                  Navigator.pop(context);
                  await _loadCourses();
                  _showSuccessSnackBar('Course added successfully');
                } catch (e) {
                  _showErrorSnackBar('Error adding course: ${e.toString().replaceAll('Exception: ', '')}');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCourseDialog(Course course) {
    if (!_adminService.isLoggedIn) {
      _showErrorSnackBar('Admin session expired. Please login again.');
      return;
    }

    final codeController = TextEditingController(text: course.code);
    final nameController = TextEditingController(text: course.name);
    final descriptionController = TextEditingController(text: course.description);
    String? selectedDept = course.departmentCode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Course'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDept,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                  items: _departments.map((dept) {
                    return DropdownMenuItem(
                      value: dept,
                      child: Text(dept),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedDept = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Course Code',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Course Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty ||
                    selectedDept == null) {
                  _showErrorSnackBar('All fields are required');
                  return;
                }

                try {
                  await _courseService.updateCourse(
                    course.id,
                    code: codeController.text.trim(),
                    name: nameController.text.trim(),
                    departmentCode: selectedDept,
                    description: descriptionController.text.trim(),
                  );
                  Navigator.pop(context);
                  await _loadCourses();
                  _showSuccessSnackBar('Course updated successfully');
                } catch (e) {
                  _showErrorSnackBar('Error updating course: ${e.toString().replaceAll('Exception: ', '')}');
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCourseStatus(Course course) async {
    if (!_adminService.isLoggedIn) {
      _showErrorSnackBar('Admin session expired. Please login again.');
      return;
    }

    try {
      await _courseService.updateCourse(
        course.id,
        isActive: !course.isActive,
      );
      await _loadCourses();
      _showSuccessSnackBar(
        'Course ${course.isActive ? 'deactivated' : 'activated'} successfully',
      );
    } catch (e) {
      _showErrorSnackBar('Error updating course status: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Widget _buildCourseCard(Course course) {
    final deptName = _departmentService
        .getDepartmentByCode(course.departmentCode)
        ?.name ?? course.departmentCode;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF263277),
                        const Color(0xFF4A90E2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    course.code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    course.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: course.isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    course.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.school, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  deptName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (course.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                course.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                if (_adminService.isLoggedIn && _adminService.canModifyDepartments) ...[
                  IconButton(
                    onPressed: () => _showEditCourseDialog(course),
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Edit Course',
                    color: const Color(0xFF263277),
                  ),
                  IconButton(
                    onPressed: () => _toggleCourseStatus(course),
                    icon: Icon(
                      course.isActive
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 20,
                    ),
                    tooltip: course.isActive ? 'Deactivate' : 'Activate',
                    color: course.isActive ? Colors.orange : Colors.green,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2F8),
      appBar: AppBar(
        title: Text(
          widget.departmentCode != null
              ? 'Courses - ${widget.departmentCode}'
              : 'Course Management',
        ),
        backgroundColor: const Color(0xFF263277),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add Button
                    Row(
                      children: [
                        const Spacer(),
                        if (_adminService.isLoggedIn && _adminService.canModifyDepartments)
                          ElevatedButton.icon(
                            onPressed: _showAddCourseDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Course'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF263277),
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Statistics
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard(
                            'Total',
                            _courses.length.toString(),
                            Icons.book,
                            Colors.blue,
                          ),
                          _buildStatCard(
                            'Active',
                            _courses.where((c) => c.isActive).length.toString(),
                            Icons.check_circle,
                            Colors.green,
                          ),
                          _buildStatCard(
                            'Inactive',
                            _courses.where((c) => !c.isActive).length.toString(),
                            Icons.cancel,
                            Colors.red,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Courses List
                    Expanded(
                      child: _courses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.book_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No courses found',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 8),
                              itemCount: _courses.length,
                              itemBuilder: (context, index) {
                                return _buildCourseCard(_courses[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

