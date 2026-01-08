import '../models/admin_user.dart';
import 'department_service.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  // In-memory storage for admin users
  final List<AdminUser> _adminUsers = [];
  AdminUser? _currentAdmin;
  
  // Lazy getter to avoid circular dependency with DepartmentService
  DepartmentService get _departmentService => DepartmentService();

  // Initialize with default admin users for each department
  void initializeDefaultAdmins() {
    if (_adminUsers.isEmpty) {
      // Initialize departments first
      _departmentService.initializeDefaultDepartments();

      // Add master admin account (can access all departments)
      final masterAdmin = AdminUser(
        id: 'admin_master',
        username: 'admin',
        password: 'admin123',
        department: 'ALL', // Special department code for master admin
        name: 'Master Administrator',
        createdAt: DateTime.now(),
      );
      _adminUsers.add(masterAdmin);

      // Get active departments from the department service
      final departments = _departmentService.getActiveDepartments();

      for (int i = 0; i < departments.length; i++) {
        final dept = departments[i];
        final admin = AdminUser(
          id: 'admin_${i + 1}',
          username: 'admin_${dept.code.toLowerCase()}',
          password: 'admin123', // Default password
          department: dept.code,
          name: '${dept.code} Admin',
          createdAt: DateTime.now(),
        );
        _adminUsers.add(admin);
      }
    }
  }

  // Get current logged in admin
  AdminUser? get currentAdmin => _currentAdmin;

  // Login admin
  bool login(String username, String password) {
    final admin = _adminUsers.firstWhere(
      (admin) => admin.username == username && admin.password == password,
      orElse: () => throw Exception('Invalid credentials'),
    );

    _currentAdmin = admin;
    return true;
  }

  // Logout admin
  void logout() {
    _currentAdmin = null;
  }

  // Register new admin
  AdminUser registerAdmin({
    required String username,
    required String password,
    required String department,
    required String name,
  }) {
    // Check if username already exists
    if (_adminUsers.any((admin) => admin.username == username)) {
      throw Exception('Username already exists');
    }

    final admin = AdminUser(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      password: password,
      department: department,
      name: name,
      createdAt: DateTime.now(),
    );

    _adminUsers.add(admin);
    return admin;
  }

  // Get all admin users
  List<AdminUser> getAllAdmins() {
    return List.from(_adminUsers);
  }

  // Get admin by department
  AdminUser? getAdminByDepartment(String department) {
    try {
      return _adminUsers.firstWhere((admin) => admin.department == department);
    } catch (e) {
      return null;
    }
  }

  // Check if admin is logged in
  bool get isLoggedIn => _currentAdmin != null;

  // Get current admin's department
  String? get currentAdminDepartment => _currentAdmin?.department;

  // Department management methods (only for super admins or specific permissions)

  // Get department service instance
  DepartmentService get departmentService => _departmentService;

  // Check if current admin can manage departments
  bool get canManageDepartments {
    // For now, all admins can view departments, but only specific ones can modify
    // This can be extended with role-based permissions
    return _currentAdmin != null;
  }

  // Check if current admin can modify departments
  bool get canModifyDepartments {
    // All logged-in admins can modify departments
    // Master admin (department = 'ALL') can modify all departments
    // Department admins can modify their own department and view others
    return _currentAdmin != null;
  }

  // Check if current admin is master admin
  bool get isMasterAdmin {
    return _currentAdmin != null && _currentAdmin!.department == 'ALL';
  }

  // Validate department exists before creating admin
  bool validateDepartment(String departmentCode) {
    final dept = _departmentService.getDepartmentByCode(departmentCode);
    return dept != null && dept.isActive;
  }

  // Get available departments for admin creation
  List<String> getAvailableDepartments() {
    return _departmentService.getDepartmentCodes();
  }

  // Get department name by code
  String? getDepartmentName(String code) {
    final dept = _departmentService.getDepartmentByCode(code);
    return dept?.name;
  }

  // Register new admin with department validation
  AdminUser registerAdminWithValidation({
    required String username,
    required String password,
    required String departmentCode,
    required String name,
  }) {
    // Validate department exists and is active
    if (!validateDepartment(departmentCode)) {
      throw Exception('Invalid or inactive department: $departmentCode');
    }

    // Check if username already exists
    if (_adminUsers.any((admin) => admin.username == username)) {
      throw Exception('Username already exists');
    }

    final admin = AdminUser(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      password: password,
      department: departmentCode,
      name: name,
      createdAt: DateTime.now(),
    );

    _adminUsers.add(admin);
    return admin;
  }

  // Get admins by department
  List<AdminUser> getAdminsByDepartment(String departmentCode) {
    return _adminUsers
        .where((admin) => admin.department == departmentCode)
        .toList();
  }

  // Get admin statistics by department
  Map<String, dynamic> getAdminStatistics() {
    final stats = <String, dynamic>{
      'total_admins': _adminUsers.length,
      'by_department': <String, int>{},
    };

    for (final admin in _adminUsers) {
      final dept = admin.department;
      stats['by_department'][dept] = (stats['by_department'][dept] ?? 0) + 1;
    }

    return stats;
  }
}
