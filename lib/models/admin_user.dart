class AdminUser {
  final String id;
  final String username;
  final String password;
  final String department;
  final String name;
  final DateTime createdAt;

  AdminUser({
    required this.id,
    required this.username,
    required this.password,
    required this.department,
    required this.name,
    required this.createdAt,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password, // In production, this should be hashed
      'department': department,
      'name': name,
      // Use snake_case to match database column
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'],
      username: json['username'],
      password: json['password'],
      department: json['department'],
      name: json['name'],
      // Accept either created_at (DB) or createdAt (legacy/local)
      createdAt: DateTime.parse(
        (json['created_at'] ?? json['createdAt']) as String,
      ),
    );
  }

  // Copy with method for updating fields
  AdminUser copyWith({
    String? id,
    String? username,
    String? password,
    String? department,
    String? name,
    DateTime? createdAt,
  }) {
    return AdminUser(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      department: department ?? this.department,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
