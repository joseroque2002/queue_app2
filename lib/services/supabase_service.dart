import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_config.dart';
import '../models/queue_entry.dart';
import '../models/admin_user.dart';
import '../models/department.dart';
import '../models/purpose.dart';
import '../models/course.dart';
import 'email_service.dart';
import 'tts_service.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _supabase;

  // Initialize Supabase
  Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    _supabase = Supabase.instance.client;
  }

  // Get Supabase client
  SupabaseClient get client => _supabase;

  // Test database connection and verify tables
  Future<Map<String, dynamic>> testDatabaseConnection() async {
    try {
      print('Testing database connection...');

      // Test if we can connect to Supabase
      await _supabase
          .from(SupabaseConfig.adminUsersTable)
          .select('count')
          .limit(1);

      print('Database connection successful');

      // Check if admin_users table has data
      final adminCount = await _supabase
          .from(SupabaseConfig.adminUsersTable)
          .select('id')
          .limit(10);

      // Check if queue_entries table exists
      await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select('count')
          .limit(1);

      return {
        'status': 'success',
        'admin_users_count': adminCount.length,
        'queue_entries_accessible': true,
        'message': 'Database connection successful',
      };
    } catch (e) {
      print('Database connection test failed: $e');
      return {
        'status': 'error',
        'error': e.toString(),
        'message': 'Database connection failed',
      };
    }
  }

  // Queue Entries Operations
  Future<List<QueueEntry>> getAllQueueEntries() async {
    try {
      print('Fetching ALL queue entries from Supabase table: ${SupabaseConfig.queueEntriesTable}');
      // Fetch ALL entries regardless of status - no filters applied
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .order(SupabaseConfig.timestampColumn, ascending: false); // Order by most recent first

      print('Raw Supabase response: ${response.length} entries');
      if (response.isNotEmpty) {
        print('Sample raw entry keys: ${(response.first as Map).keys.toList()}');
        print('Sample raw entry: ${response.first}');
      } else {
        print('WARNING: No entries found in Supabase!');
      }

      final entries = response.map((json) {
        try {
          return QueueEntry.fromJson(json);
        } catch (e) {
          print('Error parsing queue entry JSON: $e');
          print('Problematic JSON: $json');
          rethrow;
        }
      }).toList();

      print('Successfully parsed ${entries.length} queue entries');
      if (entries.isNotEmpty) {
        // Log sample data to verify structure
        final sample = entries.first;
        print('Sample entry - ID: ${sample.id}, Department: ${sample.department}, Course: ${sample.course}, Purpose: ${sample.purpose}, Status: ${sample.status}');
      }
      return entries;
    } catch (e, stackTrace) {
      print('Error fetching queue entries: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<QueueEntry>> getQueueEntriesByDepartment(
    String department,
  ) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, department)
          .or(
            '${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusWaiting},${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusServing}',
          )
          .order('is_priority', ascending: false) // Priority first
          .order(
            SupabaseConfig.queueNumberColumn,
            ascending: true,
          ) // Then by queue number
          .order(SupabaseConfig.statusColumn, ascending: false);

      return response.map((json) => QueueEntry.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching department entries: $e');
      return [];
    }
  }

  // Get only active queue entries (waiting and serving) for live display
  Future<List<QueueEntry>> getActiveQueueEntriesByDepartment(
    String department,
  ) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, department)
          .or(
            '${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusWaiting},${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusServing}',
          )
          .order('is_priority', ascending: false) // Priority first
          .order(
            SupabaseConfig.queueNumberColumn,
            ascending: true,
          ) // Then by queue number
          .order(SupabaseConfig.statusColumn, ascending: false);

      return response.map((json) => QueueEntry.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching active department entries: $e');
      return [];
    }
  }

  // Get all active queue entries across all departments (for master admin)
  Future<List<QueueEntry>> getAllActiveQueueEntries() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .or(
            '${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusWaiting},${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusServing}',
          )
          .order('is_priority', ascending: false) // Priority first
          .order(
            SupabaseConfig.queueNumberColumn,
            ascending: true,
          ) // Then by queue number
          .order(SupabaseConfig.statusColumn, ascending: false)
          .order(SupabaseConfig.departmentColumn, ascending: true); // Then by department

      return response.map((json) => QueueEntry.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching all active queue entries: $e');
      return [];
    }
  }

  // Get top 12 active queue entries for live display (4x3 grid)
  Future<List<QueueEntry>> getTop12ActiveQueueEntriesByDepartment(
    String department,
  ) async {
    try {
      // Use .or() with correct PostgREST filter syntax
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, department)
          .or(
            '${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusWaiting},${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusServing}',
          )
          .order('is_priority', ascending: false) // Priority first
          .order(
            SupabaseConfig.queueNumberColumn,
            ascending: true,
          ) // Then by queue number
          .order(SupabaseConfig.statusColumn, ascending: false)
          .limit(12);

      print('Fetched ${response.length} entries for department $department');
      
      if (response.isNotEmpty) {
        print('Sample entry: ${response.first}');
      }
      
      final entries = response.map((json) {
        try {
          return QueueEntry.fromJson(json);
        } catch (parseError) {
          print('Error parsing entry: $parseError');
          print('Entry JSON: $json');
          rethrow;
        }
      }).toList();
      
      print('Parsed ${entries.length} QueueEntry objects for department $department');
      
      return entries;
    } catch (e) {
      print('Error fetching top 12 active department entries for $department: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get top 4 active queue entries for live display (2x2 grid)
  Future<List<QueueEntry>> getTop4ActiveQueueEntriesByDepartment(
    String department,
  ) async {
    try {
      // Use .or() with correct PostgREST filter syntax
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, department)
          .or(
            '${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusWaiting},${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusServing}',
          )
          .order('is_priority', ascending: false) // Priority first
          .order(
            SupabaseConfig.queueNumberColumn,
            ascending: true,
          ) // Then by queue number
          .order(SupabaseConfig.statusColumn, ascending: false)
          .limit(4);

      print('Fetched ${response.length} entries for department $department');
      
      if (response.isNotEmpty) {
        print('Sample entry: ${response.first}');
      }
      
      final entries = response.map((json) {
        try {
          return QueueEntry.fromJson(json);
        } catch (parseError) {
          print('Error parsing entry: $parseError');
          print('Entry JSON: $json');
          rethrow;
        }
      }).toList();
      
      print('Parsed ${entries.length} QueueEntry objects for department $department');
      
      return entries;
    } catch (e) {
      print('Error fetching top 4 active department entries for $department: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get top 8 active queue entries for live display (4x2 grid)
  Future<List<QueueEntry>> getTop5ActiveQueueEntriesByDepartment(
    String department,
  ) async {
    try {
      // Use .or() with correct PostgREST filter syntax
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, department)
          .or(
            '${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusWaiting},${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusServing}',
          )
          .order('is_priority', ascending: false) // Priority first
          .order(
            SupabaseConfig.queueNumberColumn,
            ascending: true,
          ) // Then by queue number
          .order(SupabaseConfig.statusColumn, ascending: false)
          .limit(8);

      print('Fetched ${response.length} entries for department $department');
      
      if (response.isNotEmpty) {
        print('Sample entry: ${response.first}');
      }
      
      final entries = response.map((json) {
        try {
          return QueueEntry.fromJson(json);
        } catch (parseError) {
          print('Error parsing entry: $parseError');
          print('Entry JSON: $json');
          rethrow;
        }
      }).toList();
      
      print('Parsed ${entries.length} QueueEntry objects for department $department');
      
      return entries;
    } catch (e) {
      print('Error fetching top 5 active department entries for $department: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Generate a unique reference number for a queue entry
  String _generateReferenceNumber(String department, int queueNumber) {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final queueStr = queueNumber.toString().padLeft(4, '0');
    return 'REF-$dateStr-$department-$queueStr-$timeStr';
  }

  Future<QueueEntry?> addQueueEntry({
    required String name,
    required String ssuId,
    required String email,
    required String phoneNumber,
    required String department,
    required String purpose,
    required String course, // Course is now required
    bool isPwd = false,
    bool isSenior = false,
    bool isPregnant = false,
    String studentType = 'Student',
    String? gender,
    int? age,
    int? graduationYear,
  }) async {
    try {
      // Get the next queue number for this department (regular numbering)
      final nextNumber = await _getNextQueueNumberForDepartment(department);

      // Generate unique reference number
      final referenceNumber = _generateReferenceNumber(department, nextNumber);

      final entry = QueueEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        ssuId: ssuId,
        email: email,
        phoneNumber: phoneNumber,
        department: department,
        purpose: purpose,
        course: course,
        timestamp: DateTime.now(),
        queueNumber: nextNumber,
        isPwd: isPwd,
        isSenior: isSenior,
        isPregnant: isPregnant,
        studentType: studentType,
        referenceNumber: referenceNumber,
        gender: gender,
        age: age,
        graduationYear: graduationYear,
      );

      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .insert(entry.toJson())
          .select()
          .single();

      final created = QueueEntry.fromJson(response);

      // Send email confirmation on creation
      try {
        final emailService = EmailService();
        final emailSent = await emailService.sendQueueCreatedEmail(created);
        if (emailSent) {
          print('✅ Queue creation email sent successfully to ${created.email}');
        } else {
          print('⚠️ Queue creation email failed to send to ${created.email}');
        }
      } catch (emailError) {
        print('❌ Error sending creation email: $emailError');
      }

      // Check if user is now in top 5 of active queue (not just queue number)
      try {
        final activeQueue = await getActiveQueueEntriesByDepartment(department);
        final userPosition = activeQueue.indexWhere((entry) => entry.id == created.id) + 1;
        
        if (userPosition == 5) {
          // Check if top 5 email was already sent
          final response = await _supabase
              .from(SupabaseConfig.queueEntriesTable)
              .select('notified_top5')
              .eq(SupabaseConfig.idColumn, created.id)
              .single();
          
          final alreadyNotified = response['notified_top5'] ?? false;
          
          if (!alreadyNotified) {
            final emailService = EmailService();
            final emailSent = await emailService.sendTopFiveEmail(created);
            if (emailSent) {
              // Mark as notified to prevent duplicate emails
              await _supabase
                  .from(SupabaseConfig.queueEntriesTable)
                  .update({'notified_top5': true})
                  .eq(SupabaseConfig.idColumn, created.id);
              print('✅ Top-5 email sent successfully to ${created.email}');
            } else {
              print('⚠️ Top-5 email failed to send to ${created.email}');
            }
          } else {
            print('📧 Top-5 email already sent to ${created.email}');
          }
        }
      } catch (emailError) {
        print('❌ Error sending top-5 email: $emailError');
      }

      return created;
    } catch (e) {
      print('❌ Error adding queue entry: $e');
      
      // Provide more context about the error
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Failed host lookup')) {
        print('💡 Network Error: Cannot reach Supabase server');
        print('   Check internet connection and Supabase URL configuration');
      } else if (e.toString().contains('ClientException')) {
        print('💡 Client Error: HTTP request failed');
        print('   This usually indicates a network connectivity issue');
      }
      
      return null;
    }
  }

  Future<bool> updateQueueEntryStatus(String id, String status) async {
    try {
      await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .update({SupabaseConfig.statusColumn: status})
          .eq(SupabaseConfig.idColumn, id);
      
      return true;
    } catch (e) {
      print('Error updating queue entry status: $e');
      return false;
    }
  }

  // Start countdown for a queue entry
  Future<bool> startCountdown(String id) async {
    try {
      // Get the entry details before starting countdown
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.idColumn, id)
          .single();
      
      final entry = QueueEntry.fromJson(response);
      
      // Update status and start countdown
      await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .update({
            // Store UTC so client-side UTC math yields correct 30s
            SupabaseConfig.countdownStartColumn: DateTime.now()
                .toUtc()
                .toIso8601String(),
            SupabaseConfig.statusColumn: SupabaseConfig.statusServing,
            SupabaseConfig.countdownDurationColumn: 30,
          })
          .eq(SupabaseConfig.idColumn, id);
      
      // Announce that user is being called
      try {
        final ttsService = TtsService();
        await ttsService.speak('${entry.name}, queue number ${entry.queueNumber}, please proceed to the ${entry.department} counter.');
      } catch (ttsError) {
        print('TTS announcement failed: $ttsError');
      }
      
      return true;
    } catch (e) {
      print('Error starting countdown: $e');
      return false;
    }
  }

  // Stop countdown and mark as completed
  Future<bool> stopCountdown(String id) async {
    try {
      await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .update({
            SupabaseConfig.countdownStartColumn: null,
            SupabaseConfig.statusColumn: SupabaseConfig.statusCompleted,
          })
          .eq(SupabaseConfig.idColumn, id);

      return true;
    } catch (e) {
      print('Error stopping countdown: $e');
      return false;
    }
  }

  // Mark as missed (countdown expired)
  Future<bool> markAsMissed(String id) async {
    try {
      await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .update({
            SupabaseConfig.countdownStartColumn: null,
            SupabaseConfig.statusColumn: SupabaseConfig.statusMissed,
            SupabaseConfig.countdownDurationColumn: 30,
          })
          .eq(SupabaseConfig.idColumn, id);
      return true;
    } catch (e) {
      print('Error marking as missed: $e');
      return false;
    }
  }

  Future<bool> removeQueueEntry(String id) async {
    try {
      await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .delete()
          .eq(SupabaseConfig.idColumn, id);
      return true;
    } catch (e) {
      print('Error removing queue entry: $e');
      return false;
    }
  }

  Future<QueueEntry?> getNextPersonInQueue(String department) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, department)
          .eq(SupabaseConfig.statusColumn, SupabaseConfig.statusWaiting)
          .order(
            SupabaseConfig.queueNumberColumn,
          ) // FCFS: First Come, First Serve
          .limit(1)
          .single();

      return QueueEntry.fromJson(response);
    } catch (e) {
      print('Error getting next person: $e');
      return null;
    }
  }

  // Get the currently serving person for a department, if any
  Future<QueueEntry?> getCurrentServingPerson(String department) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, department)
          .eq(SupabaseConfig.statusColumn, SupabaseConfig.statusServing)
          .order(SupabaseConfig.countdownStartColumn)
          .limit(1)
          .single();

      return QueueEntry.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Get all waiting people in queue for a department (ordered by FCFS)
  Future<List<QueueEntry>> getWaitingQueueForDepartment(
    String department,
  ) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, department)
          .eq(SupabaseConfig.statusColumn, SupabaseConfig.statusWaiting)
          .order(
            SupabaseConfig.queueNumberColumn,
          ); // FCFS: First Come, First Serve

      return response.map((json) => QueueEntry.fromJson(json)).toList();
    } catch (e) {
      print('Error getting waiting queue for department: $e');
      return [];
    }
  }

  // Check and handle expired countdowns - automatically mark as completed and remove
  Future<void> checkExpiredCountdowns() async {
    try {
      final now = DateTime.now().toUtc();
      final thirtySecondsAgo = now.subtract(const Duration(seconds: 30));

      // Find all serving entries with expired countdowns
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.statusColumn, SupabaseConfig.statusServing)
          .lt(
            SupabaseConfig.countdownStartColumn,
            thirtySecondsAgo.toIso8601String(),
          );

      for (final entry in response) {
        final entryId = entry[SupabaseConfig.idColumn];
        final queueNumber = entry[SupabaseConfig.queueNumberColumn];
        final department = entry[SupabaseConfig.departmentColumn];

        // First mark as missed for tracking
        await markAsMissed(entryId);
        print(
          'Auto-marked expired countdown for entry: $entryId (Queue #$queueNumber, $department)',
        );

        // Then automatically mark as completed after a short delay
        await Future.delayed(const Duration(seconds: 2));
        await completeQueueEntry(entryId);
        print(
          'Auto-completed missed entry: $entryId (Queue #$queueNumber, $department)',
        );
      }
    } catch (e) {
      print('Error checking expired countdowns: $e');
    }
  }

  // Clean up old completed/missed entries (keep only recent history)
  Future<void> cleanupOldEntries() async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));

      // Delete old completed and missed entries
      await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .delete()
          .or(
            '${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusCompleted},${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusMissed}',
          )
          .lt(SupabaseConfig.timestampColumn, oneDayAgo.toIso8601String());

      print('Cleaned up old completed/missed entries');
    } catch (e) {
      print('Error cleaning up old entries: $e');
    }
  }

  // Immediately remove missed entries from live queue
  Future<void> removeMissedEntriesFromLiveQueue() async {
    try {
      // Get all missed entries
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.statusColumn, SupabaseConfig.statusMissed);

      for (final entry in response) {
        final entryId = entry[SupabaseConfig.idColumn];
        final queueNumber = entry[SupabaseConfig.queueNumberColumn];
        final department = entry[SupabaseConfig.departmentColumn];

        // Mark as completed to remove from live queue
        await completeQueueEntry(entryId);
        print(
          'Removed missed entry from live queue: $entryId (Queue #$queueNumber, $department)',
        );
      }
    } catch (e) {
      print('Error removing missed entries from live queue: $e');
    }
  }

  Future<bool> finishServing(String department) async {
    try {
      final nextPerson = await getNextPersonInQueue(department);
      if (nextPerson != null) {
        return await updateQueueEntryStatus(
          nextPerson.id,
          SupabaseConfig.statusCompleted,
        );
      }
      return false;
    } catch (e) {
      print('Error finishing serving: $e');
      return false;
    }
  }

  // Complete a specific queue entry
  Future<bool> completeQueueEntry(String entryId) async {
    try {
      // Get the entry details before completing
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.idColumn, entryId)
          .single();
      
      final entry = QueueEntry.fromJson(response);
      
      // Update status to completed
      final success = await updateQueueEntryStatus(
        entryId,
        SupabaseConfig.statusCompleted,
      );
      
      if (success) {
        // Announce completion via TTS
        try {
          final ttsService = TtsService();
          await ttsService.announceQueueCompletion(entry.name, entry.department);
        } catch (ttsError) {
          print('TTS announcement failed: $ttsError');
        }
      }
      
      return success;
    } catch (e) {
      print('Error completing queue entry: $e');
      return false;
    }
  }

  // Get recent history (completed or missed) for a department
  // Get recent history across all departments (for master admin)
  Future<List<QueueEntry>> getRecentHistory({int limit = 10}) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.statusColumn, SupabaseConfig.statusCompleted)
          .order(SupabaseConfig.timestampColumn, ascending: false)
          .limit(limit);

      return response.map((json) => QueueEntry.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching recent history: $e');
      return [];
    }
  }

  Future<List<QueueEntry>> getRecentHistoryForDepartment(
    String department, {
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, department)
          .or(
            '${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusCompleted},${SupabaseConfig.statusColumn}.eq.${SupabaseConfig.statusMissed}',
          )
          .order(SupabaseConfig.timestampColumn, ascending: false)
          .limit(limit);

      return response.map((json) => QueueEntry.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching recent history: $e');
      return [];
    }
  }

  Future<Map<String, int>> getQueueStatistics() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select(
            '${SupabaseConfig.departmentColumn}, ${SupabaseConfig.statusColumn}',
          )
          .eq(SupabaseConfig.statusColumn, SupabaseConfig.statusWaiting);

      final Map<String, int> stats = {};
      for (final entry in response) {
        final dept = entry[SupabaseConfig.departmentColumn];
        if (dept != null) {
          stats[dept] = (stats[dept] ?? 0) + 1;
        }
      }
      return stats;
    } catch (e) {
      print('Error getting queue statistics: $e');
      return {};
    }
  }

  // Get detailed queue statistics for a specific department
  Future<Map<String, dynamic>> getDepartmentQueueStatistics(
    String department,
  ) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select()
          .eq(SupabaseConfig.departmentColumn, department);

      final Map<String, int> statusCounts = {};
      int totalWaiting = 0;
      int totalServing = 0;
      int totalCompleted = 0;
      int totalMissed = 0;

      for (final entry in response) {
        final status = entry[SupabaseConfig.statusColumn];
        if (status != null) {
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;

          switch (status) {
            case 'waiting':
              totalWaiting++;
              break;
            case 'serving':
              totalServing++;
              break;
            case 'completed':
              totalCompleted++;
              break;
            case 'missed':
              totalMissed++;
              break;
          }
        }
      }

      return {
        'department': department,
        'total_entries': response.length,
        'waiting': totalWaiting,
        'serving': totalServing,
        'completed': totalCompleted,
        'missed': totalMissed,
        'next_queue_number': await _getNextQueueNumberForDepartment(department),
      };
    } catch (e) {
      print('Error getting department queue statistics: $e');
      return {
        'department': department,
        'total_entries': 0,
        'waiting': 0,
        'serving': 0,
        'completed': 0,
        'missed': 0,
        'next_queue_number': 1,
      };
    }
  }

  // Reset queue with purpose-based functionality
  Future<bool> resetQueue({String? purpose, String? department}) async {
    try {
      print('Resetting queue - Purpose: $purpose, Department: $department');

      if (department != null) {
        // Reset specific department only
        await _supabase
            .from(SupabaseConfig.queueEntriesTable)
            .delete()
            .eq(SupabaseConfig.departmentColumn, department);
        print('Reset completed for department: $department');
      } else {
        // Reset all departments
        await _supabase
            .from(SupabaseConfig.queueEntriesTable)
            .delete()
            .neq(SupabaseConfig.idColumn, '');
        print('Reset completed for all departments');
      }

      return true;
    } catch (e) {
      print('Error resetting queue: $e');
      return false;
    }
  }

  // Reset queue with different purposes and update graphs accordingly
  Future<Map<String, dynamic>> resetQueueWithPurpose({
    required String purpose,
    String? department,
    bool resetGraphs = true,
  }) async {
    try {
      print('Resetting queue with purpose: $purpose');

      // Get current statistics before reset
      final beforeStats = department != null
          ? await getDepartmentQueueStatistics(department)
          : await getQueueStatistics();

      // Perform the reset
      final resetSuccess = await resetQueue(
        purpose: purpose,
        department: department,
      );

      if (!resetSuccess) {
        throw Exception('Failed to reset queue');
      }

      // Get statistics after reset
      final afterStats = department != null
          ? await getDepartmentQueueStatistics(department)
          : await getQueueStatistics();

      // Prepare response based on purpose
      Map<String, dynamic> response = {
        'success': true,
        'purpose': purpose,
        'department': department,
        'before_stats': beforeStats,
        'after_stats': afterStats,
        'message': _getResetMessage(purpose, department),
        'graphs_reset': resetGraphs,
      };

      // Add purpose-specific data
      switch (purpose.toLowerCase()) {
        case 'daily':
          response['reset_type'] = 'Daily queue reset';
          response['next_queue_start'] = 1;
          break;
        case 'weekly':
          response['reset_type'] = 'Weekly queue reset';
          response['next_queue_start'] = 1;
          break;
        case 'monthly':
          response['reset_type'] = 'Monthly queue reset';
          response['next_queue_start'] = 1;
          break;
        case 'emergency':
          response['reset_type'] = 'Emergency queue reset';
          response['next_queue_start'] = 1;
          break;
        case 'maintenance':
          response['reset_type'] = 'Maintenance queue reset';
          response['next_queue_start'] = 1;
          break;
        case 'department':
          response['reset_type'] = 'Department-specific reset';
          response['next_queue_start'] = 1;
          break;
        default:
          response['reset_type'] = 'General queue reset';
          response['next_queue_start'] = 1;
      }

      print('Queue reset completed successfully: ${response['message']}');
      return response;
    } catch (e) {
      print('Error in resetQueueWithPurpose: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to reset queue',
      };
    }
  }

  // Get appropriate reset message based on purpose
  String _getResetMessage(String purpose, String? department) {
    final deptText = department != null
        ? ' for $department department'
        : ' for all departments';

    switch (purpose.toLowerCase()) {
      case 'daily':
        return 'Daily queue reset completed$deptText. All queue numbers reset to 001.';
      case 'weekly':
        return 'Weekly queue reset completed$deptText. All queue numbers reset to 001.';
      case 'monthly':
        return 'Monthly queue reset completed$deptText. All queue numbers reset to 001.';
      case 'emergency':
        return 'Emergency queue reset completed$deptText. All queue numbers reset to 001.';
      case 'maintenance':
        return 'Maintenance queue reset completed$deptText. All queue numbers reset to 001.';
      case 'department':
        return 'Department-specific queue reset completed$deptText. All queue numbers reset to 001.';
      default:
        return 'Queue reset completed$deptText. All queue numbers reset to 001.';
    }
  }

  // Reset specific queue entries by status
  Future<bool> resetQueueByStatus(String status, {String? department}) async {
    try {
      print('Resetting queue entries with status: $status');

      if (department != null) {
        await _supabase
            .from(SupabaseConfig.queueEntriesTable)
            .delete()
            .eq(SupabaseConfig.statusColumn, status)
            .eq(SupabaseConfig.departmentColumn, department);
      } else {
        await _supabase
            .from(SupabaseConfig.queueEntriesTable)
            .delete()
            .eq(SupabaseConfig.statusColumn, status);
      }

      print('Reset completed for status: $status');
      return true;
    } catch (e) {
      print('Error resetting queue by status: $e');
      return false;
    }
  }

  // Reset completed entries only (keep waiting and serving)
  Future<bool> resetCompletedEntries({String? department}) async {
    try {
      print('Resetting completed entries only');

      if (department != null) {
        await _supabase
            .from(SupabaseConfig.queueEntriesTable)
            .delete()
            .eq(SupabaseConfig.statusColumn, SupabaseConfig.statusCompleted)
            .eq(SupabaseConfig.departmentColumn, department);
      } else {
        await _supabase
            .from(SupabaseConfig.queueEntriesTable)
            .delete()
            .eq(SupabaseConfig.statusColumn, SupabaseConfig.statusCompleted);
      }

      print('Completed entries reset successful');
      return true;
    } catch (e) {
      print('Error resetting completed entries: $e');
      return false;
    }
  }

  // Admin Users Operations
  Future<AdminUser?> authenticateAdmin(String username, String password) async {
    try {
      print('Attempting to authenticate admin: $username');

      // First, let's check if the table exists and has data
      final tableCheck = await _supabase
          .from(SupabaseConfig.adminUsersTable)
          .select('count')
          .limit(1);

      print('Table check result: $tableCheck');

      // Try to authenticate
      final response = await _supabase
          .from(SupabaseConfig.adminUsersTable)
          .select()
          .eq(SupabaseConfig.usernameColumn, username)
          .eq(SupabaseConfig.passwordColumn, password)
          .single();

      print('Authentication successful for: $username');
      return AdminUser.fromJson(response);
    } catch (e) {
      print('Error authenticating admin: $e');

      // Try to get more details about the error
      try {
        final allUsers = await _supabase
            .from(SupabaseConfig.adminUsersTable)
            .select()
            .limit(5);
        print('Available users in database: $allUsers');
      } catch (debugError) {
        print('Debug error: $debugError');
      }

      return null;
    }
  }

  Future<bool> createAdminUser(AdminUser adminUser) async {
    try {
      await _supabase
          .from(SupabaseConfig.adminUsersTable)
          .insert(adminUser.toJson());
      return true;
    } catch (e) {
      print('Error creating admin user: $e');
      return false;
    }
  }

  Future<List<AdminUser>> getAllAdminUsers() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.adminUsersTable)
          .select()
          .order(SupabaseConfig.createdAtColumn);

      return response.map((json) => AdminUser.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching admin users: $e');
      return [];
    }
  }

  // Helper method to get next queue number for a specific department
  Future<int> _getNextQueueNumberForDepartment(String department) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select(SupabaseConfig.queueNumberColumn)
          .eq(SupabaseConfig.departmentColumn, department)
          .order(SupabaseConfig.queueNumberColumn, ascending: false)
          .limit(1)
          .single();

      // response is a Map<String, dynamic>
      final queueNumber = response[SupabaseConfig.queueNumberColumn];
      if (queueNumber != null) {
        return (queueNumber as int) + 1;
      }
      return 1; // Start from 1 if no entries exist for this department
    } catch (e) {
      return 1; // Start from 1 if no entries exist for this department
    }
  }

  // Note: Priority queue logic removed - we now use display sorting instead of changing queue numbers
  // PWD and Senior entries keep their original queue numbers but are displayed first

  // (Removed global numbering helper to keep per-department sequencing)

  // Get current queue number for a specific department
  Future<int> getCurrentQueueNumberForDepartment(String department) async {
    return await _getNextQueueNumberForDepartment(department);
  }

  // Get current queue number (deprecated - use getCurrentQueueNumberForDepartment instead)
  Future<int> getCurrentQueueNumber() async {
    // This method is kept for backward compatibility
    // It will return the next number for the first department found
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select(SupabaseConfig.departmentColumn)
          .limit(1)
          .single();

      final dept = response[SupabaseConfig.departmentColumn];
      if (dept != null) {
        return await _getNextQueueNumberForDepartment(dept);
      }
      return 1;
    } catch (e) {
      return 1;
    }
  }

  // Get total queue count
  Future<int> getTotalQueueCount() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.queueEntriesTable)
          .select();

      return response.length;
    } catch (e) {
      print('❌ Error getting total count: $e');
      
      // Provide more context about the error
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Failed host lookup')) {
        print('💡 Network Error: Cannot reach Supabase server');
      } else if (e.toString().contains('ClientException')) {
        print('💡 Client Error: HTTP request failed');
      }
      
      // Rethrow to let calling code handle it
      rethrow;
    }
  }

  // Check if queue is full (assuming max 500)
  Future<bool> isQueueFull() async {
    try {
      final count = await getTotalQueueCount();
      return count >= 500;
    } catch (e) {
      // If we can't check the count due to network error, rethrow
      // This allows the UI to show a proper error message
      rethrow;
    }
  }

  // Get available queue numbers
  Future<int> getAvailableQueueNumbers() async {
    final count = await getTotalQueueCount();
    return 500 - count;
  }

  // Get graph data for charts after reset
  Future<Map<String, dynamic>> getGraphDataAfterReset({
    String? department,
    String? resetPurpose,
  }) async {
    try {
      print(
        'Getting graph data after reset - Purpose: $resetPurpose, Department: $department',
      );

      // Get current statistics
      final currentStats = department != null
          ? await getDepartmentQueueStatistics(department)
          : await getQueueStatistics();

      // Prepare graph data
      Map<String, dynamic> graphData = {
        'timestamp': DateTime.now().toIso8601String(),
        'reset_purpose': resetPurpose ?? 'general',
        'department': department ?? 'all',
        'queue_status': {
          'waiting': currentStats['waiting'] ?? 0,
          'serving': currentStats['serving'] ?? 0,
          'completed': currentStats['completed'] ?? 0,
          'missed': currentStats['missed'] ?? 0,
        },
        'total_entries': currentStats['total_entries'] ?? 0,
        'next_queue_number': currentStats['next_queue_number'] ?? 1,
      };

      // Add department-specific data if applicable
      if (department != null) {
        graphData['department_specific'] = true;
        graphData['department_name'] = department;
      }

      // Add reset-specific metadata
      switch (resetPurpose?.toLowerCase()) {
        case 'daily':
          graphData['reset_category'] = 'routine';
          graphData['reset_frequency'] = 'daily';
          break;
        case 'weekly':
          graphData['reset_category'] = 'routine';
          graphData['reset_frequency'] = 'weekly';
          break;
        case 'monthly':
          graphData['reset_category'] = 'routine';
          graphData['reset_frequency'] = 'monthly';
          break;
        case 'emergency':
          graphData['reset_category'] = 'emergency';
          graphData['reset_frequency'] = 'as_needed';
          break;
        case 'maintenance':
          graphData['reset_category'] = 'maintenance';
          graphData['reset_frequency'] = 'as_needed';
          break;
        default:
          graphData['reset_category'] = 'general';
          graphData['reset_frequency'] = 'manual';
      }

      print('Graph data prepared successfully');
      return graphData;
    } catch (e) {
      print('Error getting graph data after reset: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'reset_purpose': resetPurpose ?? 'general',
        'department': department ?? 'all',
      };
    }
  }

  // Reset and get fresh graph data
  Future<Map<String, dynamic>> resetAndGetFreshGraphData({
    required String purpose,
    String? department,
  }) async {
    try {
      print('Performing reset and getting fresh graph data');

      // Perform the reset
      final resetResult = await resetQueueWithPurpose(
        purpose: purpose,
        department: department,
        resetGraphs: true,
      );

      if (!resetResult['success']) {
        throw Exception(resetResult['message']);
      }

      // Get fresh graph data
      final freshGraphData = await getGraphDataAfterReset(
        department: department,
        resetPurpose: purpose,
      );

      // Combine reset result with fresh graph data
      final combinedResult = {
        ...resetResult,
        'fresh_graph_data': freshGraphData,
        'graphs_updated': true,
        'reset_timestamp': DateTime.now().toIso8601String(),
      };

      print('Reset and graph update completed successfully');
      return combinedResult;
    } catch (e) {
      print('Error in resetAndGetFreshGraphData: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to reset and update graphs',
        'graphs_updated': false,
      };
    }
  }

  // Department Operations
  // Get all departments from database
  Future<List<Department>> getAllDepartments() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.departmentsTable)
          .select()
          .order('code', ascending: true);
      
      return response.map((json) => Department.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching departments: $e');
      return [];
    }
  }

  // Get active departments only
  Future<List<Department>> getActiveDepartments() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.departmentsTable)
          .select()
          .eq('is_active', true)
          .order('code', ascending: true);
      
      return response.map((json) => Department.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching active departments: $e');
      return [];
    }
  }

  // Get department by code
  Future<Department?> getDepartmentByCode(String code) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.departmentsTable)
          .select()
          .eq('code', code)
          .single();
      
      return Department.fromJson(response);
    } catch (e) {
      print('Error fetching department by code: $e');
      return null;
    }
  }

  // Add new department
  Future<Department?> addDepartment({
    required String code,
    required String name,
    required String description,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.departmentsTable)
          .insert({
            'code': code.toUpperCase(),
            'name': name,
            'description': description,
            'is_active': true,
          })
          .select()
          .single();
      
      return Department.fromJson(response);
    } catch (e) {
      print('Error adding department: $e');
      rethrow;
    }
  }

  // Update department
  Future<bool> updateDepartment({
    required String id,
    String? code,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      
      if (code != null) updateData['code'] = code.toUpperCase();
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (isActive != null) updateData['is_active'] = isActive;
      
      // updated_at will be automatically updated by trigger
      
      await _supabase
          .from(SupabaseConfig.departmentsTable)
          .update(updateData)
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error updating department: $e');
      rethrow;
    }
  }

  // Delete department (soft delete by setting isActive to false)
  Future<bool> deleteDepartment(String id) async {
    try {
      await _supabase
          .from(SupabaseConfig.departmentsTable)
          .update({'is_active': false})
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error deleting department: $e');
      rethrow;
    }
  }

  // Permanently remove department
  Future<bool> removeDepartment(String id) async {
    try {
      await _supabase
          .from(SupabaseConfig.departmentsTable)
          .delete()
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error permanently removing department: $e');
      rethrow;
    }
  }

  // Purpose Operations
  // Get all purposes from database
  Future<List<Purpose>> getAllPurposes() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.purposesTable)
          .select()
          .order('name', ascending: true);
      
      return response.map((json) => Purpose.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching purposes: $e');
      return [];
    }
  }

  // Get active purposes only
  Future<List<Purpose>> getActivePurposes() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.purposesTable)
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);
      
      return response.map((json) => Purpose.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching active purposes: $e');
      return [];
    }
  }

  // Get purpose by name
  Future<Purpose?> getPurposeByName(String name) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.purposesTable)
          .select()
          .eq('name', name)
          .single();
      
      return Purpose.fromJson(response);
    } catch (e) {
      print('Error fetching purpose by name: $e');
      return null;
    }
  }

  // Add new purpose
  Future<Purpose?> addPurpose({
    required String name,
    required String description,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.purposesTable)
          .insert({
            'name': name.toUpperCase(),
            'description': description,
            'is_active': true,
          })
          .select()
          .single();
      
      return Purpose.fromJson(response);
    } catch (e) {
      print('Error adding purpose: $e');
      rethrow;
    }
  }

  // Update purpose
  Future<bool> updatePurpose({
    required String id,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      
      if (name != null) updateData['name'] = name.toUpperCase();
      if (description != null) updateData['description'] = description;
      if (isActive != null) updateData['is_active'] = isActive;
      
      // updated_at will be automatically updated by trigger
      
      await _supabase
          .from(SupabaseConfig.purposesTable)
          .update(updateData)
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error updating purpose: $e');
      rethrow;
    }
  }

  // Delete purpose (soft delete by setting isActive to false)
  Future<bool> deletePurpose(String id) async {
    try {
      await _supabase
          .from(SupabaseConfig.purposesTable)
          .update({'is_active': false})
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error deleting purpose: $e');
      rethrow;
    }
  }

  // Permanently remove purpose
  Future<bool> removePurpose(String id) async {
    try {
      await _supabase
          .from(SupabaseConfig.purposesTable)
          .delete()
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error permanently removing purpose: $e');
      rethrow;
    }
  }

  // Course Operations
  // Get all courses from database
  Future<List<Course>> getAllCourses() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.coursesTable)
          .select()
          .order('code', ascending: true);
      
      return response.map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching courses: $e');
      return [];
    }
  }

  // Get active courses only
  Future<List<Course>> getActiveCourses() async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.coursesTable)
          .select()
          .eq('is_active', true)
          .order('code', ascending: true);
      
      return response.map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching active courses: $e');
      return [];
    }
  }

  // Get courses by department
  Future<List<Course>> getCoursesByDepartment(String departmentCode) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.coursesTable)
          .select()
          .eq('department_code', departmentCode)
          .eq('is_active', true)
          .order('code', ascending: true);
      
      return response.map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching courses by department: $e');
      return [];
    }
  }

  // Get course by code
  Future<Course?> getCourseByCode(String code) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.coursesTable)
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .limit(1);
      
      if (response.isEmpty) return null;
      return Course.fromJson(response.first);
    } catch (e) {
      print('Error fetching course by code: $e');
      return null;
    }
  }

  // Add new course
  Future<Course?> addCourse({
    required String code,
    required String name,
    required String departmentCode,
    required String description,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.coursesTable)
          .insert({
            'code': code.toUpperCase(),
            'name': name,
            'department_code': departmentCode,
            'description': description,
            'is_active': true,
          })
          .select()
          .single();
      
      return Course.fromJson(response);
    } catch (e) {
      print('Error adding course: $e');
      rethrow;
    }
  }

  // Update course
  Future<bool> updateCourse({
    required String id,
    String? code,
    String? name,
    String? departmentCode,
    String? description,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      
      if (code != null) updateData['code'] = code.toUpperCase();
      if (name != null) updateData['name'] = name;
      if (departmentCode != null) updateData['department_code'] = departmentCode;
      if (description != null) updateData['description'] = description;
      if (isActive != null) updateData['is_active'] = isActive;
      
      // updated_at will be automatically updated by trigger
      
      await _supabase
          .from(SupabaseConfig.coursesTable)
          .update(updateData)
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error updating course: $e');
      rethrow;
    }
  }

  // Delete course (soft delete by setting isActive to false)
  Future<bool> deleteCourse(String id) async {
    try {
      await _supabase
          .from(SupabaseConfig.coursesTable)
          .update({'is_active': false})
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error deleting course: $e');
      rethrow;
    }
  }

  // Permanently remove course
  Future<bool> removeCourse(String id) async {
    try {
      await _supabase
          .from(SupabaseConfig.coursesTable)
          .delete()
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error permanently removing course: $e');
      rethrow;
    }
  }
}
