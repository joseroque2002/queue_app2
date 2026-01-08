import '../models/course.dart';
import 'department_service.dart';
import 'admin_service.dart';
import 'supabase_service.dart';

class CourseService {
  static final CourseService _instance = CourseService._internal();
  factory CourseService() => _instance;
  CourseService._internal();

  final AdminService _adminService = AdminService();
  final DepartmentService _departmentService = DepartmentService();
  final SupabaseService _supabaseService = SupabaseService();

  // In-memory cache for courses (synced with database)
  List<Course> _courses = [];
  bool _isLoaded = false;

  // Initialize with courses from database
  Future<void> initializeDefaultCourses() async {
    if (!_isLoaded) {
      await loadCoursesFromDatabase();
      _isLoaded = true;
    }
  }

  // Load courses from Supabase database
  Future<void> loadCoursesFromDatabase() async {
    try {
      _courses = await _supabaseService.getAllCourses();
      print('Loaded ${_courses.length} courses from database');
    } catch (e) {
      print('Error loading courses from database: $e');
      // Fallback to empty list if database fails
      _courses = [];
    }
  }

  // Get all courses
  List<Course> getAllCourses() {
    return List.from(_courses);
  }

  // Get active courses only
  List<Course> getActiveCourses() {
    return _courses.where((course) => course.isActive).toList();
  }

  // Get courses by department
  List<Course> getCoursesByDepartment(String departmentCode) {
    return _courses.where((course) =>
        course.departmentCode == departmentCode && course.isActive).toList();
  }

  // Get course by code
  Course? getCourseByCode(String code) {
    try {
      return _courses.firstWhere((course) => course.code == code);
    } catch (e) {
      return null;
    }
  }

  // Get course by id
  Course? getCourseById(String id) {
    try {
      return _courses.firstWhere((course) => course.id == id);
    } catch (e) {
      return null;
    }
  }

  // Add new course (admin only)
  Future<Course> addCourse({
    required String code,
    required String name,
    required String departmentCode,
    required String description,
  }) async {
    // Check if admin is logged in
    if (!_adminService.isLoggedIn) {
      throw Exception('Only administrators can add courses');
    }
    
    // Master admin can add courses to any department
    // Department admins can add courses to their own department
    if (!_adminService.isMasterAdmin && _adminService.currentAdmin?.department != departmentCode) {
      throw Exception('You can only add courses to your own department');
    }

    // Validate department exists
    final dept = _departmentService.getDepartmentByCode(departmentCode);
    if (dept == null || !dept.isActive) {
      throw Exception('Invalid or inactive department: $departmentCode');
    }

    // Check if code already exists in the same department (in cache)
    if (_courses.any((course) =>
        course.code.toUpperCase() == code.toUpperCase() &&
        course.departmentCode == departmentCode)) {
      throw Exception('Course code already exists in this department');
    }

    try {
      // Add to database
      final course = await _supabaseService.addCourse(
        code: code,
        name: name,
        departmentCode: departmentCode,
        description: description,
      );

      if (course != null) {
        // Update cache
        _courses.add(course);
        return course;
      } else {
        throw Exception('Failed to add course to database');
      }
    } catch (e) {
      print('Error adding course: $e');
      rethrow;
    }
  }

  // Update course (admin only)
  Future<bool> updateCourse(
    String id, {
    String? code,
    String? name,
    String? departmentCode,
    String? description,
    bool? isActive,
  }) async {
    // Check if admin is logged in
    if (!_adminService.isLoggedIn) {
      throw Exception('Only administrators can update courses');
    }

    final index = _courses.indexWhere((course) => course.id == id);
    if (index == -1) return false;

    // Validate department if changed
    if (departmentCode != null && departmentCode != _courses[index].departmentCode) {
      final dept = _departmentService.getDepartmentByCode(departmentCode);
      if (dept == null || !dept.isActive) {
        throw Exception('Invalid or inactive department: $departmentCode');
      }
    }

    // Check if new code conflicts with existing courses
    if (code != null && code.toUpperCase() != _courses[index].code.toUpperCase()) {
      final deptCode = departmentCode ?? _courses[index].departmentCode;
      if (_courses.any((course) =>
          course.code.toUpperCase() == code.toUpperCase() &&
          course.departmentCode == deptCode &&
          course.id != id)) {
        throw Exception('Course code already exists in this department');
      }
    }

    try {
      // Update in database
      final success = await _supabaseService.updateCourse(
        id: id,
        code: code,
        name: name,
        departmentCode: departmentCode,
        description: description,
        isActive: isActive,
      );

      if (success) {
        // Reload from database to get updated timestamp
        await loadCoursesFromDatabase();
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating course: $e');
      rethrow;
    }
  }

  // Delete course (soft delete by setting isActive to false) - admin only
  Future<bool> deleteCourse(String id) async {
    // Check if admin is logged in
    if (!_adminService.isLoggedIn) {
      throw Exception('Only administrators can delete courses');
    }
    try {
      final success = await _supabaseService.deleteCourse(id);
      if (success) {
        // Reload from database
        await loadCoursesFromDatabase();
      }
      return success;
    } catch (e) {
      print('Error deleting course: $e');
      rethrow;
    }
  }

  // Get course codes for dropdown/selection by department
  List<String> getCourseCodesByDepartment(String departmentCode) {
    return getCoursesByDepartment(departmentCode)
        .map((course) => course.code)
        .toList();
  }

  // Get course code-name pairs for display by department
  Map<String, String> getCourseCodeNameMapByDepartment(String departmentCode) {
    final Map<String, String> map = {};
    for (final course in getCoursesByDepartment(departmentCode)) {
      map[course.code] = course.name;
    }
    return map;
  }

  // Search courses by name or code
  List<Course> searchCourses(String query, {String? departmentCode}) {
    final lowerQuery = query.toLowerCase();
    return _courses.where((course) {
      final matchesQuery = course.isActive &&
          (course.name.toLowerCase().contains(lowerQuery) ||
              course.code.toLowerCase().contains(lowerQuery) ||
              course.description.toLowerCase().contains(lowerQuery));
      
      if (departmentCode != null) {
        return matchesQuery && course.departmentCode == departmentCode;
      }
      return matchesQuery;
    }).toList();
  }

  // Get statistics
  Map<String, int> getCourseStatistics({String? departmentCode}) {
    final courses = departmentCode != null
        ? getCoursesByDepartment(departmentCode)
        : getAllCourses();
    
    return {
      'total': courses.length,
      'active': courses.where((c) => c.isActive).length,
      'inactive': courses.where((c) => !c.isActive).length,
    };
  }
}

