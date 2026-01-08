import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import '../models/admin_user.dart';
import '../services/admin_service.dart';
import 'admin_login_screen.dart';
import '../models/queue_entry.dart';
import '../services/supabase_service.dart';
import '../widgets/countdown_timer.dart';
import '../constants/supabase_config.dart';
import 'analytics_screen.dart';
import 'department_management_screen.dart';
import 'purpose_management_screen.dart';
import 'course_management_screen.dart';
import 'records_view_screen.dart';
import '../services/department_service.dart';
import '../services/purpose_service.dart';
import '../models/department.dart';
import '../services/queue_monitoring_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {

  AdminUser? _currentAdmin;
  List<QueueEntry> _departmentQueue = [];
  QueueEntry? _currentPerson;
  List<QueueEntry> _recentHistory = [];
  bool _isLoading = false;
  String? _lastCompletedId;
  Timer? _refreshTimer;
  bool _showDashboard = true; // Show dashboard by default
  List<Department> _allDepartments = [];
  Map<String, Map<String, int>> _departmentStats = {};
  List<Map<String, dynamic>> _purposeStatsByDeptCourse = []; // Purpose statistics by department and course
  List<QueueEntry> _allQueueEntries = []; // All queue entries for download

  final SupabaseService _supabaseService = SupabaseService();
  final DepartmentService _departmentService = DepartmentService();
  final PurposeService _purposeService = PurposeService();
  final AdminService _adminService = AdminService();
  final QueueMonitoringService _queueMonitoringService = QueueMonitoringService();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAdminData();

    // Start queue monitoring service for automatic top 5 notifications
    _queueMonitoringService.startMonitoring();

    // Auto-refresh every 5 seconds to check for expired countdowns
    // Only refresh data, don't rebuild UI unless data actually changes
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _silentRefresh();
    });
  }


  void _initializeAnimations() {
    // Animations removed - no longer needed
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _queueMonitoringService.stopMonitoring();
    super.dispose();
  }

  // Silent refresh that only updates UI when data actually changes
  Future<void> _silentRefresh() async {
    if (_currentAdmin == null) return;

    try {
      // Check for expired countdowns and clean up
      await _supabaseService.checkExpiredCountdowns();
      await _supabaseService.removeMissedEntriesFromLiveQueue();
      await _supabaseService.cleanupOldEntries();

      // Get fresh data
      final department = _currentAdmin!.department;
      final List<QueueEntry> newQueue;
      // If master admin (department = 'ALL'), get all queue entries
      if (department == 'ALL') {
        newQueue = await _supabaseService.getAllActiveQueueEntries();
      } else {
        newQueue = await _supabaseService.getActiveQueueEntriesByDepartment(
          department,
        );
      }

      // Remove last completed entry if it exists
      if (_lastCompletedId != null) {
        newQueue.removeWhere((e) => e.id == _lastCompletedId);
      }

      // Sort the queue
      int statusRank(String s) {
        switch (s) {
          case 'waiting':
            return 0;
          case 'current':
            return 1;
          default:
            return 2;
        }
      }

      newQueue.sort((a, b) {
        // Priority users first (PWD/Senior)
        if (a.isPriority && !b.isPriority) return -1;
        if (!a.isPriority && b.isPriority) return 1;
        // Within same priority level, sort by queue number
        final numCmp = a.queueNumber.compareTo(b.queueNumber);
        if (numCmp != 0) return numCmp;
        return statusRank(a.status).compareTo(statusRank(b.status));
      });

      final newCurrentPerson = newQueue.isNotEmpty ? newQueue.first : null;

      // Only update UI if data actually changed
      bool hasChanged = false;

      // Check if queue length changed
      if (_departmentQueue.length != newQueue.length) {
        hasChanged = true;
      }

      // Check if current person changed
      if (_currentPerson?.id != newCurrentPerson?.id) {
        hasChanged = true;
        // Don't announce automatically - only announce when admin clicks Start
      }

      // Check if any queue entry status changed
      if (!hasChanged && _departmentQueue.isNotEmpty && newQueue.isNotEmpty) {
        for (
          int i = 0;
          i < _departmentQueue.length && i < newQueue.length;
          i++
        ) {
          if (_departmentQueue[i].status != newQueue[i].status ||
              _departmentQueue[i].id != newQueue[i].id) {
            hasChanged = true;
            break;
          }
        }
      }

      // Only call setState if something actually changed
      if (hasChanged) {
        setState(() {
          _departmentQueue = newQueue;
          _currentPerson = newCurrentPerson;
        });
      }
    } catch (e) {
      print('Error in silent refresh: $e');
    }
  }

  Future<void> _loadAdminData() async {
    try {
      final adminService = AdminService();
      final loggedInAdmin = adminService.currentAdmin;

      if (loggedInAdmin == null) {
        // No admin logged in, redirect to login screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
          );
        }
        return;
      }

      setState(() {
        _currentAdmin = loggedInAdmin;
      });

      // Load all departments for dashboard
      await _loadAllDepartments();
      
      // If master admin, load purposes statistics
      if (loggedInAdmin.department == 'ALL') {
        await _loadPurposeStatistics();
        await _loadAllQueueEntries();
      }
      
      // If not master admin, load department-specific queue data
      if (loggedInAdmin.department != 'ALL') {
        await _loadDepartmentData();
        setState(() {
          _showDashboard = false;
        });
      } else {
        // Master admin sees dashboard by default
        setState(() {
          _showDashboard = true;
        });
      }
    } catch (e) {
      // Fallback to login if anything goes wrong
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
        );
      }
    }
  }

  Future<void> _loadAllDepartments() async {
    try {
      await _departmentService.initializeDefaultDepartments();
      final updatedDepartments = _departmentService.getAllDepartments();
      // Filter out the 'ALL' department - it's only for master admin access, not a real department
      setState(() {
        _allDepartments = updatedDepartments.where((dept) => dept.code != 'ALL').toList();
      });
      await _loadAllDepartmentStatistics();
    } catch (e) {
      print('Error loading all departments: $e');
    }
  }

  Future<void> _loadAllDepartmentStatistics() async {
    try {
      final Map<String, Map<String, int>> stats = {};
      
      for (final dept in _allDepartments) {
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

  Future<void> _loadPurposeStatistics() async {
    try {
      // Get all queue entries
      final allEntries = await _supabaseService.getAllQueueEntries();
      
      // Group by department and course, then count purposes
      final Map<String, Map<String, Map<String, int>>> grouped = {};
      
      for (final entry in allEntries) {
        final dept = entry.department;
        final course = entry.course ?? 'N/A';
        final purpose = entry.purpose;
        
        if (!grouped.containsKey(dept)) {
          grouped[dept] = {};
        }
        if (!grouped[dept]!.containsKey(course)) {
          grouped[dept]![course] = {};
        }
        grouped[dept]![course]![purpose] = 
            (grouped[dept]![course]![purpose] ?? 0) + 1;
      }
      
      // Convert to list format for display
      final List<Map<String, dynamic>> statsList = [];
      for (final deptEntry in grouped.entries) {
        final dept = deptEntry.key;
        final deptName = _departmentService.getDepartmentByCode(dept)?.name ?? dept;
        
        for (final courseEntry in deptEntry.value.entries) {
          final course = courseEntry.key;
          final purposes = courseEntry.value;
          
          // Find the purpose with highest count
          String topPurpose = '';
          int topCount = 0;
          int totalCount = 0;
          
          for (final purposeEntry in purposes.entries) {
            totalCount += purposeEntry.value;
            if (purposeEntry.value > topCount) {
              topCount = purposeEntry.value;
              topPurpose = purposeEntry.key;
            }
          }
          
          statsList.add({
            'department': dept,
            'departmentName': deptName,
            'course': course,
            'topPurpose': topPurpose,
            'topCount': topCount,
            'totalCount': totalCount,
            'allPurposes': purposes,
          });
        }
      }
      
      // Sort by total count descending
      statsList.sort((a, b) => (b['totalCount'] as int).compareTo(a['totalCount'] as int));
      
      setState(() {
        _purposeStatsByDeptCourse = statsList;
      });
    } catch (e) {
      print('Error loading purpose statistics: $e');
    }
  }

  Future<void> _loadAllQueueEntries() async {
    try {
      final entries = await _supabaseService.getAllQueueEntries();
      setState(() {
        _allQueueEntries = entries;
      });
    } catch (e) {
      print('Error loading all queue entries: $e');
    }
  }

  Future<void> _loadDepartmentData() async {
    if (_currentAdmin == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final department = _currentAdmin!.department;

      // Check for expired countdowns and clean up old entries
      await _supabaseService.checkExpiredCountdowns();
      await _supabaseService.removeMissedEntriesFromLiveQueue();
      await _supabaseService.cleanupOldEntries();

      // Get only active queue entries (waiting and serving)
      // If master admin (department = 'ALL'), get all queue entries
      if (department == 'ALL') {
        _departmentQueue = await _supabaseService.getAllActiveQueueEntries();
      } else {
        _departmentQueue = await _supabaseService
            .getActiveQueueEntriesByDepartment(department);
      }

      if (_lastCompletedId != null) {
        _departmentQueue.removeWhere((e) => e.id == _lastCompletedId);
      }

      int statusRank(String s) {
        switch (s) {
          case 'waiting':
            return 0;
          case 'current':
            return 1;
          default:
            return 2;
        }
      }

      _departmentQueue.sort((a, b) {
        // Priority users first (PWD/Senior)
        if (a.isPriority && !b.isPriority) return -1;
        if (!a.isPriority && b.isPriority) return 1;
        // Within same priority level, sort by queue number
        final numCmp = a.queueNumber.compareTo(b.queueNumber);
        if (numCmp != 0) return numCmp;
        return statusRank(a.status).compareTo(statusRank(b.status));
      });

      _currentPerson = _departmentQueue.isNotEmpty
          ? _departmentQueue.first
          : null;
      // Get recent history - for master admin, get from all departments
      if (department == 'ALL') {
        _recentHistory = await _supabaseService.getRecentHistory(limit: 10);
      } else {
        _recentHistory = await _supabaseService.getRecentHistoryForDepartment(
          department,
          limit: 10,
        );
      }

      setState(() {});
    } catch (e) {
      print('Error loading department data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _startCountdown() async {
    if (_currentAdmin == null || _currentPerson == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Announce department start when admin clicks start button

      final success = await _supabaseService.startCountdown(_currentPerson!.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Countdown started for Queue #${_currentPerson!.queueNumber}',
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );


        await _loadDepartmentData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _stopCountdown() async {
    if (_currentAdmin == null || _currentPerson == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _supabaseService.stopCountdown(_currentPerson!.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Countdown stopped for Queue #${_currentPerson!.queueNumber}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        await _loadDepartmentData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _finishServing() async {
    if (_currentAdmin == null || _currentPerson == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final current = _currentPerson!;
      _lastCompletedId = current.id;

      final success = await _supabaseService.completeQueueEntry(current.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Queue #${current.queueNumber} completed successfully',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Reload department data to get updated queue
        await _loadDepartmentData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetQueue() async {
    if (_currentAdmin == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final department = _currentAdmin!.department == 'ALL' 
          ? null 
          : _currentAdmin!.department;
      final success = await _supabaseService.resetQueue(
        department: department,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              department == null
                  ? 'Queue reset successfully for all departments'
                  : 'Queue reset successfully for ${_currentAdmin!.department}',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        await _loadDepartmentData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() {
    try {
      AdminService().logout();
    } catch (_) {}
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeStatisticsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Purpose Statistics by Department & Course',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF263277),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          if (_purposeStatsByDeptCourse.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text(
                  'No purpose statistics available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateColor.resolveWith(
                  (states) => const Color(0xFF263277).withOpacity(0.1),
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Department',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Course',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Top Purpose',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Count',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Total Entries',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Action',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: _purposeStatsByDeptCourse.map((stat) {
                  final purposeName = stat['topPurpose'] as String;
                  return DataRow(
                    cells: [
                      DataCell(Text(stat['departmentName'] as String)),
                      DataCell(Text(stat['course'] as String)),
                      DataCell(Text(purposeName)),
                      DataCell(Text((stat['topCount'] as int).toString())),
                      DataCell(Text((stat['totalCount'] as int).toString())),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deletePurposeFromOverview(purposeName),
                          tooltip: 'Delete Purpose',
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deletePurposeFromOverview(String purposeName) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Purpose'),
          content: Text(
            'Are you sure you want to delete the purpose "$purposeName"?\n\n'
            'This will mark the purpose as inactive. It will no longer appear in the purpose list, '
            'but existing queue entries with this purpose will remain.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      // Get the purpose by name to get its ID
      final purpose = _purposeService.getPurposeByName(purposeName);
      if (purpose == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purpose "$purposeName" not found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Delete the purpose
      setState(() {
        _isLoading = true;
      });

      final success = await _purposeService.deletePurpose(purpose.id);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purpose deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload purpose statistics to reflect the changes
        await _loadPurposeStatistics();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete purpose'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error deleting purpose: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting purpose: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadPurposeData() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Download Purpose Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to download the purpose statistics data?\n',
              ),
              Text(
                'Total entries: ${_allQueueEntries.length}\n',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'The file will contain purpose statistics by department and course.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Text(
                'The file will be saved to your documents folder.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF263277),
                foregroundColor: Colors.white,
              ),
              child: const Text('Download'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      if (_allQueueEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data available to download'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Create Excel file
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['Queue Data'];

      // Add headers
      sheet.appendRow([
        TextCellValue('Name'),
        TextCellValue('Purpose'),
        TextCellValue('SSU ID'),
        TextCellValue('Email'),
        TextCellValue('Phone Number'),
        TextCellValue('Course'),
        TextCellValue('Department'),
        TextCellValue('Queue Number'),
        TextCellValue('Status'),
        TextCellValue('Timestamp'),
      ]);

      // Add data rows
      for (final entry in _allQueueEntries) {
        final deptName = _departmentService.getDepartmentByCode(entry.department)?.name ?? entry.department;
        sheet.appendRow([
          TextCellValue(entry.name),
          TextCellValue(entry.purpose),
          TextCellValue(entry.ssuId),
          TextCellValue(entry.email),
          TextCellValue(entry.phoneNumber),
          TextCellValue(entry.course ?? 'N/A'),
          TextCellValue(deptName),
          TextCellValue(entry.queueNumber.toString()),
          TextCellValue(entry.status),
          TextCellValue(entry.timestamp.toString()),
        ]);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filePath = '${directory.path}/queue_data_$timestamp.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File downloaded to: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentAdmin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentAdmin = _currentAdmin!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1200;

    // Show dashboard view if enabled
    if (_showDashboard && (currentAdmin.department == 'ALL' || _showDashboard)) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F2F8),
        body: isMobile
            ? _buildMobileDashboardLayout(currentAdmin)
            : _buildDesktopDashboardLayout(currentAdmin, isTablet),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F2F8),
      body: isMobile
          ? _buildMobileLayout(currentAdmin)
          : _buildDesktopLayout(currentAdmin, isTablet),
    );
  }

  Widget _buildMobileLayout(AdminUser currentAdmin) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF263277), const Color(0xFF4A90E2)],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 24,
                      color: const Color(0xFF263277),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentAdmin.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          currentAdmin.department == 'ALL'
                              ? 'All Departments'
                              : _departmentService
                                      .getDepartmentByCode(currentAdmin.department)
                                      ?.name ??
                                  currentAdmin.department,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMobileMenuItem(
                      Icons.dashboard_rounded,
                      'Dashboard',
                      true,
                    ),
                    _buildMobileMenuItem(
                      Icons.analytics_rounded,
                      'Analytics',
                      false,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AnalyticsScreen(adminUser: currentAdmin),
                          ),
                        );
                      },
                    ),
                    _buildMobileMenuItem(
                      Icons.table_chart_rounded,
                      'Records',
                      false,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RecordsViewScreen(currentAdmin: currentAdmin),
                          ),
                        );
                      },
                    ),
                    if (_adminService.isMasterAdmin)
                      _buildMobileMenuItem(
                        Icons.school_rounded,
                        'Departments',
                        false,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DepartmentManagementScreen(
                                adminUser: currentAdmin,
                              ),
                            ),
                          );
                        },
                      ),
                    _buildMobileMenuItem(
                      Icons.label_rounded,
                      'Purposes',
                      false,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PurposeManagementScreen(
                              adminUser: currentAdmin,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildMobileMenuItem(
                      Icons.book_rounded,
                      'Courses',
                      false,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CourseManagementScreen(
                              adminUser: currentAdmin,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildMobileQueueStats(),
                const SizedBox(height: 16),
                _buildMobileCurrentPersonCard(),
                const SizedBox(height: 16),
                _buildMobileQueueList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileMenuItem(
    IconData icon,
    String label,
    bool isActive, [
    VoidCallback? onTap,
  ]) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileQueueStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Column(
            children: [
              Text(
                '${_departmentQueue.length}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF263277),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'In Queue',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                '${_recentHistory.length}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Completed',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCurrentPersonCard() {
    if (_currentPerson == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.queue_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No one in queue',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
            ),
            Text(
              'Queue is empty for ${_currentAdmin?.department ?? 'department'}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                'Current Person',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF263277),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF263277), const Color(0xFF4A90E2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Queue #${_currentPerson!.queueNumber.toString().padLeft(3, '0')}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Name', _currentPerson!.name),
          _buildInfoRow('SSU ID', _currentPerson!.ssuId),
          _buildInfoRow('Purpose', _currentPerson!.purpose),
          if (_currentPerson!.isPriority)
            _buildInfoRow('Priority', _currentPerson!.priorityType),

          if (_currentPerson!.status == 'current' &&
              _currentPerson!.countdownStart != null) ...[
            const SizedBox(height: 16),
            CountdownTimer(
              duration: 30,
              startTime: _currentPerson!.countdownStart!,
              onComplete: () async {
                if (_currentPerson != null) {
                  try {
                    await _supabaseService.updateQueueEntryStatus(
                      _currentPerson!.id,
                      SupabaseConfig.statusMissed,
                    );
                    print(
                      'User ${_currentPerson!.name} automatically removed from queue due to timeout',
                    );
                  } catch (e) {
                    print('Failed to remove user from queue: $e');
                  }
                }
                _loadDepartmentData();
              },
              onTick: () {
                // Timer updates its own display, no need to rebuild entire widget
              },
            ),
          ],

          const SizedBox(height: 20),

          if (_currentPerson!.status == 'waiting') ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: !_isLoading ? _startCountdown : null,
                icon: const Icon(Icons.timer_rounded),
                label: const Text('Start Countdown'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else if (_currentPerson!.status == 'current') ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: !_isLoading ? _stopCountdown : null,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: !_isLoading
                          ? () async {
                              await _supabaseService.markAsMissed(
                                _currentPerson!.id,
                              );
                              await _loadDepartmentData();
                            }
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('Skip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _currentPerson != null && !_isLoading
                        ? _finishServing
                        : null,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Finish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF263277),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: !_isLoading ? _resetQueue : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileQueueList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                'Queue List (${_departmentQueue.length} people)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF263277),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_departmentQueue.isNotEmpty && _departmentQueue.length >= 6)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        'Top 6',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Always show 6 slots, even if empty
          ...List<Widget>.generate(6, (index) {
            if (index < _departmentQueue.length) {
              final person = _departmentQueue[index];
              final isCurrent = person.id == _currentPerson?.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF263277).withOpacity(0.1)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrent
                      ? Border.all(color: const Color(0xFF263277), width: 2)
                      : index < 6
                      ? Border.all(color: Colors.orange.shade300, width: 2)
                      : null,
                  boxShadow: index < 6
                      ? [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: person.isPriority
                                ? Colors.green.shade500
                                : isCurrent
                                ? const Color(0xFF263277)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (person.isPriority) ...[
                                Icon(
                                  person.isPwd && person.isSenior && person.isPregnant
                                      ? Icons.accessible_forward_rounded
                                      : person.isPwd && person.isSenior
                                      ? Icons.accessible_forward_rounded
                                      : person.isPwd && person.isPregnant
                                      ? Icons.accessible_rounded
                                      : person.isSenior && person.isPregnant
                                      ? Icons.elderly_rounded
                                      : person.isPwd
                                      ? Icons.accessible_rounded
                                      : person.isSenior
                                      ? Icons.elderly_rounded
                                      : person.isPregnant
                                      ? Icons.child_care_rounded
                                      : Icons.priority_high_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                '#${person.queueNumber.toString().padLeft(3, '0')}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: person.isPriority || isCurrent
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (index < 6)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              child: Text('🔥', style: TextStyle(fontSize: 10)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'SSU ID: ${person.ssuId} | Purpose: ${person.purpose}${person.isPriority ? ' | ${person.priorityType}' : ''}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // Show empty slot
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.queue_rounded,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '#---',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Empty slot',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade400,
                                ),
                          ),
                          Text(
                            'Waiting for next person...',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(AdminUser currentAdmin, bool isTablet) {
    return Row(
      children: [
        Container(
          width: isTablet ? 240 : 280,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF263277), const Color(0xFF4A90E2)],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: isTablet ? 32 : 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        size: isTablet ? 32 : 40,
                        color: const Color(0xFF263277),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentAdmin.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      _departmentService
                              .getDepartmentByCode(currentAdmin.department)
                              ?.name ??
                          currentAdmin.department,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildMenuItem(Icons.dashboard_rounded, 'Dashboard', true, () {}),
              _buildMenuItem(Icons.analytics_rounded, 'Analytics', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AnalyticsScreen(adminUser: currentAdmin),
                  ),
                );
              }),
              _buildMenuItem(Icons.table_chart_rounded, 'Records', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RecordsViewScreen(currentAdmin: currentAdmin),
                  ),
                );
              }),
              if (_adminService.isMasterAdmin)
                _buildMenuItem(Icons.school_rounded, 'Departments', false, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DepartmentManagementScreen(adminUser: currentAdmin),
                    ),
                  );
                }),
              _buildMenuItem(Icons.label_rounded, 'Purposes', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PurposeManagementScreen(adminUser: currentAdmin),
                  ),
                );
              }),
              const Spacer(),
              Container(
                margin: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentAdmin.department == 'ALL'
                      ? 'Master Admin Dashboard - All Departments'
                      : '${_departmentService.getDepartmentByCode(currentAdmin.department)?.name ?? currentAdmin.department} Queue Management',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF263277),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                if (_currentPerson != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
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
                              'Current Person',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: const Color(0xFF263277),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
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
                                'Queue #${_currentPerson!.queueNumber.toString().padLeft(3, '0')}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildInfoRow('Name', _currentPerson!.name),
                        _buildInfoRow('SSU ID', _currentPerson!.ssuId),
                        if (_currentPerson!.isPriority)
                          _buildInfoRow(
                            'Priority',
                            _currentPerson!.priorityType,
                          ),
                        _buildInfoRow('Purpose', _currentPerson!.purpose),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            if (_currentPerson!.status == 'waiting')
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: !_isLoading
                                      ? _startCountdown
                                      : null,
                                  icon: const Icon(Icons.timer_rounded),
                                  label: const Text('Start Countdown'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            if (_currentPerson!.status == 'current') ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: !_isLoading
                                      ? _stopCountdown
                                      : null,
                                  icon: const Icon(Icons.stop_rounded),
                                  label: const Text('Complete'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: !_isLoading
                                      ? () async {
                                          await _supabaseService.markAsMissed(
                                            _currentPerson!.id,
                                          );
                                          await _loadDepartmentData();
                                        }
                                      : null,
                                  icon: const Icon(Icons.skip_next_rounded),
                                  label: const Text('Skip'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _currentPerson != null && !_isLoading
                                    ? _finishServing
                                    : null,
                                icon: const Icon(Icons.check_circle_rounded),
                                label: const Text('Finish'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF263277),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: !_isLoading ? _resetQueue : null,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reset'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.queue_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No one in queue',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                        Text(
                          'Queue is empty for ${currentAdmin.department}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Queue List (${_departmentQueue.length} people)',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: const Color(0xFF263277),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _departmentQueue.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.queue_rounded,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No one in queue',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _departmentQueue.length,
                                  itemBuilder: (context, index) {
                                    final person = _departmentQueue[index];
                                    final isCurrent =
                                        person.id == _currentPerson?.id;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? const Color(
                                                0xFF263277,
                                              ).withOpacity(0.1)
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isCurrent
                                            ? Border.all(
                                                color: const Color(0xFF263277),
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Stack(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isCurrent
                                                      ? const Color(0xFF263277)
                                                      : Colors.grey.shade300,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '#${person.queueNumber.toString().padLeft(3, '0')}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: isCurrent
                                                            ? Colors.white
                                                            : Colors
                                                                  .grey
                                                                  .shade700,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              if (index < 5)
                                                Positioned(
                                                  top: -5,
                                                  right: -5,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '🔥',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  person.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                Text(
                                                  'SSU ID: ${person.ssuId} | Purpose: ${person.purpose}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isCurrent)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'CURRENT',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dashboard Layout Methods
  Widget _buildMobileDashboardLayout(AdminUser currentAdmin) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF263277), const Color(0xFF4A90E2)],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 24,
                      color: const Color(0xFF263277),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentAdmin.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          'All Departments Dashboard',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildDashboardContent(currentAdmin, true),
        ),
      ],
    );
  }

  Widget _buildDesktopDashboardLayout(AdminUser currentAdmin, bool isTablet) {
    return Row(
      children: [
        Container(
          width: isTablet ? 240 : 280,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF263277), const Color(0xFF4A90E2)],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: isTablet ? 32 : 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        size: isTablet ? 32 : 40,
                        color: const Color(0xFF263277),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentAdmin.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'All Departments',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildMenuItem(Icons.dashboard_rounded, 'Dashboard', true, () {
                setState(() {
                  _showDashboard = true;
                });
              }),
              if (_adminService.isMasterAdmin)
                _buildMenuItem(Icons.school_rounded, 'Departments', false, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DepartmentManagementScreen(adminUser: currentAdmin),
                    ),
                  );
                }),
              _buildMenuItem(Icons.analytics_rounded, 'Analytics', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AnalyticsScreen(adminUser: currentAdmin),
                  ),
                );
              }),
              _buildMenuItem(Icons.table_chart_rounded, 'Records', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RecordsViewScreen(currentAdmin: currentAdmin),
                  ),
                );
              }),
              _buildMenuItem(Icons.label_rounded, 'Purposes', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PurposeManagementScreen(adminUser: currentAdmin),
                  ),
                );
              }),
              const Spacer(),
              Container(
                margin: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 16 : 24),
            child: _buildDashboardContent(currentAdmin, false),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardContent(AdminUser currentAdmin, bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Add Department Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Departments',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF263277),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_adminService.isMasterAdmin)
                ElevatedButton.icon(
                  onPressed: _showAddDepartmentDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Department'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF263277),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Statistics Overview
          _buildStatisticsOverview(),
          
          const SizedBox(height: 24),
          
          // Departments Grid
          _buildDepartmentsGrid(isMobile),
        ],
      ),
    );
  }

  Widget _buildStatisticsOverview() {
    final totalDepts = _allDepartments.length;
    final activeDepts = _allDepartments.where((d) => d.isActive).length;
    final totalWaiting = _departmentStats.values
        .fold<int>(0, (sum, stats) => sum + (stats['waiting'] ?? 0));
    final totalCurrent = _departmentStats.values
        .fold<int>(0, (sum, stats) => sum + (stats['current'] ?? 0));

    return Container(
      padding: const EdgeInsets.all(20),
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
          _buildStatCard('Total Departments', totalDepts.toString(),
              Icons.school, Colors.blue),
          _buildStatCard('Active', activeDepts.toString(),
              Icons.check_circle, Colors.green),
          _buildStatCard('Waiting', totalWaiting.toString(),
              Icons.queue, Colors.orange),
          _buildStatCard('Serving', totalCurrent.toString(),
              Icons.person, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentsGrid(bool isMobile) {
    if (_allDepartments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No departments found',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isMobile ? 1.2 : 1.5,
      ),
      itemCount: _allDepartments.length,
      itemBuilder: (context, index) {
        return _buildDepartmentCard(_allDepartments[index]);
      },
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _adminService.isMasterAdmin ? () {
          // Navigate to department management screen for this department (master admin only)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DepartmentManagementScreen(
                adminUser: _currentAdmin!,
              ),
            ),
          );
        } : null,
        borderRadius: BorderRadius.circular(16),
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
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
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
              const SizedBox(height: 12),
              Text(
                department.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMiniStat('Waiting', stats['waiting']!.toString(), Colors.blue),
                  const SizedBox(width: 8),
                  _buildMiniStat('Current', stats['current']!.toString(), Colors.orange),
                  const SizedBox(width: 8),
                  _buildMiniStat('Total', stats['total']!.toString(), Colors.grey),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.admin_panel_settings, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '$adminCount admin${adminCount != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (_adminService.isMasterAdmin) ...[
                    IconButton(
                      onPressed: () => _showEditDepartmentDialog(department),
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Edit Department',
                      color: const Color(0xFF263277),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      color: Colors.white,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
                  ] else
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
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
            onPressed: () {
              if (codeController.text.trim().isEmpty ||
                  nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code and name are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                _departmentService.addDepartment(
                  code: codeController.text.trim().toUpperCase(),
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                Navigator.pop(context);
                _loadAllDepartments();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Department added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDepartmentDialog(Department department) {
    if (!_adminService.isLoggedIn || !_adminService.isMasterAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only master admin can edit departments'),
          backgroundColor: Colors.red,
        ),
      );
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
                enabled: _adminService.isMasterAdmin,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code and name are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                _departmentService.updateDepartment(
                  department.id,
                  code: codeController.text.trim().toUpperCase(),
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                Navigator.pop(context);
                await _loadAllDepartments();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Department updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
                    backgroundColor: Colors.red,
                  ),
                );
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

  void _showDeleteDepartmentDialog(Department department) {
    if (!_adminService.isLoggedIn || !_adminService.isMasterAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only master admin can delete departments'),
          backgroundColor: Colors.red,
        ),
      );
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
                _departmentService.deleteDepartment(department.id);
                Navigator.pop(context);
                await _loadAllDepartments();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Department deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only master admin can permanently delete departments'),
          backgroundColor: Colors.red,
        ),
      );
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
                _departmentService.removeDepartment(department.id);
                Navigator.pop(context);
                await _loadAllDepartments();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Department permanently deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
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
}
