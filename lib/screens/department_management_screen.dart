import 'package:flutter/material.dart';
import '../models/admin_user.dart';
import '../models/department.dart';
import '../services/admin_service.dart';
import '../services/department_service.dart';
import '../services/supabase_service.dart';
import 'course_management_screen.dart';

class DepartmentManagementScreen extends StatefulWidget {
  final AdminUser adminUser;

  const DepartmentManagementScreen({super.key, required this.adminUser});

  @override
  State<DepartmentManagementScreen> createState() =>
      _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState
    extends State<DepartmentManagementScreen> {
  final AdminService _adminService = AdminService();
  final DepartmentService _departmentService = DepartmentService();
  final SupabaseService _supabaseService = SupabaseService();

  List<Department> _departments = [];
  Map<String, Map<String, int>> _departmentStats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    
    // Refresh statistics periodically
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadDepartmentStatistics();
      }
    });
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load departments from database
      await _departmentService.initializeDefaultDepartments();
      _departments = _departmentService.getAllDepartments();
      await _loadDepartmentStatistics();
    } catch (e) {
      _showErrorSnackBar('Error loading departments: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDepartmentStatistics() async {
    try {
      final Map<String, Map<String, int>> stats = {};
      
      for (final dept in _departments) {
        final deptStats = await _supabaseService.getDepartmentQueueStatistics(dept.code);
        stats[dept.code] = {
          'waiting': deptStats['waiting'] ?? 0,
          'current': deptStats['current'] ?? 0,
          'completed': deptStats['completed'] ?? 0,
          'missed': deptStats['missed'] ?? 0,
          'total': deptStats['total'] ?? 0,
        };
      }
      
      setState(() {
        _departmentStats = stats;
      });
    } catch (e) {
      print('Error loading department statistics: $e');
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

  void _showAddDepartmentDialog() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Department Code (e.g., CAS)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Department Name',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.trim().isEmpty ||
                  nameController.text.trim().isEmpty) {
                _showErrorSnackBar('Code and name are required');
                return;
              }

              try {
                await _departmentService.addDepartment(
                  code: codeController.text.trim().toUpperCase(),
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                Navigator.pop(context);
                await _loadDepartments();
                _showSuccessSnackBar('Department added successfully');
              } catch (e) {
                _showErrorSnackBar('Error adding department: ${e.toString().replaceAll('Exception: ', '')}');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDepartmentDialog(Department department) {
    if (!_adminService.isLoggedIn) {
      _showErrorSnackBar('Admin session expired. Please login again.');
      return;
    }

    final codeController = TextEditingController(text: department.code);
    final nameController = TextEditingController(text: department.name);
    final descriptionController = TextEditingController(
      text: department.description,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Department'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Department Code',
                  border: OutlineInputBorder(),
                  helperText: 'Unique code for the department',
                ),
                textCapitalization: TextCapitalization.characters,
                enabled: _adminService.isMasterAdmin, // Only master admin can change code
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Department Name *',
                  border: OutlineInputBorder(),
                  helperText: 'Full name of the department/college',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  helperText: 'Brief description of the department',
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
                  nameController.text.trim().isEmpty) {
                _showErrorSnackBar('Code and name are required');
                return;
              }

              try {
                await _departmentService.updateDepartment(
                  department.id,
                  code: codeController.text.trim().toUpperCase(),
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                Navigator.pop(context);
                await _loadDepartments();
                _showSuccessSnackBar('Department updated successfully');
              } catch (e) {
                _showErrorSnackBar('Error updating department: ${e.toString().replaceAll('Exception: ', '')}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF263277),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDepartmentStatus(Department department) async {
    try {
      await _departmentService.updateDepartment(
        department.id,
        isActive: !department.isActive,
      );
      await _loadDepartments();
      _showSuccessSnackBar(
        'Department ${department.isActive ? 'deactivated' : 'activated'} successfully',
      );
    } catch (e) {
      _showErrorSnackBar('Error updating department status: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _showDeleteDepartmentDialog(Department department) {
    if (!_adminService.isLoggedIn) {
      _showErrorSnackBar('Admin session expired. Please login again.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this department?',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Warning',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Department: ${department.code} - ${department.name}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This will deactivate the department. It can be reactivated later.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _departmentService.deleteDepartment(department.id);
                Navigator.pop(context);
                await _loadDepartments();
                _showSuccessSnackBar('Department deleted successfully');
              } catch (e) {
                _showErrorSnackBar('Error deleting department: ${e.toString().replaceAll('Exception: ', '')}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPermanentDeleteDialog(Department department) {
    if (!_adminService.isLoggedIn || !_adminService.isMasterAdmin) {
      _showErrorSnackBar('Only master admin can permanently delete departments');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action cannot be undone!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Permanent Deletion',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Department: ${department.code} - ${department.name}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will permanently remove the department from the system. All associated data will be lost.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _departmentService.removeDepartment(department.id);
                Navigator.pop(context);
                await _loadDepartments();
                _showSuccessSnackBar('Department permanently deleted');
              } catch (e) {
                _showErrorSnackBar('Error deleting department: ${e.toString().replaceAll('Exception: ', '')}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(Department department) {
    final adminCount = _adminService
        .getAdminsByDepartment(department.code)
        .length;
    
    final stats = _departmentStats[department.code] ?? {
      'waiting': 0,
      'current': 0,
      'completed': 0,
      'missed': 0,
      'total': 0,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigate to department detail or queue view
        },
        borderRadius: BorderRadius.circular(12),
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
                      department.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      department.name,
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
                      color: department.isActive ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      department.isActive ? 'Active' : 'Inactive',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (department.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  department.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 12),
              
              // Department Statistics
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.queue,
                      'Waiting',
                      stats['waiting']!.toString(),
                      Colors.blue,
                    ),
                    _buildStatItem(
                      Icons.person,
                      'Current',
                      stats['current']!.toString(),
                      Colors.orange,
                    ),
                    _buildStatItem(
                      Icons.check_circle,
                      'Completed',
                      stats['completed']!.toString(),
                      Colors.green,
                    ),
                    _buildStatItem(
                      Icons.cancel,
                      'Missed',
                      stats['missed']!.toString(),
                      Colors.red,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$adminCount admin${adminCount != 1 ? 's' : ''}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.format_list_numbered,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${stats['total']} total entries',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  // Manage Courses button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CourseManagementScreen(
                            adminUser: widget.adminUser,
                            departmentCode: department.code,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.book, size: 16),
                    label: const Text('Courses'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_adminService.canModifyDepartments) ...[
                    IconButton(
                      onPressed: () => _showEditDepartmentDialog(department),
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: 'Edit Department',
                      color: const Color(0xFF263277),
                    ),
                    IconButton(
                      onPressed: () => _toggleDepartmentStatus(department),
                      icon: Icon(
                        department.isActive
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      tooltip: department.isActive ? 'Deactivate' : 'Activate',
                      color: department.isActive ? Colors.orange : Colors.green,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      color: Colors.white,
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteDepartmentDialog(department);
                        } else if (value == 'permanent_delete') {
                          _showPermanentDeleteDialog(department);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete (Deactivate)'),
                            ],
                          ),
                        ),
                        if (_adminService.isMasterAdmin)
                          const PopupMenuItem(
                            value: 'permanent_delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_forever, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Permanently Delete'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2F8),
      appBar: AppBar(
        title: const Text('Department Management'),
        backgroundColor: const Color(0xFF263277),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12), // Reduced from 16
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with stats
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16), // Reduced from 20
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Department Overview',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: const Color(0xFF263277),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              if (widget.adminUser.department == 'ALL')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.admin_panel_settings,
                                        size: 16,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Master Admin',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12), // Reduced from 16
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatCard(
                                'Total',
                                _departments.length.toString(),
                                Icons.school,
                                Colors.blue,
                              ),
                              _buildStatCard(
                                'Active',
                                _departments
                                    .where((d) => d.isActive)
                                    .length
                                    .toString(),
                                Icons.check_circle,
                                Colors.green,
                              ),
                              _buildStatCard(
                                'Inactive',
                                _departments
                                    .where((d) => !d.isActive)
                                    .length
                                    .toString(),
                                Icons.cancel,
                                Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16), // Reduced from 24
                    // Departments list
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All Departments',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: const Color(0xFF263277),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                _loadDepartments();
                              },
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Refresh Statistics',
                              color: const Color(0xFF263277),
                            ),
                            if (_adminService.canModifyDepartments)
                              ElevatedButton.icon(
                                onPressed: _showAddDepartmentDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Department'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF263277),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12), // Reduced from 16

                    Expanded(
                      child: _departments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No departments found',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                bottom: 8,
                              ), // Add bottom padding
                              itemCount: _departments.length,
                              itemBuilder: (context, index) {
                                return _buildDepartmentCard(
                                  _departments[index],
                                );
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
