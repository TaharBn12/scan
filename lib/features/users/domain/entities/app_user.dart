import 'package:equatable/equatable.dart';

/// What a person is allowed to do in the shop.
///
/// Roles are deliberately concrete (the four jobs a small shop actually
/// has) and every screen asks the role, not the user, for permission.
enum UserRole { admin, accountant, stockkeeper, cashier }

extension UserRoleX on UserRole {
  String get labelKey => 'role_$name';
  String get descriptionKey => 'role_${name}_desc';

  bool get isAdmin => this == UserRole.admin;

  /// Selling at the till (everybody can serve a customer).
  bool get canSell => true;

  /// Reports, profit, Z-report, exports.
  bool get canViewReports =>
      this == UserRole.admin || this == UserRole.accountant;

  /// Daily expenses and cash-out entries.
  bool get canManageExpenses =>
      this == UserRole.admin || this == UserRole.accountant;

  /// Creating/editing products, labels, low-stock and stock takes.
  bool get canManageProducts =>
      this == UserRole.admin || this == UserRole.stockkeeper;

  /// Purchases and stock movements.
  bool get canManageInventory =>
      this == UserRole.admin || this == UserRole.stockkeeper;

  /// Customer files and debt follow-up.
  bool get canManageCustomers => this != UserRole.stockkeeper;

  /// App settings, shop identity, backups.
  bool get canChangeSettings => this == UserRole.admin;

  /// Creating other accounts.
  bool get canManageUsers => this == UserRole.admin;

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

  /// Login identifier. Normalised to lower case; may be a plain username
  /// (e.g. "karim") or a real e-mail — both work offline.
  final String email;

  final UserRole role;

  /// SHA-256 of "<salt>:<pin>" — quick switching at the till (optional).
  final String pinHash;
  final String salt;

  /// Stretched hash of the account password (see AuthHelper).
  final String passwordHash;
  final String passwordSalt;

  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool active;

  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.pinHash,
    required this.salt,
    required this.createdAt,
    this.email = '',
    this.passwordHash = '',
    this.passwordSalt = '',
    this.lastLoginAt,
    this.active = true,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get hasPassword => passwordHash.isNotEmpty;
  bool get hasPin => pinHash.isNotEmpty;

  /// Two initials for the avatar.
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String word) => word.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return first(parts[0]) + first(parts[1]);
  }

  AppUser copyWith({
    String? name,
    String? email,
    UserRole? role,
    String? pinHash,
    String? salt,
    String? passwordHash,
    String? passwordSalt,
    DateTime? lastLoginAt,
    bool? active,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      salt: salt ?? this.salt,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'pinHash': pinHash,
        'salt': salt,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'active': active,
      };

  factory AppUser.fromMap(Map map) => AppUser(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        email: (map['email'] as String? ?? '').toLowerCase(),
        role: UserRoleX.fromName(map['role'] as String?),
        pinHash: map['pinHash'] as String? ?? '',
        salt: map['salt'] as String? ?? '',
        passwordHash: map['passwordHash'] as String? ?? '',
        passwordSalt: map['passwordSalt'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        lastLoginAt: DateTime.tryParse(map['lastLoginAt'] as String? ?? ''),
        active: map['active'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        role,
        pinHash,
        salt,
        passwordHash,
        passwordSalt,
        createdAt,
        lastLoginAt,
        active,
      ];
}
