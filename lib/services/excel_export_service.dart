import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/queue_entry.dart';
import '../services/supabase_service.dart';
import '../services/department_service.dart';

class ExcelExportService {
  final SupabaseService _supabaseService = SupabaseService();
  final DepartmentService _departmentService = DepartmentService();

  /// Test method to check database connection and records
  Future<void> testDatabaseConnection() async {
    try {
      print('Testing database connection...');
      final allEntries = await _supabaseService.getAllQueueEntries();
      print('Database test: Found ${allEntries.length} records');

      if (allEntries.isNotEmpty) {
        print('Database test: Sample records:');
        for (int i = 0; i < allEntries.length && i < 3; i++) {
          final entry = allEntries[i];
          print(
            '  - ${entry.name} (${entry.department}) - Status: ${entry.status}',
          );
        }
      } else {
        print('Database test: No records found in queue_entries table');
      }
    } catch (e) {
      print('Database test error: $e');
    }
  }

  /// Test method to create a simple Excel file
  Future<void> testExcelCreation() async {
    try {
      print('Testing Excel creation...');

      // Create a simple Excel file
      final excel = Excel.createExcel();
      final sheet = excel['Test Sheet'];

      // Add headers using appendRow
      sheet.appendRow([
        TextCellValue('Name'),
        TextCellValue('Value'),
        TextCellValue('Status'),
      ]);

      // Add test data using appendRow
      sheet.appendRow([
        TextCellValue('Test User 1'),
        TextCellValue('100'),
        TextCellValue('Active'),
      ]);

      sheet.appendRow([
        TextCellValue('Test User 2'),
        TextCellValue('200'),
        TextCellValue('Inactive'),
      ]);

      sheet.appendRow([
        TextCellValue('Test User 3'),
        TextCellValue('300'),
        TextCellValue('Pending'),
      ]);

      print('Excel test: Created test Excel with 4 rows (1 header + 3 data)');

      // Save the test file
      final fileName =
          'Excel_Test_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final result = await _saveExcelFile(excel, fileName);

      if (result != null) {
        print('Excel test: Successfully saved test file to: $result');
      } else {
        print('Excel test: Failed to save test file');
      }
    } catch (e) {
      print('Excel test error: $e');
    }
  }

  /// Export all queue records to Excel file
  Future<String?> exportAllRecords() async {
    try {
      // Get all queue entries
      final allEntries = await _supabaseService.getAllQueueEntries();

      print('Excel Export: Found ${allEntries.length} records');
      if (allEntries.isNotEmpty) {
        print(
          'Excel Export: First record: ${allEntries.first.name} - ${allEntries.first.department}',
        );
      }

      if (allEntries.isEmpty) {
        throw Exception('No records found to export');
      }

      // Create Excel file (ensure the target sheet is the default and remove empty default sheet)
      final excel = Excel.createExcel();
      final sheet = _createTargetSheet(excel, 'Queue Records');

      print('Excel Export: Created Excel file and set default sheet to "${sheet.sheetName}"');

      // Add headers
      _addHeaders(sheet);
      print('Excel Export: Added headers to sheet');

      // Add data rows using appendRow method
      for (final entry in allEntries) {
        print('Excel Export: Adding row for ${entry.name}');
        _addDataRow(sheet, entry);
      }

      print('Excel Export: Added ${allEntries.length} data rows');

      // Auto-size columns
      _autoSizeColumns(sheet);
      print('Excel Export: Auto-sized columns');

      // Save file
      final fileName =
          'Queue_Records_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      return await _saveExcelFile(excel, fileName);
    } catch (e) {
      print('Error exporting records: $e');
      return null;
    }
  }

