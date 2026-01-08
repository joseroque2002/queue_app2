class Course {
  final String id;
  final String code;
  final String name;
  final String departmentCode; // Foreign key to department
  final String description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Course({
    required this.id,
    required this.code,
    required this.name,
    required this.departmentCode,
    required this.description,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'department_code': departmentCode,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Create from JSON
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      departmentCode: json['department_code']?.toString() ?? json['departmentCode']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'].toString())
              : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'].toString())
              : null,
    );
  }

  // Copy with method for updating fields
  Course copyWith({
    String? id,
    String? code,
    String? name,
    String? departmentCode,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      departmentCode: departmentCode ?? this.departmentCode,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Course(id: $id, code: $code, name: $name, departmentCode: $departmentCode, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Course &&
        other.id == id &&
        other.code == code &&
        other.name == name &&
        other.departmentCode == departmentCode &&
        other.description == description &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        code.hashCode ^
        name.hashCode ^
        departmentCode.hashCode ^
        description.hashCode ^
        isActive.hashCode;
  }
}

