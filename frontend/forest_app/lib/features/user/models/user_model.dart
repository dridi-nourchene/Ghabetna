// features/user/models/user_model.dart

enum UserRoleFilter { all, supervisor, agent }

class AppUser {
  final String userId;
  final String fullName;
  final String email;
  final String cin;
  final String? phone;
  final String role;        // 'admin' | 'supervisor' | 'agent'
  final String status;      // 'active' | 'inactive' | 'banned'
  final String? birthDate;
  final String createdAt;

  const AppUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.cin,
    this.phone,
    required this.role,
    required this.status,
    this.birthDate,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        userId:    json['user_id'],
        fullName:  json['full_name'],
        email:     json['email'],
        cin:       json['cin'],
        phone:     json['phone'],
        role:      json['role'],
        status:    json['status'],
        birthDate: json['birth_date'],
        createdAt: json['created_at'],
      );

  Map<String, dynamic> toJson() => {
        'user_id':    userId,
        'full_name':  fullName,
        'email':      email,
        'cin':        cin,
        'phone':      phone,
        'role':       role,
        'status':     status,
        'birth_date': birthDate,
        'created_at': createdAt,
      };

  AppUser copyWith({
    String? fullName,
    String? email,
    String? cin,
    String? phone,
    String? role,
    String? status,
    String? birthDate,
  }) =>
      AppUser(
        userId:    userId,
        fullName:  fullName    ?? this.fullName,
        email:     email       ?? this.email,
        cin:       cin         ?? this.cin,
        phone:     phone       ?? this.phone,
        role:      role        ?? this.role,
        status:    status      ?? this.status,
        birthDate: birthDate   ?? this.birthDate,
        createdAt: createdAt,
      );

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.substring(0, 2).toUpperCase();
  }
}