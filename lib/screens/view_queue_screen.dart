// ✅ Fixed but same algo & design
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/department_service.dart';
import '../services/bluetooth_tts_service.dart';
import '../models/queue_entry.dart';

class ViewQueueScreen extends StatefulWidget {
  const ViewQueueScreen({super.key});

  @override
  State<ViewQueueScreen> createState() => _ViewQueueScreenState();
}

class _ViewQueueScreenState extends State<ViewQueueScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _staggerController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late final List<Animation<double>> _staggerAnimations = [];

  final SupabaseService _supabaseService = SupabaseService();
  final DepartmentService _departmentService = DepartmentService();
  final BluetoothTtsService _bluetoothTtsService = BluetoothTtsService();
  List<String> _departments = [];
  final Map<String, List<QueueEntry>> _departmentQueues = {};
  Timer? _countdownTimer;
  Timer? _autoRefreshTimer;
  RealtimeChannel? _queueChannel;
  RealtimeChannel? _departmentChannel;
  bool _isLoading = true;
  final Map<String, QueueEntry?> _previousFirstEntries = {};

  @override
  void initState() {
    super.initState();

    // Initialize departments from service (async)
    _initializeDepartments();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Staggered animations (safe interval clamping)
    for (int i = 0; i < _departments.length; i++) {
      final start = i * 0.15;
      final end = (i + 1) * 0.15;
      _staggerAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _staggerController,
            curve: Interval(
              start,
              end > 1.0 ? 1.0 : end,
              curve: Curves.easeOutBack,
            ),
          ),
        ),
      );
    }

    _initializeBluetoothTts().then((_) {
      _initializeDepartments().then((_) {
      _loadQueueData().then((_) {
        if (mounted) {
          setState(() => _isLoading = false);

          _fadeController.forward();
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _slideController.forward();
          });
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) _staggerController.forward();
          });
        }
        });
      });
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // refresh countdown
      } else {
        timer.cancel();
      }
    });

    // Auto-refresh queues every 2 seconds so the display follows updates quickly
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _loadQueueData();
      if (mounted) setState(() {});
    });

    // Realtime subscription: update immediately on DB changes
    _queueChannel = Supabase.instance.client
        .channel('public:queue_entries')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'queue_entries',
          callback: (payload) async {
            // Force refresh when any queue entry changes
            await _loadQueueData();
            if (mounted) setState(() {});
          },
        )
        .subscribe();

    // Realtime subscription for departments: refresh when departments are added/updated/deleted
    _departmentChannel = Supabase.instance.client
        .channel('public:departments')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'departments',
          callback: (payload) async {
            // Reload departments when they change
            await _initializeDepartments();
            // Reload queue data for new departments
            await _loadQueueData();
            if (mounted) setState(() {});
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _staggerController.dispose();
    _countdownTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _queueChannel?.unsubscribe();
    _departmentChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initializeBluetoothTts() async {
    try {
      await _bluetoothTtsService.initialize();
    } catch (e) {
      debugPrint('Error initializing Bluetooth TTS: $e');
    }
  }

  Future<void> _initializeDepartments() async {
    try {
      // Load departments from database
      await _departmentService.initializeDefaultDepartments();
      // Get only active departments for live queue display
      final activeDepartments = _departmentService.getActiveDepartments();
      setState(() {
        _departments = activeDepartments.map((dept) => dept.code).toList();
        // Rebuild stagger animations for new department count
        _staggerAnimations.clear();
        for (int i = 0; i < _departments.length; i++) {
          final start = i * 0.15;
          final end = (i + 1) * 0.15;
          _staggerAnimations.add(
            Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _staggerController,
                curve: Interval(
                  start,
                  end > 1.0 ? 1.0 : end,
                  curve: Curves.easeOutBack,
                ),
              ),
            ),
          );
        }
      });
      debugPrint('Loaded ${_departments.length} active departments for live queue');
    } catch (e) {
      debugPrint('Error initializing departments: $e');
      // Fallback to empty list if database fails
      setState(() {
        _departments = [];
      });
    }
  }

  Future<void> _loadQueueData() async {
    try {
      // Ensure departments are loaded before fetching queue data
      if (_departments.isEmpty) {
        debugPrint('No departments available, skipping queue data load');
        return;
      }

      // Check for expired countdowns and clean up missed entries before loading data
      await _supabaseService.checkExpiredCountdowns();
      await _supabaseService.removeMissedEntriesFromLiveQueue();

      for (final department in _departments) {
        try {
        // Get only top 12 active entries (waiting and serving) for live display (4x3 grid)
        final entries = await _supabaseService
            .getTop12ActiveQueueEntriesByDepartment(department);
          
          debugPrint('Loaded ${entries.length} entries for department $department');
          
        // Sort by priority first, then by queue number (PWD/Senior appear in top 2)
        entries.sort((a, b) {
          // Priority users first
          if (a.isPriority && !b.isPriority) return -1;
          if (!a.isPriority && b.isPriority) return 1;
          // Within same priority level, sort by queue number
          return a.queueNumber.compareTo(b.queueNumber);
        });
        
        // Get first entry for tracking (no automatic announcements)
        final firstEntry = entries.isNotEmpty ? entries.first : null;
        
        // Don't announce automatically - only announce when department admin clicks Start
        
        _previousFirstEntries[department] = firstEntry;
        _departmentQueues[department] = entries;
        } catch (deptError) {
          debugPrint('Error loading queue data for department $department: $deptError');
          // Continue with other departments even if one fails
          _departmentQueues[department] = [];
        }
      }
    } catch (e) {
      debugPrint('Error loading queue data: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  Widget _buildDepartment(String department, int index) {
    // Hide any entries that are not waiting/current to ensure missed don't display
    final entries = (_departmentQueues[department] ?? [])
        .where((e) => e.status == 'waiting' || e.status == 'current')
        .toList();
    final animation = _staggerAnimations[index % _staggerAnimations.length];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(12),
            width: 430, // Fixed width for consistent container sizing
            height: 400, // 1x height (matches width for 1:1 aspect ratio)
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
              mainAxisSize: MainAxisSize.min,
              children: [
                // Department header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF263277), Color(0xFF4A90E2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              department,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 28,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              _departmentService
                                      .getDepartmentByCode(department)
                                      ?.name ??
                                  department,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 18,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entries.length}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: _buildQueueGrid(context, entries),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQueueGrid(
    BuildContext context,
    List<QueueEntry> entries,
  ) {
    // Always show 12 slots in a 4x3 grid (4 columns, 3 rows)
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 4 columns
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0, // 1x1 square containers
      ),
      itemCount: 12, // Always 12 slots
        itemBuilder: (context, index) {
        if (index < entries.length) {
          // Show actual entry
          final person = entries[index];
          final bool isFirst = index == 0;

          if (isFirst &&
              person.status == 'current' &&
              person.countdownStart != null &&
              person.countdownDuration > 0) {
            final DateTime now = DateTime.now();
            final int elapsed = now.difference(person.countdownStart!).inSeconds;
            final int remaining = person.countdownDuration - elapsed.clamp(0, 9999);
            final double progress = (remaining / person.countdownDuration).clamp(
              0.0,
              1.0,
            );

            Color getProgressColor() {
              if (remaining <= 0) return Colors.red;
              if (remaining <= 10) return Colors.orange;
              return Colors.blue;
            }

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: getProgressColor(), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: getProgressColor().withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            getProgressColor(),
                            getProgressColor().withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        person.queueNumber.toString().padLeft(3, '0'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: remaining <= 0 ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          Color getBarColor() {
            // Priority entries get green color
            if (person.isPriority) {
              switch (person.status) {
                case 'done':
                  return Colors.green.shade700;
                case 'missed':
                  return Colors.red;
                case 'current':
                  return Colors.green.shade600;
                default:
                  return Colors.green.shade500; // Green for priority entries
              }
            }

            // Regular entries
            switch (person.status) {
              case 'done':
                return Colors.green;
              case 'missed':
                return Colors.red;
              case 'current':
                return Colors.blue;
              default:
                return isFirst
                    ? const Color(0xFF263277)
                    : const Color(0xFF263277).withOpacity(0.1);
            }
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [getBarColor(), getBarColor().withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: getBarColor(), width: isFirst ? 3 : 2),
              boxShadow: [
                BoxShadow(
                  color: getBarColor().withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        person.queueNumber.toString().padLeft(3, '0'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Show empty slot
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_rounded, size: 20, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '---',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildLogoContainer() {
    return Container(
      margin: const EdgeInsets.all(8),
      width: 300,
      height: 300,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/queue_logo.jpg',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.image_not_supported,
                size: 64,
                color: Colors.grey.shade400,
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildDepartmentGrid() {
    final List<Widget> rows = [];
    
    // Limit to 8 departments (4 columns × 2 rows)
    final departmentsToShow = _departments.take(8).toList();

    // Build rows with 4 departments each
    for (int i = 0; i < departmentsToShow.length; i += 4) {
      final List<Widget> rowChildren = [];

      // First department in the row
      rowChildren.add(_buildDepartment(departmentsToShow[i], i));

      // Second department in the row (if exists)
      if (i + 1 < departmentsToShow.length) {
        rowChildren.add(_buildDepartment(departmentsToShow[i + 1], i + 1));
      }

      // Third department in the row (if exists)
      if (i + 2 < departmentsToShow.length) {
        rowChildren.add(_buildDepartment(departmentsToShow[i + 2], i + 2));
      }

      // Fourth department in the row (if exists)
      if (i + 3 < departmentsToShow.length) {
        rowChildren.add(_buildDepartment(departmentsToShow[i + 3], i + 3));
      }

      // Add logo container to the second row only (when i == 4), next to departments
      if (i == 4) {
        rowChildren.add(_buildLogoContainer());
      }

      rows.add(Row(
        children: rowChildren,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      ));
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔙 Header
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF263277),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF263277), Color(0xFF4A90E2)],
                        ),
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
                        children: [
                          const Icon(
                            Icons.queue_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Live Queue Display",
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF263277),
                        ),
                      )
                    : SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SingleChildScrollView(
                            child: Column(children: _buildDepartmentGrid()),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
