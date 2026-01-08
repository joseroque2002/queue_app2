class SupabaseConfig {
  // Supabase credentials
  static const String supabaseUrl = 'https://imnnlmqcapiivnrsdwqq.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imltbm5sbXFjYXBpaXZucnNkd3FxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0OTI3MjksImV4cCI6MjA3MTA2ODcyOX0.Y8uirXHdTyQj5MTplQqxe5_FtwZcofGO99PAXAfEOhE';

  // Table names
  static const String queueEntriesTable = 'queue_entries';
  static const String adminUsersTable = 'admin_users';
  static const String departmentsTable = 'departments';
  static const String purposesTable = 'purposes';
  static const String coursesTable = 'courses';

  // Column names for queue_entries table
  static const String idColumn = 'id';
  static const String nameColumn = 'name';
  static const String ssuIdColumn = 'ssu_id';
  static const String emailColumn = 'email';
  static const String phoneNumberColumn = 'phone_number';
  static const String departmentColumn = 'department';
  static const String purposeColumn = 'purpose';
  static const String timestampColumn = 'timestamp';
  static const String queueNumberColumn = 'queue_number';
  static const String statusColumn = 'status';

  // Column names for admin_users table
  static const String adminIdColumn = 'id';
  static const String usernameColumn = 'username';
  static const String passwordColumn = 'password';
  static const String adminDepartmentColumn = 'department';
  static const String adminNameColumn = 'name';
  static const String createdAtColumn = 'created_at';

  // Status values for queue entries
  static const String statusWaiting = 'waiting';
  static const String statusServing = 'current';
  static const String statusCompleted = 'done';
  static const String statusCancelled = 'cancelled';
  static const String statusMissed = 'missed';

  // Countdown column names
  static const String countdownStartColumn = 'countdown_start';
  static const String countdownDurationColumn = 'countdown_duration';
}
