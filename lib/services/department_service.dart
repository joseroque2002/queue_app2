import '../models/department.dart';
import 'supabase_service.dart';
import 'admin_service.dart';

class DepartmentService {
  static final DepartmentService _instance = DepartmentService._internal();
  factory DepartmentService() => _instance;
  DepartmentService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  
  // Lazy getter to avoid circular dependency with AdminService
  AdminService get _adminService => AdminService();
  
  // In-memory cache for departments (synced with database)
  List<Department> _departments = [];
  bool _isLoaded = false;

  // Initialize with default departments (loads from database)
  Future<void> initializeDefaultDepartments() async {
    if (!_isLoaded) {
      await loadDepartmentsFromDatabase();
      _isLoaded = true;
    }
  }

  // Load departments from Supabase database
  Future<void> loadDepartmentsFromDatabase() async {
    try {
      _departments = await _supabaseService.getAllDepartments();
      print('Loaded ${_departments.length} departments from database');
    } catch (e) {
      print('Error loading departments from database: $e');
      // Fallback to empty list if database fails
      _departments = [];
    }
  }

  // Get all departments
  List<Department> getAllDepartments() {
    return List.from(_departments);
  }

  // Get active departments only
  List<Department> getActiveDepartments() {
    return _departments.where((dept) => dept.isActive).toList();
  }

  // Get department by code
  Department? getDepartmentByCode(String code) {
    try {
      return _departments.firstWhere((dept) => dept.code == code);
    } catch (e) {
      return null;
    }
  }

  // Get department by id
  Department? getDepartmentById(String id) {
    try {
      return _departments.firstWhere((dept) => dept.id == id);
    } catch (e) {
      return null;
    }
  }

  // Add new department (master admin only)
  Future<Department> addDepartment({
    required String code,
    required String name,
    required String description,
  }) async {
    // Only master admin can add departments
    if (!_adminService.isMasterAdmin) {
      throw Exception('Only master administrator can add departments');
    }
    
    // Check if code already exists in cache
    if (_departments.any((dept) => dept.code.toUpperCase() == code.toUpperCase())) {
      throw Exception('Department code already exists');
    }

    try {
      // Add to database
      final department = await _supabaseService.addDepartment(
        code: code,
        name: name,
        description: description,
      );

      if (department != null) {
        // Update cache
        _departments.add(department);
        return department;
      } else {
        throw Exception('Failed to add department to database');
      }
    } catch (e) {
      print('Error adding department: $e');
      rethrow;
    }
  }

  // Update department
  Future<bool> updateDepartment(
    String id, {
    String? code,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    final index = _departments.indexWhere((dept) => dept.id == id);
    if (index == -1) return false;

    // Check if new code conflicts with existing departments
    if (code != null && code.toUpperCase() != _departments[index].code.toUpperCase()) {
      if (_departments.any((dept) => dept.code.toUpperCase() == code.toUpperCase() && dept.id != id)) {
        throw Exception('Department code already exists');
      }
    }

    try {
      // Update in database
      final success = await _supabaseService.updateDepartment(
        id: id,
        code: code,
        name: name,
        description: description,
        isActive: isActive,
      );

      if (success) {
        // Reload from database to get updated timestamp
        await loadDepartmentsFromDatabase();
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating department: $e');
      rethrow;
    }
  }

  // Delete department (soft delete by setting isActive to false)
  Future<bool> deleteDepartment(String id) async {
    try {
      final success = await _supabaseService.deleteDepartment(id);
      if (success) {
        // Reload from database
        await loadDepartmentsFromDatabase();
      }
      return success;
    } catch (e) {
      print('Error deleting department: $e');
      rethrow;
    }
  }

  // Permanently remove department (use with caution)
  Future<bool> removeDepartment(String id) async {
    try {
      final success = await _supabaseService.removeDepartment(id);
      if (success) {
        // Reload from database
        await loadDepartmentsFromDatabase();
      }
      return success;
    } catch (e) {
      print('Error permanently removing department: $e');
      rethrow;
    }
  }

  // Get department codes for dropdown/selection
  List<String> getDepartmentCodes() {
    return getActiveDepartments().map((dept) => dept.code).toList();
  }

  // Get department names for display
  List<String> getDepartmentNames() {
    return getActiveDepartments().map((dept) => dept.name).toList();
  }

  // Get department code-name pairs for display
  Map<String, String> getDepartmentCodeNameMap() {
    final Map<String, String> map = {};
    for (final dept in getActiveDepartments()) {
      map[dept.code] = dept.name;
    }
    return map;
  }

  // Search departments by name or code
  List<Department> searchDepartments(String query) {
    final lowerQuery = query.toLowerCase();
    return _departments.where((dept) {
      return dept.isActive &&
          (dept.name.toLowerCase().contains(lowerQuery) ||
              dept.code.toLowerCase().contains(lowerQuery) ||
              dept.description.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Get statistics
  Map<String, int> getDepartmentStatistics() {
    return {
      'total': _departments.length,
      'active': getActiveDepartments().length,
      'inactive': _departments.where((dept) => !dept.isActive).length,
    };
  }
}
