import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../services/analytics_service.dart';
import '../services/supabase_service.dart';
import '../services/department_service.dart';
import '../constants/supabase_config.dart';
import '../models/admin_user.dart';
import '../models/queue_entry.dart';

class AnalyticsScreen extends StatefulWidget {
  final AdminUser? adminUser;
  const AnalyticsScreen({super.key, this.adminUser});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final SupabaseService _supabaseService = SupabaseService();
  final DepartmentService _departmentService = DepartmentService();
  List<QueueEntry> _allQueueEntries = [];
  List<QueueEntry> _filteredQueueEntries = [];
  bool _isLoadingStudents = false;
  String? _selectedDepartmentFilter;
  String? _selectedCourseFilter;
  String? _selectedPurposeFilter;
  DateTime? _selectedMonth;
  DateTime? _selectedDay;
  int _refreshKey = 0; // Key to force FutureBuilder rebuild

  @override
  void initState() {
    super.initState();
    _loadAllStudents();
  }

  Future<void> _loadAllStudents() async {
    setState(() {
      _isLoadingStudents = true;
    });
    try {
      // Always fetch from Supabase with current filters
      final String? dept = widget.adminUser?.department;
      final bool isMasterAdmin = dept == 'ALL' || dept == null;
      
      // Build Supabase query with filters
      var query = _supabaseService.client
          .from(SupabaseConfig.queueEntriesTable)
          .select();
      
      // Apply base department filter (for department admins only, not master admin)
      // Department admins can ONLY see their department data
      // Note: If !isMasterAdmin, then dept cannot be null (isMasterAdmin = dept == 'ALL' || dept == null)
      if (!isMasterAdmin) {
        // ignore: unnecessary_null_comparison
        if (dept != null) {
          query = query.eq(SupabaseConfig.departmentColumn, dept);
        }
      }
      
      // Apply additional filters (master admin can filter by any department)
      // Only allow department filter if user is master admin
      if (isMasterAdmin && _selectedDepartmentFilter != null && _selectedDepartmentFilter!.isNotEmpty) {
        query = query.eq(SupabaseConfig.departmentColumn, _selectedDepartmentFilter!);
      }
      
      if (_selectedCourseFilter != null && _selectedCourseFilter!.isNotEmpty) {
        query = query.eq('course', _selectedCourseFilter!);
      }
      
      if (_selectedPurposeFilter != null && _selectedPurposeFilter!.isNotEmpty) {
        query = query.eq(SupabaseConfig.purposeColumn, _selectedPurposeFilter!);
      }
      
      // Apply day filter (takes precedence over month filter)
      if (_selectedDay != null) {
        final startOfDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        query = query
            .gte(SupabaseConfig.timestampColumn, startOfDay.toIso8601String())
            .lt(SupabaseConfig.timestampColumn, endOfDay.toIso8601String());
      } else if (_selectedMonth != null) {
        // Apply month filter only if day filter is not set
        final startOfMonth = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
        final endOfMonth = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 1);
        query = query
            .gte(SupabaseConfig.timestampColumn, startOfMonth.toIso8601String())
            .lt(SupabaseConfig.timestampColumn, endOfMonth.toIso8601String());
      }
      
      // Execute query
      final response = await query;
      _allQueueEntries = response.map((json) => QueueEntry.fromJson(json)).toList();
      
      print('Loaded ${_allQueueEntries.length} queue entries from Supabase');
      if (isMasterAdmin) {
        print('Master admin: Fetched all data from Supabase');
      } else {
        print('Department admin ($dept): Fetched department data from Supabase');
      }
      
      // Sort by department, then by queue number
      _allQueueEntries.sort((a, b) {
        final deptCompare = a.department.compareTo(b.department);
        if (deptCompare != 0) return deptCompare;
        return a.queueNumber.compareTo(b.queueNumber);
      });
      
      // Update filtered entries
      setState(() {
        _filteredQueueEntries = _allQueueEntries;
      });
    } catch (e) {
      print('Error loading students from Supabase: $e');
    } finally {
      setState(() {
        _isLoadingStudents = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? dept = widget.adminUser?.department;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F2F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          dept != null ? '$dept Analytics Dashboard' : 'Analytics Dashboard',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF263277),
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF263277)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF263277)),
            onPressed: () {
              setState(() {
                _refreshKey++;
              });
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Builder(
          builder: (context) {
            final String? dept = widget.adminUser?.department;
            final bool isMasterAdmin = dept == 'ALL' || dept == null;
            
            return FutureBuilder<Map<String, dynamic>>(
              key: ValueKey('analytics_${_refreshKey}_${_selectedDepartmentFilter}_${_selectedCourseFilter}_${_selectedPurposeFilter}_${_selectedMonth?.toString()}_${_selectedDay?.toString()}'),
              future: _analyticsService.getComprehensiveAnalytics(
                department: isMasterAdmin 
                    ? (_selectedDepartmentFilter ?? null) // Master admin can filter by any department or see all
                    : (dept != 'ALL' ? dept : null), // Department admin only sees their department
                course: _selectedCourseFilter,
                purpose: _selectedPurposeFilter,
                month: _selectedDay != null ? null : _selectedMonth, // Don't use month if day is selected
                day: _selectedDay,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: Color(0xFF263277)),
                    ),
                  );
                }
            
                // Handle errors
                if (snapshot.hasError) {
                  print('Analytics error: ${snapshot.error}');
                  print('Stack trace: ${snapshot.stackTrace}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading analytics: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _refreshKey++;
                              });
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
            
                final bool ok =
                    snapshot.hasData && snapshot.data?['success'] == true;
            
                if (!ok) {
                  print('Analytics data not successful. Data: ${snapshot.data}');
                  print('Has data: ${snapshot.hasData}, Success: ${snapshot.data?['success']}');
                }

                final Map<String, dynamic> graphs = ok
                    ? (snapshot.data!['graphs'] as Map<String, dynamic>)
                    : <String, dynamic>{};
                final Map<String, dynamic> summary = ok
                    ? (snapshot.data!['summary'] as Map<String, dynamic>)
                    : <String, dynamic>{};
                
                // Master admin specific charts
                final List<dynamic> deptUsage = ok && isMasterAdmin
                    ? ((graphs['department_usage'] as Map<String, dynamic>?)?['data'] as List?) ?? const []
                    : const [];
                final List<dynamic> topCourses = ok && isMasterAdmin
                    ? ((graphs['top_courses_usage'] as Map<String, dynamic>?)?['data'] as List?) ?? const []
                    : const [];
            
                // Debug logging
                print('Analytics Screen: ok=$ok, isMasterAdmin=$isMasterAdmin, graphs keys: ${graphs.keys.toList()}');
                if (isMasterAdmin) {
                  print('Analytics Screen: deptUsage count: ${deptUsage.length}, topCourses count: ${topCourses.length}');
                  print('Analytics Screen: deptUsage data: $deptUsage');
                  print('Analytics Screen: topCourses data: $topCourses');
                  if (graphs.containsKey('department_usage')) {
                    print('Analytics Screen: department_usage graph exists: ${graphs['department_usage']}');
                  } else {
                    print('Analytics Screen: WARNING - department_usage NOT in graphs!');
                  }
                  if (graphs.containsKey('top_courses_usage')) {
                    print('Analytics Screen: top_courses_usage graph exists: ${graphs['top_courses_usage']}');
                  } else {
                    print('Analytics Screen: WARNING - top_courses_usage NOT in graphs!');
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Analytics Header with Live Indicator
                    _buildAnalyticsHeader(isMasterAdmin),
                    const SizedBox(height: 20),
                    
                    // Real-time Metrics Dashboard
                    _buildRealTimeMetrics(snapshot.data ?? {}),
                    const SizedBox(height: 20),
                    
                    // Queue Status Chart (from department analytics)
                    _buildQueueStatusChart(snapshot.data ?? {}),
                    const SizedBox(height: 20),
                    
                    // Recent Activity Timeline (from department analytics)
                    _buildRecentActivityTimeline(),
                    const SizedBox(height: 20),
                    
                    // Master Admin Charts Only
                    if (isMasterAdmin) ...[
                      // Students List Section (Enhanced)
                      _buildEnhancedStudentsList(),
                    ] else ...[
                      // Students List Section (Enhanced)
                      _buildEnhancedStudentsList(),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEnhancedStudentsList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF263277).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people_rounded,
                  color: Color(0xFF263277),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Queue Participants by Department',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF263277),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Live Data',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoadingStudents)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: Color(0xFF263277)),
              ),
            )
          else
            _buildStudentsList(),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    List<QueueEntry> filteredEntries = _filteredQueueEntries.isNotEmpty 
        ? _filteredQueueEntries 
        : _allQueueEntries;

    if (filteredEntries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No queue entries found',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    // Group entries by department
    final Map<String, List<QueueEntry>> groupedByDept = {};
    for (final entry in filteredEntries) {
      if (!groupedByDept.containsKey(entry.department)) {
        groupedByDept[entry.department] = [];
      }
      groupedByDept[entry.department]!.add(entry);
    }

    // Get department names
    final departments = _departmentService.getAllDepartments();
    final deptMap = {for (var d in departments) d.code: d.name};

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: groupedByDept.length,
        itemBuilder: (context, index) {
          final deptCode = groupedByDept.keys.elementAt(index);
          final entries = groupedByDept[deptCode]!;
          final deptName = deptMap[deptCode] ?? deptCode;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Department header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF263277), Color(0xFF4A90E2)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          deptCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deptName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entries.length} ${entries.length == 1 ? 'student' : 'students'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Students list
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  itemBuilder: (context, idx) {
                    final entry = entries[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: idx < entries.length - 1 ? 1 : 0,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Queue number badge
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: entry.isPriority
                                  ? Colors.green.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: entry.isPriority
                                    ? Colors.green.shade300
                                    : Colors.blue.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.queueNumber.toString().padLeft(3, '0')}',
                                style: TextStyle(
                                  color: entry.isPriority
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Student info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF263277),
                                            ),
                                      ),
                                    ),
                                    if (entry.isPriority)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          entry.priorityType,
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.badge_rounded,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      entry.ssuId,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey.shade700,
                                          ),
                                    ),
                                    if (entry.course != null && entry.course!.isNotEmpty) ...[
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTime(entry.timestamp),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.grey.shade500,
                                              fontSize: 11,
                                            ),
                                      ),
                                    ] else ...[
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTime(entry.timestamp),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.grey.shade500,
                                              fontSize: 11,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(entry.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        entry.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(entry.status),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Colors.orange;
      case 'current':
      case 'serving':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'missed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Icons.hourglass_empty_rounded;
      case 'current':
      case 'serving':
        return Icons.person_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'missed':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Enhanced Analytics UI Components
  Widget _buildAnalyticsHeader(bool isMasterAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF263277), Color(0xFF4A90E2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMasterAdmin ? 'Master Analytics Dashboard' : '${widget.adminUser?.department} Analytics',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time queue insights and performance metrics',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeMetrics(Map<String, dynamic> data) {
    // Calculate metrics from filtered queue entries instead of service data
    final waitingCount = _allQueueEntries.where((e) => e.status == 'waiting').length;
    final completedCount = _allQueueEntries.where((e) => e.status == 'completed' || e.status == 'done').length;
    final totalCount = _allQueueEntries.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: Color(0xFF263277)),
              const SizedBox(width: 12),
              const Text(
                'Real-Time Metrics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263277),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Updated now',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Waiting',
                    '$waitingCount',
                    Icons.hourglass_empty_rounded,
                    Colors.orange,
                    'In queue',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Completed',
                    '$completedCount',
                    Icons.check_circle_rounded,
                    Colors.green,
                    'Finished',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Total',
                    '$totalCount',
                    Icons.people_rounded,
                    Colors.purple,
                    'All entries',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentPerformanceChart(Map<String, dynamic> data) {
    final graphs = data['graphs'] as Map<String, dynamic>? ?? {};
    final deptUsage = graphs['department_usage'] as Map<String, dynamic>? ?? {};
    final chartData = deptUsage['data'] as List? ?? [];

    if (chartData.isEmpty) {
      return _buildEmptyChart('Department Performance', 'No department data available');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Color(0xFF263277)),
              const SizedBox(width: 12),
              const Text(
                'Department Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263277),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartData.isNotEmpty
                    ? chartData
                        .map((e) => (e['count'] as num?)?.toDouble() ?? 0.0)
                        .reduce(math.max)
                        .ceilToDouble()
                    : 10,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFF263277),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < chartData.length) {
                        final dept = chartData[groupIndex];
                        return BarTooltipItem(
                          '${dept['department']}\n${dept['count']} students',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < chartData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${chartData[index]['department']}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 40,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                    left: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                barGroups: chartData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dept = entry.value;
                  final count = (dept['count'] as num?)?.toDouble() ?? 0.0;
                  final color = Color(int.parse(
                    (dept['color'] as String?)?.replaceAll('#', '0xFF') ?? '0xFF263277',
                  ));
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        color: color,
                        width: 24,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [color.withOpacity(0.7), color],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCoursesChart(Map<String, dynamic> data) {
    final graphs = data['graphs'] as Map<String, dynamic>? ?? {};
    final coursesData = graphs['top_courses_usage'] as Map<String, dynamic>? ?? {};
    final chartData = coursesData['data'] as List? ?? [];

    if (chartData.isEmpty) {
      return _buildEmptyChart('Top Courses Usage', 'No course data available');
    }

    final top8Courses = chartData.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.book_rounded, color: Color(0xFF263277)),
              const SizedBox(width: 12),
              const Text(
                'Top Courses Usage',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263277),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: top8Courses.length,
              itemBuilder: (context, index) {
                final course = top8Courses[index];
                final courseName = course['course'] as String? ?? 'Unknown';
                final count = (course['count'] as num?)?.toInt() ?? 0;
                final maxCount = top8Courses.isNotEmpty
                    ? (top8Courses.first['count'] as num?)?.toInt() ?? 1
                    : 1;
                final percentage = maxCount > 0 ? (count / maxCount) : 0.0;
                
                final colors = [
                  const Color(0xFF263277),
                  const Color(0xFF4A90E2),
                  const Color(0xFF96CEB4),
                  const Color(0xFFFF6B35),
                  const Color(0xFFFECA57),
                  const Color(0xFF9B59B6),
                  const Color(0xFF48CAE4),
                  const Color(0xFFFF8A80),
                ];
                final color = colors[index % colors.length];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              courseName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: percentage,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  Widget _buildQueueStatusChart(Map<String, dynamic> data) {
    final statusCounts = <String, int>{};
    for (final entry in _allQueueEntries) {
      statusCounts[entry.status] = (statusCounts[entry.status] ?? 0) + 1;
    }

    final total = statusCounts.values.fold(0, (sum, count) => sum + count);
    final colors = {
      'waiting': const Color(0xFFF59E0B),
      'current': const Color(0xFF3B82F6),
      'completed': const Color(0xFF10B981),
      'done': const Color(0xFF10B981),
      'missed': const Color(0xFFEF4444),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Queue Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              fontFamily: 'SF Pro Display',
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.white,
                    blurRadius: 10,
                    offset: const Offset(-5, -5),
                  ),
                ],
              ),
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (event is FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
                        final sectionIndex = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                        final statusEntry = statusCounts.entries.elementAt(sectionIndex);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${statusEntry.key.toUpperCase()}: ${statusEntry.value} students'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: colors[statusEntry.key] ?? Colors.grey,
                          ),
                        );
                      }
                    },
                  ),
                  sections: statusCounts.entries.map((entry) {
                    final color = colors[entry.key] ?? Colors.grey;
                    final percentage = total > 0 ? (entry.value / total * 100).round() : 0;
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.8),
                          color,
                          color.withOpacity(0.9),
                        ],
                      ),
                      title: '$percentage%',
                      radius: 70,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      badgeWidget: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getStatusIcon(entry.key),
                          color: color,
                          size: 16,
                        ),
                      ),
                      badgePositionPercentageOffset: 1.2,
                    );
                  }).toList(),
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  centerSpaceColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: statusCounts.entries.map((entry) {
              final color = colors[entry.key] ?? Colors.grey;
              final percentage = total > 0 ? (entry.value / total * 100).round() : 0;
              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${entry.key.toUpperCase()}: ${entry.value} students'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: color,
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.key.toUpperCase()} ($percentage%)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityTimeline() {
    final recentEntries = _allQueueEntries.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity Timeline',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          if (recentEntries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...recentEntries.map((entry) {
              final statusColor = _getStatusColor(entry.status);
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Queue #${entry.queueNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            entry.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(entry.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF263277),
            ),
          ),
          const SizedBox(height: 40),
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

