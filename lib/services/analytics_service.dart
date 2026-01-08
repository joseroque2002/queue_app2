import '../models/queue_entry.dart';
import 'supabase_service.dart';
import '../constants/supabase_config.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // Status counts directly from DB (per department)
  Future<Map<String, int>> getStatusCountsDb(String? department) async {
    try {
      var query = _supabaseService.client
          .from(SupabaseConfig.queueEntriesTable)
          .select();
      
      if (department != null && department != 'ALL') {
        query = query.eq(SupabaseConfig.departmentColumn, department);
      }

      final rows = await query;

      int waiting = 0, current = 0, done = 0;
      for (final r in rows) {
        final s = (r[SupabaseConfig.statusColumn] as String?) ?? 'waiting';
        if (s == 'waiting') waiting++;
        if (s == 'current') current++;
        if (s == 'done') done++;
      }
      return {'waiting': waiting, 'current': current, 'done': done};
    } catch (e) {
      print('Error getting status counts: $e');
      return {'waiting': 0, 'current': 0, 'done': 0};
    }
  }

  // Purpose breakdown list: [{purpose, count}]
  Future<List<Map<String, dynamic>>> getPurposeBreakdownDb(
    String? department,
  ) async {
    try {
      var query = _supabaseService.client
          .from(SupabaseConfig.queueEntriesTable)
          .select();
      
      if (department != null && department != 'ALL') {
        query = query.eq(SupabaseConfig.departmentColumn, department);
      }

      final rows = await query;

      final Map<String, int> counts = {};
      for (final r in rows) {
        final p = (r[SupabaseConfig.purposeColumn] as String?) ?? '';
        if (p.isEmpty) continue;
        counts[p] = (counts[p] ?? 0) + 1;
      }
      final list = counts.entries
          .map((e) => {'purpose': e.key, 'count': e.value})
          .toList();
      list.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      return list;
    } catch (e) {
      print('Error getting purpose breakdown: $e');
      return [];
    }
  }

  // Top purpose helper (kept for compatibility) - alias to DB version
  Future<Map<String, dynamic>> getTopPurposeFromDb({String? department}) async {
    try {
      if (department == null) {
        final rows = await _supabaseService.client
            .from(SupabaseConfig.queueEntriesTable)
            .select();
        final Map<String, int> counts = {};
        for (final r in rows) {
          final p = (r[SupabaseConfig.purposeColumn] as String?) ?? '';
          if (p.isEmpty) continue;
          counts[p] = (counts[p] ?? 0) + 1;
        }
        if (counts.isEmpty) return {'purpose': '—', 'count': 0};
        final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
        return {'purpose': top.key, 'count': top.value};
      }
      final list = await getPurposeBreakdownDb(department);
      if (list.isEmpty) return {'purpose': '—', 'count': 0};
      return list.first;
    } catch (e) {
      return {'purpose': '—', 'count': 0};
    }
  }

  // Hourly counts today (0-23)
  Future<List<Map<String, dynamic>>> getHourlyCountsTodayDb(
    String department,
  ) async {
    try {
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final rows = await _supabaseService.client
          .from(SupabaseConfig.queueEntriesTable)
          .select(SupabaseConfig.timestampColumn)
          .eq(SupabaseConfig.departmentColumn, department)
          .gte(SupabaseConfig.timestampColumn, start.toIso8601String())
          .lt(SupabaseConfig.timestampColumn, end.toIso8601String());

      final counts = List<int>.filled(24, 0);
      for (final r in rows) {
        final ts = DateTime.parse(r[SupabaseConfig.timestampColumn]).toUtc();
        counts[ts.hour]++;
      }
      return List.generate(24, (h) => {'hour': h, 'count': counts[h]});
    } catch (e) {
      return List.generate(24, (h) => {'hour': h, 'count': 0});
    }
  }

  // Lightweight helper (deprecated duplicate) – renamed to avoid clash
  Future<Map<String, dynamic>> getTopPurposeFromDbRaw({
    String? department,
  }) async {
    try {
      final client = _supabaseService.client;
      var query = client
          .from(SupabaseConfig.queueEntriesTable)
          .select('purpose');
      if (department != null) {
        query = query.eq(SupabaseConfig.departmentColumn, department);
      }
      final rows = await query;
      if (rows.isEmpty) return {'purpose': '—', 'count': 0};

      final Map<String, int> counts = {};
      for (final r in rows) {
        final p = (r['purpose'] ?? '').toString();
        if (p.isEmpty) continue;
        counts[p] = (counts[p] ?? 0) + 1;
      }
      if (counts.isEmpty) return {'purpose': '—', 'count': 0};

      final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return {'purpose': top.key, 'count': top.value};
    } catch (e) {
      return {'purpose': '—', 'count': 0};
    }
  }

  // Get comprehensive analytics data for high-impact graphs
  Future<Map<String, dynamic>> getComprehensiveAnalytics({
    String? department,
    String? timeRange,
    String? course,
    String? purpose,
    DateTime? month,
    DateTime? day,
  }) async {
    try {
      print('Getting comprehensive analytics data from Supabase');
      print('Filters: department=$department, course=$course, purpose=$purpose, month=$month, day=$day');

      // Fetch directly from Supabase with filters applied at database level
      List<QueueEntry> filteredEntries;
      
      // Handle 'ALL' department as null (fetch all departments)
      final effectiveDept = (department == 'ALL' || department == null) ? null : department;
      
      // Check if any filters are applied
      if (effectiveDept != null || course != null || purpose != null || month != null || day != null) {
        // Build query with filters
        var query = _supabaseService.client
            .from(SupabaseConfig.queueEntriesTable)
            .select();
        
        if (effectiveDept != null) {
          query = query.eq(SupabaseConfig.departmentColumn, effectiveDept);
        }
        
        if (course != null) {
          query = query.eq('course', course);
        }
        
        if (purpose != null) {
          query = query.eq(SupabaseConfig.purposeColumn, purpose);
        }
        
        // Day filter takes precedence over month filter
        if (day != null) {
          final startOfDay = DateTime(day.year, day.month, day.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));
          query = query
              .gte(SupabaseConfig.timestampColumn, startOfDay.toIso8601String())
              .lt(SupabaseConfig.timestampColumn, endOfDay.toIso8601String());
        } else if (month != null) {
          final startOfMonth = DateTime(month.year, month.month, 1);
          final endOfMonth = DateTime(month.year, month.month + 1, 1);
          query = query
              .gte(SupabaseConfig.timestampColumn, startOfMonth.toIso8601String())
              .lt(SupabaseConfig.timestampColumn, endOfMonth.toIso8601String());
        }
        
        final response = await query;
        print('Raw Supabase response count: ${response.length}');
        if (response.isNotEmpty) {
          print('Sample raw entry: ${response.first}');
        }
        filteredEntries = response.map((json) {
          try {
            return QueueEntry.fromJson(json);
          } catch (e) {
            print('Error parsing queue entry: $e, JSON: $json');
            rethrow;
          }
        }).toList();
        print('Fetched ${filteredEntries.length} entries from Supabase with filters');
        if (filteredEntries.isNotEmpty) {
          print('Sample parsed entry - Department: ${filteredEntries.first.department}, Purpose: ${filteredEntries.first.purpose}, Course: ${filteredEntries.first.course}');
        }
      } else {
        // Get all entries if no filters (master admin default)
        print('Fetching ALL queue entries from Supabase (no filters)');
        filteredEntries = await _supabaseService.getAllQueueEntries();
        print('Fetched ${filteredEntries.length} entries from Supabase (all data)');
        if (filteredEntries.isNotEmpty) {
          print('Sample entry - Department: ${filteredEntries.first.department}, Purpose: ${filteredEntries.first.purpose}, Course: ${filteredEntries.first.course}');
          // Count entries by department
          final deptCounts = <String, int>{};
          final purposeCounts = <String, int>{};
          final courseCounts = <String, int>{};
          for (final entry in filteredEntries) {
            deptCounts[entry.department] = (deptCounts[entry.department] ?? 0) + 1;
            purposeCounts[entry.purpose] = (purposeCounts[entry.purpose] ?? 0) + 1;
            if (entry.course != null && entry.course!.isNotEmpty) {
              courseCounts[entry.course!] = (courseCounts[entry.course!] ?? 0) + 1;
            }
          }
          print('Department distribution: $deptCounts');
          print('Purpose distribution: $purposeCounts');
          print('Course distribution: $courseCounts');
        } else {
          print('WARNING: No queue entries found in Supabase!');
        }
      }

      // Calculate key metrics
      final totalEntries = filteredEntries.length;
      final waitingCount = filteredEntries
          .where((e) => e.status == 'waiting')
          .length;
      final servingCount = filteredEntries
          .where((e) => e.status == 'current')
          .length;
      final completedCount = filteredEntries
          .where((e) => e.status == 'done' || e.status == 'completed')
          .length;
      final missedCount = filteredEntries
          .where((e) => e.status == 'missed')
          .length;

      // Calculate average wait time
      final avgWaitTime = _calculateAverageWaitTime(filteredEntries);

      // Get department distribution
      final departmentStats = _getDepartmentDistribution(filteredEntries);

      // Get hourly distribution
      final hourlyStats = _getHourlyDistribution(filteredEntries);

      // Get purpose distribution
      final purposeStats = _getPurposeDistribution(filteredEntries);
      // Compute top purpose for quick access
      String topPurpose = '';
      int topPurposeCount = 0;
      if (purposeStats.isNotEmpty) {
        purposeStats.sort(
          (a, b) => (b['count'] as int).compareTo(a['count'] as int),
        );
        topPurpose = purposeStats.first['purpose'];
        topPurposeCount = (purposeStats.first['count'] as num).toInt();
      }

      // Get department usage statistics (for master admin)
      final departmentUsage = _getDepartmentUsage(filteredEntries);
      
      // Get top courses usage (for master admin)
      final topCoursesUsage = _getTopCoursesUsage(filteredEntries);

      // Calculate efficiency metrics
      final efficiencyMetrics = _calculateEfficiencyMetrics(filteredEntries);

      // Prepare high-impact graph data
      final graphData = {
        'queue_status_chart': {
          'title': 'Queue Status Overview',
          'subtitle': 'Real-time queue distribution',
          'data': [
            {
              'label': 'Waiting',
              'value': waitingCount,
              'color': '#FF6B35',
              'icon': '⏳',
            },
            {
              'label': 'Serving',
              'value': servingCount,
              'color': '#4ECDC4',
              'icon': '👨‍💼',
            },
            {
              'label': 'Completed',
              'value': completedCount,
              'color': '#45B7D1',
              'icon': '✅',
            },
            {
              'label': 'Missed',
              'value': missedCount,
              'color': '#FF6B6B',
              'icon': '❌',
            },
          ],
          'total': totalEntries,
        },

        'department_performance': {
          'title': 'Department Performance',
          'subtitle': 'Queue efficiency by department',
          'data': departmentStats
              .map(
                (dept) => {
                  'department': dept['department'],
                  'total': dept['total'],
                  'completed': dept['completed'],
                  'efficiency': dept['efficiency'],
                  'color': _getDepartmentColor(dept['department']),
                },
              )
              .toList(),
        },

        'hourly_trend': {
          'title': 'Hourly Queue Trends',
          'subtitle': 'Queue activity throughout the day',
          'data': hourlyStats
              .map(
                (hour) => {
                  'hour': hour['hour'],
                  'count': hour['count'],
                  'color': hour['color'] ?? _getHourColor(hour['hour']),
                },
              )
              .toList(),
        },

        'purpose_breakdown': {
          'title': 'Purpose Distribution',
          'subtitle': 'Why people are in queue',
          'data': purposeStats
              .map(
                (purpose) => {
                  'purpose': purpose['purpose'],
                  'count': purpose['count'],
                  'percentage': purpose['percentage'],
                  'color': _getPurposeColor(purpose['purpose']),
                },
              )
              .toList(),
        },
        'top_purpose': {'purpose': topPurpose, 'count': topPurposeCount},

        'efficiency_gauge': {
          'title': 'Overall System Efficiency',
          'subtitle': 'Performance metrics',
          'data': {
            'completion_rate': efficiencyMetrics['completion_rate'],
            'avg_wait_time': efficiencyMetrics['avg_wait_time'],
            'throughput': efficiencyMetrics['throughput'],
            'satisfaction_score': efficiencyMetrics['satisfaction_score'],
          },
        },

        'real_time_metrics': {
          'title': 'Real-Time Metrics',
          'subtitle': 'Live queue statistics',
          'data': {
            'current_waiting': waitingCount,
            'currently_serving': servingCount,
            'total_served_today': completedCount,
            'next_queue_number': await _getNextQueueNumber(department),
            'estimated_wait_time': _estimateWaitTime(
              waitingCount,
              servingCount,
            ),
          },
        },

        // Master admin specific charts
        'department_usage': {
          'title': 'Department Queue Usage',
          'subtitle': 'Queue usage by department',
          'data': departmentUsage,
        },

        'top_courses_usage': {
          'title': 'Top Courses Queue Usage',
          'subtitle': 'Top courses using the queue system',
          'data': topCoursesUsage,
        },
      };

      final result = {
        'success': true,
        'timestamp': DateTime.now().toIso8601String(),
        'department': department ?? 'All Departments',
        'time_range': timeRange ?? 'All Time',
        'summary': {
          'total_entries': totalEntries,
          'waiting': waitingCount,
          'serving': servingCount,
          'completed': completedCount,
          'missed': missedCount,
          'avg_wait_time': avgWaitTime,
        },
        'graphs': graphData,
        'insights': _generateInsights(filteredEntries, department),
      };
      
      print('Analytics result summary: ${result['summary']}');
      print('Total entries: $totalEntries, Waiting: $waitingCount, Serving: $servingCount, Completed: $completedCount');
      print('Hourly stats count: ${hourlyStats.length}');
      print('Purpose stats count: ${purposeStats.length}');
      print('Department stats count: ${departmentStats.length}');
      print('Department usage count: ${departmentUsage.length}');
      print('Top courses usage count: ${topCoursesUsage.length}');
      print('Graph data keys: ${graphData.keys.toList()}');
      if (departmentUsage.isNotEmpty) {
        print('Sample department usage: ${departmentUsage.first}');
        print('All department usage data: $departmentUsage');
      } else {
        print('WARNING: departmentUsage is EMPTY!');
      }
      if (topCoursesUsage.isNotEmpty) {
        print('Sample top courses: ${topCoursesUsage.first}');
        print('All top courses data: $topCoursesUsage');
      } else {
        print('WARNING: topCoursesUsage is EMPTY!');
      }
      
      // Verify graphData structure
      if (graphData.containsKey('department_usage')) {
        print('department_usage in graphData: ${graphData['department_usage']}');
      } else {
        print('ERROR: department_usage NOT in graphData!');
      }
      if (graphData.containsKey('top_courses_usage')) {
        print('top_courses_usage in graphData: ${graphData['top_courses_usage']}');
      } else {
        print('ERROR: top_courses_usage NOT in graphData!');
      }
      
      // Debug: Print sample data to verify it's being generated
      if (hourlyStats.isNotEmpty) {
        print('Sample hourly data (first 3): ${hourlyStats.take(3).toList()}');
      } else {
        print('WARNING: Hourly stats is empty!');
      }
      if (purposeStats.isNotEmpty) {
        print('Sample purpose data (first 3): ${purposeStats.take(3).toList()}');
      } else {
        print('WARNING: Purpose stats is empty!');
      }
      
      print('Analytics service: Successfully returning result with ${graphData.keys.length} graph keys');
      final graphs = result['graphs'] as Map<String, dynamic>?;
      print('Analytics service: department_usage in result: ${graphs?.containsKey('department_usage') ?? false}');
      print('Analytics service: top_courses_usage in result: ${graphs?.containsKey('top_courses_usage') ?? false}');
      return result;
    } catch (e, stackTrace) {
      print('❌ ERROR getting comprehensive analytics: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: $stackTrace');
      
      // Try to return partial data even on error - at least get the charts working
      try {
        print('Attempting fallback: Getting basic data for charts...');
        final allEntries = await _supabaseService.getAllQueueEntries();
        print('Fallback: Got ${allEntries.length} entries');
        
        final deptUsage = _getDepartmentUsage(allEntries);
        print('Fallback: Got ${deptUsage.length} departments');
        
        final topCourses = _getTopCoursesUsage(allEntries);
        print('Fallback: Got ${topCourses.length} courses');
        
        return {
          'success': true, // Return true so charts can display
          'error': e.toString(),
          'message': 'Analytics loaded with some errors',
          'timestamp': DateTime.now().toIso8601String(),
          'department': department ?? 'All Departments',
          'time_range': timeRange ?? 'All Time',
          'summary': {
            'total_entries': allEntries.length,
            'waiting': allEntries.where((e) => e.status == 'waiting').length,
            'serving': allEntries.where((e) => e.status == 'current' || e.status == 'serving').length,
            'completed': allEntries.where((e) => e.status == 'done' || e.status == 'completed').length,
            'missed': allEntries.where((e) => e.status == 'missed').length,
            'avg_wait_time': 0.0,
          },
          'graphs': {
            'department_usage': {
              'title': 'Department Queue Usage',
              'subtitle': 'Queue usage by department',
              'data': deptUsage,
            },
            'top_courses_usage': {
              'title': 'Top Courses Queue Usage',
              'subtitle': 'Top courses using the queue system',
              'data': topCourses,
            },
          },
          'insights': [],
        };
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        return {
          'success': false,
          'error': e.toString(),
          'fallback_error': fallbackError.toString(),
          'message': 'Failed to load analytics data',
          'summary': {
            'total_entries': 0,
            'waiting': 0,
            'serving': 0,
            'completed': 0,
            'missed': 0,
            'avg_wait_time': 0.0,
          },
          'graphs': <String, dynamic>{},
          'insights': <String, dynamic>{},
        };
      }
    }
  }

  // Calculate average wait time
  double _calculateAverageWaitTime(List<QueueEntry> entries) {
    try {
      final completedEntries = entries
          .where((e) => e.status == 'done' || e.status == 'completed')
          .toList();
      if (completedEntries.isEmpty) return 0.0;

      double totalWaitTime = 0.0;
      int validEntries = 0;

      for (final entry in completedEntries) {
        if (entry.countdownStart != null) {
          final waitTime = entry.countdownStart!
              .difference(entry.timestamp)
              .inMinutes;
          if (waitTime > 0) {
            totalWaitTime += waitTime;
            validEntries++;
          }
        }
      }

      return validEntries > 0 ? totalWaitTime / validEntries : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Get department distribution
  List<Map<String, dynamic>> _getDepartmentDistribution(
    List<QueueEntry> entries,
  ) {
    final Map<String, Map<String, dynamic>> deptMap = {};

    for (final entry in entries) {
      if (!deptMap.containsKey(entry.department)) {
        deptMap[entry.department] = {
          'department': entry.department,
          'total': 0,
          'completed': 0,
          'waiting': 0,
          'serving': 0,
        };
      }

      deptMap[entry.department]!['total']++;

      switch (entry.status) {
        case 'done':
        case 'completed':
          deptMap[entry.department]!['completed']++;
          break;
        case 'waiting':
          deptMap[entry.department]!['waiting']++;
          break;
        case 'current':
        case 'serving':
          deptMap[entry.department]!['serving']++;
          break;
      }
    }

    // Calculate efficiency for each department
    return deptMap.values.map((dept) {
      final efficiency = dept['total'] > 0
          ? (dept['completed'] / dept['total'] * 100).roundToDouble()
          : 0.0;

      return {...dept, 'efficiency': efficiency};
    }).toList();
  }

  // Get hourly distribution
  List<Map<String, dynamic>> _getHourlyDistribution(List<QueueEntry> entries) {
    final Map<int, int> hourMap = {};

    for (int i = 0; i < 24; i++) {
      hourMap[i] = 0;
    }

    for (final entry in entries) {
      final hour = entry.timestamp.hour;
      hourMap[hour] = (hourMap[hour] ?? 0) + 1;
    }

    return hourMap.entries
        .map(
          (entry) => {
            'hour': entry.key,
            'count': entry.value,
            'label': '${entry.key.toString().padLeft(2, '0')}:00',
            'color': _getHourColor(entry.key),
          },
        )
        .toList();
  }

  // Get purpose distribution
  List<Map<String, dynamic>> _getPurposeDistribution(List<QueueEntry> entries) {
    final Map<String, int> purposeMap = {};
    final total = entries.length;

    for (final entry in entries) {
      purposeMap[entry.purpose] = (purposeMap[entry.purpose] ?? 0) + 1;
    }

    final result = purposeMap.entries.map((entry) {
      final percentage = total > 0
          ? (entry.value / total * 100).roundToDouble()
          : 0.0;

      return {
        'purpose': entry.key,
        'count': entry.value,
        'percentage': percentage,
      };
    }).toList();

    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  // Calculate efficiency metrics
  Map<String, dynamic> _calculateEfficiencyMetrics(List<QueueEntry> entries) {
    final total = entries.length;
    final completed = entries.where((e) => e.status == 'done' || e.status == 'completed').length;
    final avgWaitTime = _calculateAverageWaitTime(entries);

    final completionRate = total > 0
        ? (completed / total * 100).roundToDouble()
        : 0.0;
    final throughput = total > 0
        ? (total / 24.0).roundToDouble()
        : 0.0; // per hour
    final satisfactionScore = _calculateSatisfactionScore(entries);

    return {
      'completion_rate': completionRate,
      'avg_wait_time': avgWaitTime,
      'throughput': throughput,
      'satisfaction_score': satisfactionScore,
    };
  }

  // Calculate satisfaction score based on wait times and completion
  double _calculateSatisfactionScore(List<QueueEntry> entries) {
    try {
      double score = 100.0;

      // Penalize long wait times
      final avgWaitTime = _calculateAverageWaitTime(entries);
      if (avgWaitTime > 30) score -= 20;
      if (avgWaitTime > 60) score -= 30;

      // Penalize high missed rate
      final total = entries.length;
      final missed = entries.where((e) => e.status == 'missed').length;
      if (total > 0) {
        final missedRate = missed / total * 100;
        if (missedRate > 10) score -= 15;
        if (missedRate > 20) score -= 25;
      }

      return score.clamp(0.0, 100.0);
    } catch (e) {
      return 75.0; // Default score
    }
  }

  // Generate insights from data
  List<String> _generateInsights(List<QueueEntry> entries, String? department) {
    final insights = <String>[];

    if (entries.isEmpty) {
      insights.add('No queue data available for analysis');
      return insights;
    }

    final waiting = entries.where((e) => e.status == 'waiting').length;
    final completed = entries.where((e) => e.status == 'completed').length;
    final avgWaitTime = _calculateAverageWaitTime(entries);

    // Queue status insights
    if (waiting > 10) {
      insights.add('High queue volume detected - consider adding staff');
    }

    if (completed > 50) {
      insights.add('Excellent throughput - system is performing well');
    }

    if (avgWaitTime > 30) {
      insights.add('Average wait time is high - optimize service process');
    }

    // Department-specific insights
    if (department != null) {
      final deptEntries = entries
          .where((e) => e.department == department)
          .toList();
      final deptEfficiency = _calculateEfficiencyMetrics(deptEntries);

      if (deptEfficiency['completion_rate'] > 80) {
        insights.add('$department department shows high efficiency');
      }

      if (deptEfficiency['satisfaction_score'] < 70) {
        insights.add(
          '$department department needs improvement in service quality',
        );
      }
    }

    // Time-based insights
    final hourlyStats = _getHourlyDistribution(entries);
    if (hourlyStats.isNotEmpty) {
      final peakHour = hourlyStats.reduce(
        (a, b) => (a['count'] as int) > (b['count'] as int) ? a : b,
      );

      if (peakHour['count'] > 20) {
        insights.add(
          'Peak hour at ${peakHour['label']} - plan resources accordingly',
        );
      }
    }

    return insights;
  }

  // Get purpose distribution across all departments (for master admin)
  List<Map<String, dynamic>> _getPurposeByDepartment(List<QueueEntry> entries) {
    print('_getPurposeByDepartment: Processing ${entries.length} entries');
    final Map<String, Map<String, int>> purposeDeptMap = {};
    
    for (final entry in entries) {
      final purpose = entry.purpose;
      final dept = entry.department;
      
      if (purpose.isEmpty) {
        print('Warning: Found entry with empty purpose, skipping');
        continue;
      }
      
      if (!purposeDeptMap.containsKey(purpose)) {
        purposeDeptMap[purpose] = {};
      }
      
      purposeDeptMap[purpose]![dept] = (purposeDeptMap[purpose]![dept] ?? 0) + 1;
    }
    
    print('_getPurposeByDepartment: Found ${purposeDeptMap.length} unique purposes');
    
    // Convert to list format for pie chart
    final List<Map<String, dynamic>> result = [];
    for (final entry in purposeDeptMap.entries) {
      final purpose = entry.key;
      final deptCounts = entry.value;
      final totalCount = deptCounts.values.fold(0, (sum, count) => sum + count);
      
      result.add({
        'purpose': purpose,
        'count': totalCount,
        'departments': deptCounts.length,
        'color': _getPurposeColor(purpose),
      });
    }
    
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    print('_getPurposeByDepartment: Returning ${result.length} items');
    if (result.isNotEmpty) {
      print('_getPurposeByDepartment: Top item = ${result.first}');
    }
    return result;
  }

  // Get department usage statistics (for master admin)
  List<Map<String, dynamic>> _getDepartmentUsage(List<QueueEntry> entries) {
    print('_getDepartmentUsage: Processing ${entries.length} entries');
    final Map<String, int> deptMap = {};
    
    for (final entry in entries) {
      if (entry.department.isEmpty) {
        print('Warning: Found entry with empty department, skipping');
        continue;
      }
      deptMap[entry.department] = (deptMap[entry.department] ?? 0) + 1;
    }
    
    print('_getDepartmentUsage: Found ${deptMap.length} unique departments');
    
    final result = deptMap.entries.map((entry) {
      return {
        'department': entry.key,
        'count': entry.value,
        'color': _getDepartmentColor(entry.key),
      };
    }).toList();
    
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    print('_getDepartmentUsage: Returning ${result.length} items');
    if (result.isNotEmpty) {
      print('_getDepartmentUsage: Top item = ${result.first}');
    }
    return result;
  }

  // Get top courses usage (for master admin)
  List<Map<String, dynamic>> _getTopCoursesUsage(List<QueueEntry> entries) {
    print('_getTopCoursesUsage: Processing ${entries.length} entries');
    final Map<String, int> courseMap = {};
    
    int entriesWithCourse = 0;
    for (final entry in entries) {
      if (entry.course != null && entry.course!.isNotEmpty) {
        courseMap[entry.course!] = (courseMap[entry.course!] ?? 0) + 1;
        entriesWithCourse++;
      }
    }
    
    print('_getTopCoursesUsage: Found ${entriesWithCourse} entries with courses, ${courseMap.length} unique courses');
    
    final result = courseMap.entries.map((entry) {
      return {
        'course': entry.key,
        'count': entry.value,
        'color': _getCourseColor(entry.key),
      };
    }).toList();
    
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    final top10 = result.take(10).toList(); // Top 10 courses
    print('_getTopCoursesUsage: Returning ${top10.length} items (top 10)');
    if (top10.isNotEmpty) {
      print('_getTopCoursesUsage: Top item = ${top10.first}');
    }
    return top10;
  }

  // Color scheme for courses
  String _getCourseColor(String course) {
    // Generate a color based on course code hash
    final colors = [
      '#FF6B35', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E2',
    ];
    final index = course.hashCode.abs() % colors.length;
    return colors[index];
  }

  // Get next queue number
  Future<int> _getNextQueueNumber(String? department) async {
    try {
      if (department != null) {
        return await _supabaseService.getCurrentQueueNumberForDepartment(
          department,
        );
      } else {
        return await _supabaseService.getCurrentQueueNumber();
      }
    } catch (e) {
      return 1;
    }
  }

  // Estimate wait time
  String _estimateWaitTime(int waiting, int serving) {
    if (waiting == 0) return 'No wait';
    if (serving == 0) return 'Staff unavailable';

    final estimatedMinutes = (waiting / serving * 5)
        .round(); // 5 min per person
    if (estimatedMinutes < 1) return 'Less than 1 minute';
    if (estimatedMinutes < 60) return '$estimatedMinutes minutes';

    final hours = estimatedMinutes ~/ 60;
    final minutes = estimatedMinutes % 60;
    return '$hours hours $minutes minutes';
  }

  // Color schemes for departments
  String _getDepartmentColor(String department) {
    switch (department.toUpperCase()) {
      case 'CAS':
        return '#FF6B35';
      case 'COED':
        return '#4ECDC4';
      case 'CONHS':
        return '#45B7D1';
      case 'COENG':
        return '#96CEB4';
      case 'CIT':
        return '#FFEAA7';
      case 'CGS':
        return '#9B59B6'; // Purple for College of Graduating School
      default:
        return '#DDA0DD';
    }
  }

  // Color schemes for hours
  String _getHourColor(int hour) {
    if (hour >= 6 && hour <= 18) return '#4ECDC4'; // Day hours
    if (hour >= 19 && hour <= 22) return '#FF6B35'; // Evening hours
    return '#96CEB4'; // Night hours
  }

  // Color schemes for purposes
  String _getPurposeColor(String purpose) {
    switch (purpose.toLowerCase()) {
      case 'enrollment':
        return '#FF6B35';
      case 'consultation':
        return '#4ECDC4';
      case 'documentation':
        return '#45B7D1';
      case 'payment':
        return '#96CEB4';
      case 'inquiry':
        return '#FFEAA7';
      default:
        return '#DDA0DD';
    }
  }
}
