import 'package:equatable/equatable.dart';

enum UserRole { admin, cashier }

extension UserRoleX on UserRole {
  String get labelKey => 'role_$name';

  static UserRole fromName(String? name) {
    if (name == null) return UserRole.cashier;
    return UserRole.values.firstWhere(
      (r) => r.name == name,
      orElse: () => UserRole.cashier,
    );
  }
}

class AppUser extends Equatable {
  final String id;
  final String name;
  final UserRole role;
  /// SHA-256 hash of "<salt>:<pin>" (never the PIN itself).
  final String pinHash;
  final String salt;
  final DateTime createdAt;
  final bool active;

  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.pinHash,
    required this.salt,
    required this.createdAt,
    this.active = true,
  });

  bool get isAdmin => role == UserRole.admin;

  AppUser copyWith({
    String? name,
    UserRole? role,
    String? pinHash,
    String? salt,
    bool? active,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      salt: salt ?? this.salt,
      createdAt: createdAt,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role.name,
        'pinHash': pinHash,
        'salt': salt,
        'createdAt': createdAt.toIso8601String(),
        'active': active,
      };

  factory AppUser.fromMap(Map map) => AppUser(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        role: UserRoleX.fromName(map['role'] as String?),
        pinHash: map['pinHash'] as String? ?? '',
        salt: map['salt'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        active: map['active'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [id, name, role, pinHash, salt, createdAt, active];
}
