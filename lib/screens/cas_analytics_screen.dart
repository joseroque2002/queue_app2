import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:async';
import '../services/analytics_service.dart';
import '../services/supabase_service.dart';
import '../services/department_service.dart';
import '../constants/supabase_config.dart';
import '../models/admin_user.dart';
import '../models/queue_entry.dart';

class CASAnalyticsScreen extends StatefulWidget {
  final AdminUser? adminUser;
  const CASAnalyticsScreen({super.key, this.adminUser});

  @override
  State<CASAnalyticsScreen> createState() => _CASAnalyticsScreenState();
}

class _CASAnalyticsScreenState extends State<CASAnalyticsScreen>
    with TickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  final SupabaseService _supabaseService = SupabaseService();
  final DepartmentService _departmentService = DepartmentService();
  
  List<QueueEntry> _casQueueEntries = [];
  bool _isLoading = false;
  Timer? _updateTimer;
  final List<Map<String, dynamic>> _realtimeUpdates = [];
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadCASData();
    _startRealtimeUpdates();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startRealtimeUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadCASData();
      _trackRealtimeUpdate();
    });
  }

  void _trackRealtimeUpdate() {
    final now = DateTime.now();
    final updateData = {
      'timestamp': now,
      'totalEntries': _casQueueEntries.length,
      'waitingCount': _casQueueEntries.where((e) => e.status == 'waiting').length,
      'completedCount': _casQueueEntries.where((e) => e.status == 'completed' || e.status == 'done').length,
    };
    
    setState(() {
      _realtimeUpdates.add(updateData);
      if (_realtimeUpdates.length > 20) {
        _realtimeUpdates.removeAt(0);
      }
    });
  }

  Future<void> _loadCASData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabaseService.client
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, 'CAS');
      
      _casQueueEntries = response.map((json) => QueueEntry.fromJson(json)).toList();
      _casQueueEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('Loaded ${_casQueueEntries.length} CAS queue entries');
    } catch (e) {
      print('Error loading CAS data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            ),
          ),
        ),
        title: const Text(
          'CAS Analytics Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadCASData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderStats(),
                      const SizedBox(height: 24),
                      _buildQueueStatusPieChart(),
                      const SizedBox(height: 24),
                      _buildRecentActivityTimeline(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderStats() {
    final totalEntries = _casQueueEntries.length;
    final waitingCount = _casQueueEntries.where((e) => e.status == 'waiting').length;
    final completedCount = _casQueueEntries.where((e) => e.status == 'completed' || e.status == 'done').length;
    final priorityCount = _casQueueEntries.where((e) => e.isPriority).length;

    return Row(
      children: [
        Expanded(child: _buildStatCard('Total', totalEntries.toString(), Icons.people, const Color(0xFF3B82F6))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Waiting', waitingCount.toString(), Icons.hourglass_empty, const Color(0xFFF59E0B))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Completed', completedCount.toString(), Icons.check_circle, const Color(0xFF10B981))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Priority', priorityCount.toString(), Icons.priority_high, const Color(0xFFEF4444))),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueStatusPieChart() {
    final statusCounts = <String, int>{};
    for (final entry in _casQueueEntries) {
      statusCounts[entry.status] = (statusCounts[entry.status] ?? 0) + 1;
    }

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
                  sections: statusCounts.entries.map((entry) {
                    final color = colors[entry.key] ?? Colors.grey;
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
                      title: '${entry.value}',
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
              return Row(
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
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontFamily: 'SF Pro Display',
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityTimeline() {
    final recentEntries = _casQueueEntries.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity Timeline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 24),
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
                            '${entry.purpose} • ${entry.course ?? 'No course'} • Queue #${entry.queueNumber}',
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return const Color(0xFFF59E0B);
      case 'current':
      case 'serving':
        return const Color(0xFF3B82F6);
      case 'completed':
      case 'done':
        return const Color(0xFF10B981);
      case 'missed':
        return const Color(0xFFEF4444);
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
      case 'done':
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
}