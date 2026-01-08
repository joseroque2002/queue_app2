import 'package:flutter/material.dart';
import '../models/queue_entry.dart';
import '../models/admin_user.dart';
import '../services/supabase_service.dart';
import '../services/excel_export_service.dart';
import '../services/department_service.dart';
import '../services/purpose_service.dart';

class RecordsViewScreen extends StatefulWidget {
  final AdminUser currentAdmin;

  const RecordsViewScreen({super.key, required this.currentAdmin});

  @override
  State<RecordsViewScreen> createState() => _RecordsViewScreenState();
}

class _RecordsViewScreenState extends State<RecordsViewScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ExcelExportService _excelService = ExcelExportService();
  final DepartmentService _departmentService = DepartmentService();
  final PurposeService _purposeService = PurposeService();

  List<QueueEntry> _allRecords = [];
  List<QueueEntry> _filteredRecords = [];
  bool _isLoading = false;
  bool _isExporting = false;
  String _selectedFilter = 'all';
  String _selectedStatus = 'all';
  String _selectedPriority = 'all';
  String _selectedPurpose = 'all';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, int> _statistics = {};
  Set<String> _availablePriorityTypes = {'priority', 'pwd', 'senior', 'pregnant', 'regular'}; // Default set

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadRecords();
  }

  Future<void> _initializeServices() async {
    try {
      await _purposeService.initializeDefaultPurposes();
    } catch (e) {
      debugPrint('Error initializing purposes: $e');
    }
  }

  Future<void> _fetchAvailablePriorityTypes() async {
    try {
      // Query Supabase to get unique priority combinations
      final response = await _supabaseService.client
          .from('queue_entries')
          .select('is_pwd, is_senior, is_pregnant, is_priority');

      final Set<String> priorityTypes = {'priority', 'regular'}; // Always include these

      for (final row in response) {
        final isPwd = row['is_pwd'] as bool? ?? false;
        final isSenior = row['is_senior'] as bool? ?? false;
        final isPregnant = row['is_pregnant'] as bool? ?? false;

        if (isPwd) priorityTypes.add('pwd');
        if (isSenior) priorityTypes.add('senior');
        if (isPregnant) priorityTypes.add('pregnant');
      }

      setState(() {
        _availablePriorityTypes = priorityTypes;
      });
    } catch (e) {
      debugPrint('Error fetching priority types: $e');
      // Keep default set on error
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _testDatabaseConnection() async {
    await _excelService.testDatabaseConnection();
    _showSuccessSnackBar('Database test completed. Check console for results.');
  }

  Future<void> _testExcelCreation() async {
    await _excelService.testExcelCreation();
    _showSuccessSnackBar('Excel test completed. Check console for results.');
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // For department admins, only load records from their department
      if (widget.currentAdmin.department != 'ALL') {
        // Department admin - filter by their department
        final response = await _supabaseService.client
            .from('queue_entries')
            .select()
            .eq('department', widget.currentAdmin.department)
            .order('timestamp', ascending: false);
        
        _allRecords = response.map((json) => QueueEntry.fromJson(json)).toList();
        print('Records View (${widget.currentAdmin.department}): Loaded ${_allRecords.length} department records');
      } else {
        // Master admin - load all records
        _allRecords = await _supabaseService.getAllQueueEntries();
        print('Records View (Master): Loaded ${_allRecords.length} records');
      }

      if (_allRecords.isNotEmpty) {
        print(
          'Records View: First record: ${_allRecords.first.name} - ${_allRecords.first.department}',
        );
      }

      // Calculate statistics from filtered records
      _calculateStatistics();

      // Fetch available priority types from Supabase
      _fetchAvailablePriorityTypes();

      _applyFilters();
    } catch (e) {
      debugPrint('Error loading records: $e');
      _showErrorSnackBar('Failed to load records: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateStatistics() {
    int totalRecords = _allRecords.length;
    int priorityRecords = _allRecords.where((e) => e.isPriority).length;
    int completedRecords = _allRecords.where((e) => e.status == 'completed').length;
    int waitingRecords = _allRecords.where((e) => e.status == 'waiting').length;

    _statistics = {
      'total': totalRecords,
      'priority': priorityRecords,
      'completed': completedRecords,
      'waiting': waitingRecords,
    };
  }

  void _applyFilters() {
    _filteredRecords = _allRecords.where((entry) {
      // Department filter
      if (_selectedFilter != 'all' && entry.department != _selectedFilter) {
        return false;
      }

      // Status filter
      if (_selectedStatus != 'all' && entry.status != _selectedStatus) {
        return false;
      }

      // Priority filter
      if (_selectedPriority != 'all') {
        switch (_selectedPriority) {
          case 'priority':
            if (!entry.isPriority) return false;
            break;
          case 'pwd':
            if (!entry.isPwd) return false;
            break;
          case 'senior':
            if (!entry.isSenior) return false;
            break;
          case 'pregnant':
            if (!entry.isPregnant) return false;
            break;
          case 'regular':
            if (entry.isPriority) return false;
            break;
        }
      }

      // Purpose filter
      if (_selectedPurpose != 'all' && entry.purpose != _selectedPurpose) {
        return false;
      }

      // Date range filter
      if (_startDate != null || _endDate != null) {
        final entryDate = entry.timestamp;
        if (_startDate != null && entryDate.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null) {
          // Include the entire end date (up to 23:59:59)
          final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
          if (entryDate.isAfter(endOfDay)) {
            return false;
          }
        }
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!entry.name.toLowerCase().contains(query) &&
            !entry.email.toLowerCase().contains(query) &&
            !entry.phoneNumber.contains(query) &&
            !entry.queueNumber.toString().contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by priority first, then by queue number
    _filteredRecords.sort((a, b) {
      if (a.isPriority && !b.isPriority) return -1;
      if (!a.isPriority && b.isPriority) return 1;
      return a.queueNumber.compareTo(b.queueNumber);
    });
  }

  Future<void> _exportToExcel() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export to Excel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to export the queue records to Excel?\n',
            ),
            Text(
              'Total records: ${_filteredRecords.length}\n',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_selectedFilter != 'all')
              Text('• Department: ${_departmentService.getDepartmentByCode(_selectedFilter)?.name ?? _selectedFilter}'),
            if (_selectedStatus != 'all')
              Text('• Status: $_selectedStatus'),
            if (_selectedPriority != 'all')
              Text('• Priority: $_selectedPriority'),
            if (_selectedPurpose != 'all')
              Text('• Purpose: $_selectedPurpose'),
            if (_searchQuery.isNotEmpty)
              Text('• Search: "$_searchQuery"'),
            if (_startDate != null || _endDate != null) ...[
              if (_startDate != null)
                Text('• Start Date: ${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'),
              if (_endDate != null)
                Text('• End Date: ${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'),
            ],
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
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      String? filePath;

      // Export filtered records (respects all current filters)
      filePath = await _excelService.exportFilteredRecords(
        department: _selectedFilter == 'all' ? null : _selectedFilter,
        purpose: _selectedPurpose == 'all' ? null : _selectedPurpose,
        startDate: _startDate,
        endDate: _endDate,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        priority: _selectedPriority == 'all' ? null : _selectedPriority,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (filePath != null) {
        _showSuccessSnackBar(
          'Excel file exported successfully!\nSaved to: $filePath',
        );
      } else {
        _showErrorSnackBar('Failed to export Excel file');
      }
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      _showErrorSnackBar('Export failed: $e');
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Queue Records'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _testDatabaseConnection,
            tooltip: 'Test Database Connection',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: _testExcelCreation,
            tooltip: 'Test Excel Creation',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: 'Refresh Records',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatisticsCard(),
          _buildFiltersCard(),
          _buildSearchCard(),
          Expanded(child: _buildRecordsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isExporting ? null : _exportToExcel,
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        icon: _isExporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.download),
        label: Text(_isExporting ? 'Exporting...' : 'Export to Excel'),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Records Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    _statistics['total'] ?? 0,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Priority',
                    _statistics['priority'] ?? 0,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Completed',
                    _statistics['completed'] ?? 0,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Waiting',
                    _statistics['waiting'] ?? 0,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Only show department filter for master admin
                if (widget.currentAdmin.department == 'ALL') ...[
                  Expanded(
                    child: _buildFilterDropdown(
                      'Department',
                      _selectedFilter,
                      _getDepartmentOptions(),
                      (value) {
                        setState(() {
                          _selectedFilter = value!;
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _buildFilterDropdown(
                    'Status',
                    _selectedStatus,
                    const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                        value: 'waiting',
                        child: Text('Waiting'),
                      ),
                      DropdownMenuItem(
                        value: 'current',
                        child: Text('Current'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(value: 'missed', child: Text('Missed')),
                    ],
                    (value) {
                      setState(() {
                        _selectedStatus = value!;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDropdown(
                    'Priority',
                    _selectedPriority,
                    _getPriorityOptions(),
                    (value) {
                      setState(() {
                        _selectedPriority = value!;
                        _applyFilters();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    'Purpose',
                    _selectedPurpose,
                    _getPurposeOptions(),
                    (value) {
                      setState(() {
                        _selectedPurpose = value!;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateFilter(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date Range',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final DateTimeRange? picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _startDate != null && _endDate != null
                  ? DateTimeRange(start: _startDate!, end: _endDate!)
                  : null,
            );
            if (picked != null) {
              setState(() {
                _startDate = picked.start;
                _endDate = picked.end;
                _applyFilters();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _startDate == null && _endDate == null
                        ? 'Select date range'
                        : _startDate != null && _endDate != null
                            ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                            : _startDate != null
                                ? 'From ${_formatDate(_startDate!)}'
                                : 'Until ${_formatDate(_endDate!)}',
                    style: TextStyle(
                      color: _startDate == null && _endDate == null
                          ? Colors.grey[600]
                          : Colors.black87,
                    ),
                  ),
                ),
                if (_startDate != null || _endDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _applyFilters();
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  List<DropdownMenuItem<String>> _getDepartmentOptions() {
    final departments = _departmentService.getActiveDepartments();
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Departments')),
    ];

    for (final dept in departments) {
      items.add(
        DropdownMenuItem(
          value: dept.code,
          child: Text('${dept.code} - ${dept.name}'),
        ),
      );
    }

    return items;
  }

  List<DropdownMenuItem<String>> _getPurposeOptions() {
    final purposes = _purposeService.getActivePurposes();
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Purposes')),
    ];

    for (final purpose in purposes) {
      items.add(
        DropdownMenuItem(
          value: purpose.name,
          child: Text(purpose.name),
        ),
      );
    }

    return items;
  }

  List<DropdownMenuItem<String>> _getPriorityOptions() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Priorities')),
    ];

    // Add priority types that exist in the database
    if (_availablePriorityTypes.contains('priority')) {
      items.add(
        const DropdownMenuItem(
          value: 'priority',
          child: Text('Priority'),
        ),
      );
    }
    if (_availablePriorityTypes.contains('pwd')) {
      items.add(
        const DropdownMenuItem(
          value: 'pwd',
          child: Text('PWD'),
        ),
      );
    }
    if (_availablePriorityTypes.contains('senior')) {
      items.add(
        const DropdownMenuItem(
          value: 'senior',
          child: Text('Senior'),
        ),
      );
    }
    if (_availablePriorityTypes.contains('pregnant')) {
      items.add(
        const DropdownMenuItem(
          value: 'pregnant',
          child: Text('Pregnant'),
        ),
      );
    }
    if (_availablePriorityTypes.contains('regular')) {
      items.add(
        const DropdownMenuItem(
          value: 'regular',
          child: Text('Regular'),
        ),
      );
    }

    return items;
  }

  Widget _buildSearchCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name, email, phone, or queue number...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _applyFilters();
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _applyFilters();
            });
          },
        ),
      ),
    );
  }

  Widget _buildRecordsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No records found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search criteria',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final entry = _filteredRecords[index];
        return _buildRecordCard(entry);
      },
    );
  }

  Widget _buildRecordCard(QueueEntry entry) {
    final departmentName =
        _departmentService.getDepartmentByCode(entry.department)?.name ??
        entry.department;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: entry.isPriority ? Colors.green : Colors.blue,
          child: Text(
            entry.queueNumber.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (entry.isPriority) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entry.isPwd ? Icons.accessible : Icons.elderly,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.priorityType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.email, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.email)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(entry.phoneNumber),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.business, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(child: Text('$departmentName (${entry.department})')),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.school, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('${entry.studentType}'),
                const SizedBox(width: 16),
                Icon(Icons.description, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.purpose)),
              ],
            ),
            if (entry.referenceNumber != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.receipt_long, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ref: ${entry.referenceNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusChip(entry.status),
                const SizedBox(width: 8),
                Text(
                  'Created: ${_formatDateTime(entry.timestamp)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'waiting':
        color = Colors.orange;
        break;
      case 'current':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'missed':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