  /// Export records for a specific department
  Future<String?> exportDepartmentRecords(String department) async {
    try {
      // Get department entries
      final entries = await _supabaseService.getQueueEntriesByDepartment(
        department,
      );

      print(
        'Excel Export: Found ${entries.length} records for department $department',
      );
      if (entries.isNotEmpty) {
        print(
          'Excel Export: First record: ${entries.first.name} - ${entries.first.department}',
        );
      }

      if (entries.isEmpty) {
        throw Exception('No records found for department $department');
      }

      // Create Excel file (ensure the target sheet is the default and remove empty default sheet)
      final excel = Excel.createExcel();
      final sheet = _createTargetSheet(excel, '${department}_Records');

      // Add headers
      _addHeaders(sheet);

      // Add data rows
      for (final entry in entries) {
        _addDataRow(sheet, entry);
      }

      // Auto-size columns
      _autoSizeColumns(sheet);

      // Save file
      final departmentName =
          _departmentService.getDepartmentByCode(department)?.name ??
          department;
      final fileName =
          '${departmentName}_Records_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      return await _saveExcelFile(excel, fileName);
    } catch (e) {
      print('Error exporting department records: $e');
      return null;
    }
  }

  /// Export filtered records based on multiple criteria
  Future<String?> exportFilteredRecords({
    String? department,
    String? purpose,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? priority,
    String? searchQuery,
  }) async {
    try {
      // Get all entries first
      List<QueueEntry> entries = await _supabaseService.getAllQueueEntries();

      print('Excel Export: Starting with ${entries.length} total records');

      // Apply filters
      entries = entries.where((entry) {
        // Department filter
        if (department != null && entry.department != department) {
          return false;
        }

        // Purpose filter
        if (purpose != null && entry.purpose != purpose) {
          return false;
        }

        // Status filter
        if (status != null && entry.status != status) {
          return false;
        }

        // Priority filter
        if (priority != null) {
          switch (priority) {
            case 'priority':
              if (!entry.isPriority) return false;
              break;
            case 'pwd':
              if (!entry.isPwd) return false;
              break;
            case 'senior':
              if (!entry.isSenior) return false;
              break;
            case 'regular':
              if (entry.isPriority) return false;
              break;
          }
        }

        // Date range filter
        if (startDate != null || endDate != null) {
          final entryDate = entry.timestamp;
          if (startDate != null && entryDate.isBefore(startDate)) {
            return false;
          }
          if (endDate != null) {
            final endOfDay = DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
              23,
              59,
              59,
            );
            if (entryDate.isAfter(endOfDay)) {
              return false;
            }
          }
        }

        // Search filter
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          if (!entry.name.toLowerCase().contains(query) &&
              !entry.email.toLowerCase().contains(query) &&
              !entry.phoneNumber.contains(query) &&
              !entry.queueNumber.toString().contains(query)) {
            return false;
          }
        }

        return true;
      }).toList();

      print('Excel Export: After filtering, ${entries.length} records remain');

      if (entries.isEmpty) {
        throw Exception('No records match the selected filters');
      }

      // Create Excel file
      final excel = Excel.createExcel();
      
      // Generate sheet name based on filters
      String sheetName = 'Filtered Records';
      if (department != null) {
        final deptName = _departmentService.getDepartmentByCode(department)?.name ?? department;
        sheetName = '${deptName}_Records';
      }
      final sheet = _createTargetSheet(excel, sheetName);

      // Add headers
      _addHeaders(sheet);

      // Add data rows
      for (final entry in entries) {
        _addDataRow(sheet, entry);
      }

      // Auto-size columns
      _autoSizeColumns(sheet);

