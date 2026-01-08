import '../models/queue_entry.dart';
import 'department_service.dart';

class QueueService {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  // In-memory storage (in a real app, this would be a database)
  final List<QueueEntry> _queueEntries = [];
  int _nextQueueNumber = 1;
  static const int maxQueueNumber = 500;
  final DepartmentService _departmentService = DepartmentService();

  // Get all queue entries
  List<QueueEntry> getAllEntries() {
    return List.from(_queueEntries);
  }

  // Get entries by department
  List<QueueEntry> getEntriesByDepartment(String department) {
    return _queueEntries
        .where((entry) => entry.department == department)
        .toList();
  }

  // Get first 5 entries for display (for LED screen)
  List<QueueEntry> getFirstFiveEntries() {
    final sortedEntries = List<QueueEntry>.from(_queueEntries);
    sortedEntries.sort((a, b) => a.queueNumber.compareTo(b.queueNumber));
    return sortedEntries.take(5).toList();
  }

  // Get first 5 entries by department
  List<QueueEntry> getFirstFiveByDepartment(String department) {
    final departmentEntries = getEntriesByDepartment(department);
    departmentEntries.sort((a, b) => a.queueNumber.compareTo(b.queueNumber));
    return departmentEntries.take(5).toList();
  }

  // Add new queue entry with department validation
  QueueEntry addEntry({
    required String name,
    required String ssuId,
    required String email,
    required String phoneNumber,
    required String department,
    required String purpose,
  }) {
    // Check if we've reached the maximum queue number
    if (_nextQueueNumber > maxQueueNumber) {
      throw Exception('Queue number limit reached. Please reset the queue.');
    }

    // Validate department exists and is active
    final dept = _departmentService.getDepartmentByCode(department);
    if (dept == null || !dept.isActive) {
      throw Exception('Invalid or inactive department: $department');
    }

    final entry = QueueEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      ssuId: ssuId,
      email: email,
      phoneNumber: phoneNumber,
      department: department,
      purpose: purpose,
      timestamp: DateTime.now(),
      queueNumber: _nextQueueNumber++,
    );

    _queueEntries.add(entry);
    return entry;
  }

  // Remove entry from queue (when admin clicks finish)
  bool removeEntry(String id) {
    final index = _queueEntries.indexWhere((entry) => entry.id == id);
    if (index != -1) {
      _queueEntries.removeAt(index);
      return true;
    }
    return false;
  }

  // Get next person in queue for a department
  QueueEntry? getNextPerson(String department) {
    final departmentEntries = getEntriesByDepartment(department);
    if (departmentEntries.isNotEmpty) {
      // Sort by queue number to get the lowest number first
      departmentEntries.sort((a, b) => a.queueNumber.compareTo(b.queueNumber));
      return departmentEntries.first;
    }
    return null;
  }

  // Finish serving a person (remove from queue)
  bool finishServing(String department) {
    final nextPerson = getNextPerson(department);
    if (nextPerson != null) {
      return removeEntry(nextPerson.id);
    }
    return false;
  }

  // Get queue statistics
  Map<String, int> getQueueStatistics() {
    final Map<String, int> stats = {};
    for (final entry in _queueEntries) {
      stats[entry.department] = (stats[entry.department] ?? 0) + 1;
    }
    return stats;
  }

  // Reset queue numbers (admin function)
  void resetQueue() {
    _queueEntries.clear();
    _nextQueueNumber = 1;
  }

  // Get current queue number
  int get currentQueueNumber => _nextQueueNumber;

  // Get total queue count
  int getTotalCount() {
    return _queueEntries.length;
  }

  // Check if queue is full
  bool get isQueueFull => _nextQueueNumber > maxQueueNumber;

  // Get available queue numbers
  int get availableQueueNumbers => maxQueueNumber - _nextQueueNumber + 1;

  // Department-related methods

  // Get department service instance
  DepartmentService get departmentService => _departmentService;

  // Get available departments for queue entry
  List<String> getAvailableDepartments() {
    return _departmentService.getDepartmentCodes();
  }

  // Get department name by code
  String? getDepartmentName(String code) {
    final dept = _departmentService.getDepartmentByCode(code);
    return dept?.name;
  }

  // Get queue statistics by department with department names
  Map<String, dynamic> getDetailedQueueStatistics() {
    final Map<String, dynamic> stats = {};

    for (final dept in _departmentService.getActiveDepartments()) {
      final entries = getEntriesByDepartment(dept.code);
      stats[dept.code] = {
        'name': dept.name,
        'code': dept.code,
        'count': entries.length,
        'waiting': entries.where((e) => e.status == 'waiting').length,
        'current': entries.where((e) => e.status == 'current').length,
        'completed': entries.where((e) => e.status == 'completed').length,
        'missed': entries.where((e) => e.status == 'missed').length,
      };
    }

    return stats;
  }

  // Validate department before operations
  bool validateDepartment(String departmentCode) {
    final dept = _departmentService.getDepartmentByCode(departmentCode);
    return dept != null && dept.isActive;
  }

  // Get queue entries with department information
  List<Map<String, dynamic>> getEntriesWithDepartmentInfo() {
    return _queueEntries.map((entry) {
      final dept = _departmentService.getDepartmentByCode(entry.department);
      return {
        'entry': entry,
        'departmentName': dept?.name ?? 'Unknown Department',
        'departmentCode': entry.department,
        'isValidDepartment': dept != null && dept.isActive,
      };
    }).toList();
  }
}
