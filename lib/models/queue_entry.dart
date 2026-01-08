class QueueEntry {
  final String id;
  final String name;
  final String ssuId;
  final String email;
  final String phoneNumber;
  final String department; // Department code (e.g., 'CAS', 'COED')
  final String purpose;
  final String? course; // Course code (e.g., 'BSIT', 'BSCS')
  final DateTime timestamp;
  final int queueNumber;
  final String status; // Added status field
  final DateTime? countdownStart; // When countdown started
  final int countdownDuration; // Countdown duration in seconds
  final bool isPwd; // Person with Disability
  final bool isSenior; // Senior Citizen
  final bool isPregnant; // Pregnant
  final String studentType; // Student or Graduated
  final String? referenceNumber; // Unique reference number for receipt
  final bool isPriority; // Computed field for priority (PWD, Senior, or Pregnant)
  final String? gender; // Gender (Male, Female, Other, Prefer not to say)
  final int? age; // Age of the person
  final int? graduationYear; // Graduation year (only if studentType = 'Graduated')

  QueueEntry({
    required this.id,
    required this.name,
    required this.ssuId,
    required this.email,
    required this.phoneNumber,
    required this.department,
    required this.purpose,
    this.course,
    required this.timestamp,
    required this.queueNumber,
    this.status = 'waiting', // Default status
    this.countdownStart,
    this.countdownDuration = 30, // 30 seconds default
    this.isPwd = false, // Default not PWD
    this.isSenior = false, // Default not Senior
    this.isPregnant = false, // Default not Pregnant
    this.studentType = 'Student', // Default to Student
    this.referenceNumber,
    this.gender,
    this.age,
    this.graduationYear,
  }) : isPriority = isPwd || isSenior || isPregnant; // Computed priority field

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ssu_id': ssuId,
      'email': email,
      'phone_number': phoneNumber,
      'department': department,
      'purpose': purpose,
      'course': course,
      'timestamp': timestamp.toIso8601String(),
      'queue_number': queueNumber,
      'status': status,
      'countdown_start': countdownStart?.toIso8601String(),
      'countdown_duration': countdownDuration,
      'is_pwd': isPwd,
      'is_senior': isSenior,
      'is_pregnant': isPregnant,
      'student_type': studentType,
      'reference_number': referenceNumber,
      'gender': gender,
      'age': age,
      'graduation_year': graduationYear,
      // Note: is_priority is computed by database trigger, not sent in JSON
    };
  }

  // Create from JSON
  factory QueueEntry.fromJson(Map<String, dynamic> json) {
    return QueueEntry(
      id: json['id'],
      name: json['name'],
      ssuId: json['ssu_id'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      department: json['department'],
      purpose: json['purpose'],
      course: json['course'],
      timestamp: DateTime.parse(json['timestamp']),
      queueNumber: json['queue_number'],
      status: json['status'] ?? 'waiting',
      countdownStart: json['countdown_start'] != null
          ? DateTime.parse(json['countdown_start'])
          : null,
      countdownDuration: json['countdown_duration'] ?? 30,
      isPwd: json['is_pwd'] ?? false,
      isSenior: json['is_senior'] ?? false,
      isPregnant: json['is_pregnant'] ?? false,
      studentType: json['student_type'] ?? 'Student',
      referenceNumber: json['reference_number'],
      gender: json['gender'],
      age: json['age'] != null ? int.tryParse(json['age'].toString()) : null,
      graduationYear: json['graduation_year'] != null ? int.tryParse(json['graduation_year'].toString()) : null,
    );
  }

  // Copy with method for updating fields
  QueueEntry copyWith({
    String? id,
    String? name,
    String? ssuId,
    String? email,
    String? phoneNumber,
    String? department,
    String? purpose,
    String? course,
    DateTime? timestamp,
    int? queueNumber,
    String? status,
    DateTime? countdownStart,
    int? countdownDuration,
    bool? isPwd,
    bool? isSenior,
    bool? isPregnant,
    String? studentType,
    String? referenceNumber,
    String? gender,
    int? age,
    int? graduationYear,
  }) {
    return QueueEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      ssuId: ssuId ?? this.ssuId,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      department: department ?? this.department,
      purpose: purpose ?? this.purpose,
      course: course ?? this.course,
      timestamp: timestamp ?? this.timestamp,
      queueNumber: queueNumber ?? this.queueNumber,
      status: status ?? this.status,
      countdownStart: countdownStart ?? this.countdownStart,
      countdownDuration: countdownDuration ?? this.countdownDuration,
      isPwd: isPwd ?? this.isPwd,
      isSenior: isSenior ?? this.isSenior,
      isPregnant: isPregnant ?? this.isPregnant,
      studentType: studentType ?? this.studentType,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      graduationYear: graduationYear ?? this.graduationYear,
    );
  }

  // Helper method to get priority type as string
  String get priorityType {
    final priorities = <String>[];
    if (isPwd) priorities.add('PWD');
    if (isSenior) priorities.add('Senior');
    if (isPregnant) priorities.add('Pregnant');
    
    if (priorities.isEmpty) return 'Regular';
    return priorities.join(' & ');
  }

  // Helper method to get priority color
  String get priorityColor {
    return isPriority
        ? '#4CAF50'
        : '#2196F3'; // Green for priority, Blue for regular
  }
}