      // Generate filename based on filters
      String fileName = 'Queue_Records';
      if (department != null) {
        final deptName = _departmentService.getDepartmentByCode(department)?.name ?? department;
        fileName = '${deptName}_Records';
      }
      if (purpose != null) {
        fileName += '_$purpose';
      }
      if (startDate != null || endDate != null) {
        final startStr = startDate != null
            ? '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}'
            : '';
        final endStr = endDate != null
            ? '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}'
            : '';
        fileName += '_${startStr}_to_$endStr';
      }
      fileName += '_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      return await _saveExcelFile(excel, fileName);
    } catch (e) {
      print('Error exporting filtered records: $e');
      return null;
    }
  }

  /// Add headers to the Excel sheet
  void _addHeaders(Sheet sheet) {
    final headers = [
      'Reference Number',
      'Queue Number',
      'SSU ID',
      'Name',
      'Email',
      'Phone Number',
      'Age',
      'Gender',
      'Department',
      'Department Name',
      'Course',
      'Purpose',
      'Student Type',
      'Graduation Year',
      'Priority Type',
      'Status',
      'Created At',
      'Updated At',
      'Countdown Duration',
      'Is PWD',
      'Is Senior',
      'Is Pregnant',
      'Is Priority',
    ];

    // Use appendRow for headers to ensure proper row tracking
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    
    // Apply styling to header row
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );
    }
    
    print('Excel Export: Added ${headers.length} headers: ${headers.join(', ')}');
  }

  /// Add data row to the Excel sheet
  void _addDataRow(Sheet sheet, QueueEntry entry) {
    final departmentName =
        _departmentService.getDepartmentByCode(entry.department)?.name ??
        entry.department;

    final rowData = [
      entry.referenceNumber ?? 'N/A',
      entry.queueNumber.toString().padLeft(3, '0'),
      entry.ssuId, // ssuId is required, so no null check needed
      entry.name,
      entry.email,
      entry.phoneNumber,
      entry.age?.toString() ?? 'N/A',
      entry.gender ?? 'N/A',
      entry.department,
      departmentName,
      entry.course ?? 'N/A',
      entry.purpose,
      entry.studentType,
      entry.graduationYear != null 
          ? entry.graduationYear.toString() 
          : (entry.studentType == 'Graduated' ? 'N/A' : ''),
      entry.priorityType,
      entry.status.toUpperCase(),
      _formatDateTime(entry.timestamp),
      _formatDateTime(entry.timestamp),
      '${entry.countdownDuration}s',
      entry.isPwd ? 'Yes' : 'No',
      entry.isSenior ? 'Yes' : 'No',
      entry.isPregnant ? 'Yes' : 'No',
      entry.isPriority ? 'Yes' : 'No',
    ];
    
    print('Excel Export: Row data for ${entry.name} - Age: ${entry.age}, Gender: ${entry.gender}, Graduation Year: ${entry.graduationYear}, Course: ${entry.course}, Is Pregnant: ${entry.isPregnant}');
    print('Excel Export: Full row data (${rowData.length} columns): ${rowData.join(' | ')}');

    // Use appendRow method which is more reliable for data rows
    try {
      final cellValues = rowData.map((data) => TextCellValue(data.toString())).toList();
      sheet.appendRow(cellValues);
      print('Excel Export: Successfully appended row for ${entry.name} with ${cellValues.length} cells');
      
      // Verify the row was added
      final lastRowIndex = sheet.maxRows - 1;
      if (lastRowIndex >= 0 && lastRowIndex < sheet.rows.length) {
        final lastRow = sheet.rows[lastRowIndex];
        print('Excel Export: Verified row $lastRowIndex has ${lastRow.length} cells');
        // Print first few cells to verify data
        final sampleCells = lastRow.take(5).map((c) => c?.value?.toString() ?? 'null').join(', ');
        print('Excel Export: Sample cells from row: $sampleCells');
      }
    } catch (e, stackTrace) {
      print('Excel Export: Error appending row for ${entry.name}: $e');
      print('Excel Export: Stack trace: $stackTrace');
      // Fallback: try direct cell assignment
      final currentRow = sheet.maxRows;
      for (int i = 0; i < rowData.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow),
        );
        cell.value = TextCellValue(rowData[i].toString());
      }
      print('Excel Export: Used fallback method for ${entry.name}');
    }
  }

  /// Auto-size columns for better readability
  void _autoSizeColumns(Sheet sheet) {
    // Set default width for all columns
    for (int i = 0; i < 23; i++) {
      sheet.setColumnWidth(i, 15);
    }

    // Set specific widths for certain columns
    sheet.setColumnWidth(0, 20); // Reference Number
    sheet.setColumnWidth(1, 15); // Queue Number
    sheet.setColumnWidth(2, 15); // SSU ID
    sheet.setColumnWidth(3, 25); // Name
    sheet.setColumnWidth(4, 30); // Email
    sheet.setColumnWidth(5, 18); // Phone
    sheet.setColumnWidth(6, 10); // Age
    sheet.setColumnWidth(7, 12); // Gender
    sheet.setColumnWidth(8, 15); // Department
    sheet.setColumnWidth(9, 25); // Department Name
    sheet.setColumnWidth(10, 20); // Course
    sheet.setColumnWidth(11, 20); // Purpose
    sheet.setColumnWidth(12, 15); // Student Type
    sheet.setColumnWidth(13, 15); // Graduation Year
    sheet.setColumnWidth(14, 15); // Priority Type
    sheet.setColumnWidth(15, 12); // Status
    sheet.setColumnWidth(16, 20); // Created At
    sheet.setColumnWidth(17, 20); // Updated At
    sheet.setColumnWidth(18, 18); // Countdown Duration
    sheet.setColumnWidth(19, 12); // Is PWD
    sheet.setColumnWidth(20, 12); // Is Senior
    sheet.setColumnWidth(21, 12); // Is Pregnant
    sheet.setColumnWidth(22, 12); // Is Priority
  }

  /// Create or get target sheet, remove default empty sheet, set default sheet
  Sheet _createTargetSheet(Excel excel, String sheetName) {
    // Remove the default "Sheet1" if it exists and is empty to avoid saving a blank sheet
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    return sheet;
  }

  /// Format DateTime for Excel display
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Save Excel file and return the file path
  Future<String?> _saveExcelFile(Excel excel, String fileName) async {
    try {
      // Convert Excel to bytes first
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      print('Excel Export: Encoded Excel file, size: ${bytes.length} bytes');

      // Get appropriate directory based on platform
      Directory? directory;
      
      if (Platform.isAndroid) {
        // For Android, use external storage directory
        // This works better for user-accessible files
        try {
          // Try to get external storage directory first
          directory = await getExternalStorageDirectory();
          if (directory != null) {
            // Create a Downloads subfolder for better organization
            final downloadsDir = Directory('${directory.path}/Download');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
            directory = downloadsDir;
            print('Excel Export: Using Android external storage: ${directory.path}');
          }
        } catch (e) {
          print('Excel Export: External storage not available, using app directory: $e');
          // Fallback to application documents directory
          directory = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isWindows) {
        directory = Directory(
          '${Platform.environment['USERPROFILE']}\\Downloads',
        );
      } else if (Platform.isMacOS) {
        directory = Directory('${Platform.environment['HOME']}/Downloads');
      } else if (Platform.isLinux) {
        directory = Directory('${Platform.environment['HOME']}/Downloads');
      } else {
        // Fallback to documents directory for other platforms
        directory = await getApplicationDocumentsDirectory();
      }

      // Ensure directory exists
      if (directory != null && !await directory.exists()) {
        print('Excel Export: Directory does not exist, using app documents directory');
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not determine storage directory');
      }

      final filePath = '${directory.path}/$fileName';
      print('Excel Export: Saving file to: $filePath');
      
      final file = File(filePath);

      // Write file
      await file.writeAsBytes(bytes);
      print('Excel Export: Successfully wrote ${bytes.length} bytes to file');

      // Verify file was created
      if (await file.exists()) {
        final fileSize = await file.length();
        print('Excel Export: File verified - Size: $fileSize bytes');
        print('Excel file saved successfully: $filePath');
        return filePath;
      } else {
        throw Exception('File was not created at expected path');
      }
    } catch (e, stackTrace) {
      print('Error saving Excel file: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get export statistics
  Future<Map<String, int>> getExportStatistics() async {
    try {
      final allEntries = await _supabaseService.getAllQueueEntries();

      print('Statistics: Found ${allEntries.length} total records');
      if (allEntries.isNotEmpty) {
        print(
          'Statistics: Sample record - Name: ${allEntries.first.name}, Status: ${allEntries.first.status}, Department: ${allEntries.first.department}',
        );
      }

      int totalRecords = allEntries.length;
      int priorityRecords = allEntries.where((e) => e.isPriority).length;
      int pwdRecords = allEntries.where((e) => e.isPwd).length;
      int seniorRecords = allEntries.where((e) => e.isSenior).length;
      int completedRecords = allEntries
          .where((e) => e.status == 'completed')
          .length;
      int waitingRecords = allEntries
          .where((e) => e.status == 'waiting')
          .length;
      int missedRecords = allEntries.where((e) => e.status == 'missed').length;

      return {
        'total': totalRecords,
        'priority': priorityRecords,
        'pwd': pwdRecords,
        'senior': seniorRecords,
        'completed': completedRecords,
        'waiting': waitingRecords,
        'missed': missedRecords,
      };
    } catch (e) {
      print('Error getting export statistics: $e');
      return {};
    }
  }
}
