import '../models/purpose.dart';
import 'admin_service.dart';
import 'supabase_service.dart';

class PurposeService {
  static final PurposeService _instance = PurposeService._internal();
  factory PurposeService() => _instance;
  PurposeService._internal();

  final AdminService _adminService = AdminService();
  final SupabaseService _supabaseService = SupabaseService();

  // In-memory cache for purposes (synced with database)
  List<Purpose> _purposes = [];
  bool _isLoaded = false;

  // Initialize with default purposes (loads from database)
  Future<void> initializeDefaultPurposes() async {
    if (!_isLoaded) {
      await loadPurposesFromDatabase();
      _isLoaded = true;
    }
  }

  // Load purposes from Supabase database
  Future<void> loadPurposesFromDatabase() async {
    try {
      _purposes = await _supabaseService.getAllPurposes();
      print('Loaded ${_purposes.length} purposes from database');
    } catch (e) {
      print('Error loading purposes from database: $e');
      // Fallback to empty list if database fails
      _purposes = [];
    }
  }

  // Get all purposes (read-only, available to all users)
  List<Purpose> getAllPurposes() {
    return List.from(_purposes);
  }

  // Get active purposes only (read-only, available to all users)
  // Regular users can only see active purposes for selection
  List<Purpose> getActivePurposes() {
    return _purposes.where((purpose) => purpose.isActive).toList();
  }

  // Get purpose by name
  Purpose? getPurposeByName(String name) {
    try {
      return _purposes.firstWhere((purpose) => purpose.name == name);
    } catch (e) {
      return null;
    }
  }

  // Get purpose by id
  Purpose? getPurposeById(String id) {
    try {
      return _purposes.firstWhere((purpose) => purpose.id == id);
    } catch (e) {
      return null;
    }
  }

  // Add new purpose (admin only)
  Future<Purpose> addPurpose({
    required String name,
    required String description,
  }) async {
    // Check if admin is logged in
    if (!_adminService.isLoggedIn) {
      throw Exception('Only administrators can add purposes');
    }

    // Check if name already exists in cache
    if (_purposes.any((purpose) => purpose.name.toUpperCase() == name.toUpperCase())) {
      throw Exception('Purpose name already exists');
    }

    try {
      // Add to database
      final purpose = await _supabaseService.addPurpose(
        name: name,
        description: description,
      );

      if (purpose != null) {
        // Update cache
        _purposes.add(purpose);
        return purpose;
      } else {
        throw Exception('Failed to add purpose to database');
      }
    } catch (e) {
      print('Error adding purpose: $e');
      rethrow;
    }
  }

  // Update purpose (admin only)
  Future<bool> updatePurpose(
    String id, {
    String? name,
    String? description,
    bool? isActive,
  }) async {
    // Check if admin is logged in
    if (!_adminService.isLoggedIn) {
      throw Exception('Only administrators can update purposes');
    }

    final index = _purposes.indexWhere((purpose) => purpose.id == id);
    if (index == -1) return false;

    // Check if new name conflicts with existing purposes
    if (name != null && name.toUpperCase() != _purposes[index].name.toUpperCase()) {
      if (_purposes.any((purpose) => 
          purpose.name.toUpperCase() == name.toUpperCase() && purpose.id != id)) {
        throw Exception('Purpose name already exists');
      }
    }

    try {
      // Update in database
      final success = await _supabaseService.updatePurpose(
        id: id,
        name: name,
        description: description,
        isActive: isActive,
      );

      if (success) {
        // Reload from database to get updated timestamp
        await loadPurposesFromDatabase();
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating purpose: $e');
      rethrow;
    }
  }

  // Delete purpose (soft delete by setting isActive to false) - admin only
  Future<bool> deletePurpose(String id) async {
    // Check if admin is logged in
    if (!_adminService.isLoggedIn) {
      throw Exception('Only administrators can delete purposes');
    }
    try {
      final success = await _supabaseService.deletePurpose(id);
      if (success) {
        // Reload from database
        await loadPurposesFromDatabase();
      }
      return success;
    } catch (e) {
      print('Error deleting purpose: $e');
      rethrow;
    }
  }

  // Permanently remove purpose (use with caution) - admin only
  Future<bool> removePurpose(String id) async {
    // Check if admin is logged in
    if (!_adminService.isLoggedIn) {
      throw Exception('Only administrators can remove purposes');
    }

    try {
      final success = await _supabaseService.removePurpose(id);
      if (success) {
        // Reload from database
        await loadPurposesFromDatabase();
      }
      return success;
    } catch (e) {
      print('Error permanently removing purpose: $e');
      rethrow;
    }
  }

  // Get purpose names for dropdown/selection (read-only, available to all users)
  // Only active purposes are returned for selection
  List<String> getPurposeNames() {
    return getActivePurposes().map((purpose) => purpose.name).toList();
  }

  // Search purposes by name or description
  List<Purpose> searchPurposes(String query) {
    final lowerQuery = query.toLowerCase();
    return _purposes.where((purpose) {
      return purpose.isActive &&
          (purpose.name.toLowerCase().contains(lowerQuery) ||
              purpose.description.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Get statistics
  Map<String, int> getPurposeStatistics() {
    return {
      'total': _purposes.length,
      'active': getActivePurposes().length,
      'inactive': _purposes.where((purpose) => !purpose.isActive).length,
    };
  }
}

