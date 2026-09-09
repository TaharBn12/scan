import 'package:fpdart/fpdart.dart';

import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/app_user.dart';

/// Shop members live in the cloud at /shops/{shopId}/members/{uid}.
/// Passwords never touch the database — they're Firebase Auth's business;
/// here we only keep who the person is and what they may do.
class UserRepository {
  static const _currentUserKey = 'current_user_id';

  /// Member maps from RTDB lack the legacy auth fields — enrich with the
  /// member id (the map key) so the entity loads safely.
  AppUser _toUser(String uid, Map raw) {
    final map = Map<String, dynamic>.from(raw);
    map['id'] = uid;
    return AppUser.fromMap(map);
  }

  Future<Either<Failure, List<AppUser>>> getUsers() async {
    try {
      final box = CloudDatabase.usersBox;
      final users = <AppUser>[
        for (final uid in box.keys) _toUser(uid, box.get(uid) ?? const {}),
      ]..sort((a, b) {
          if (a.role != b.role) return a.isAdmin ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return Right(users);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  /// Creates or updates a member. Only name/role/active are editable here —
  /// a person's credentials belong to Firebase Auth (they sign up on the
  /// login page with the shop code, the admin then activates them here).
  Future<Either<Failure, AppUser>> saveUser({
    String? id,
    required String name,
    required UserRole role,
    String? email,
    String? password, // legacy signature, ignored in cloud mode
    String? pin, // legacy signature, ignored in cloud mode
    bool? active,
  }) async {
    try {
      if (id == null || id.isEmpty) {
        return const Left(CacheFailure('cloud_member_id_required'));
      }
      final box = CloudDatabase.usersBox;
      final current = box.get(id);
      final merged = <String, dynamic>{
        if (current != null) ...Map<String, dynamic>.from(current),
        'name': name.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'role': role.name,
        if (active != null) 'active': active,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await box.put(id, merged);
      return Right(_toUser(id, merged));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> deleteUser(String id) async {
    try {
      await CloudDatabase.usersBox.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  AppUser? getUser(String id) {
    final raw = CloudDatabase.usersBox.get(id);
    return raw == null ? null : _toUser(id, raw);
  }

  // ------------------------------------------------ legacy local helpers
  //
  // Kept for the legacy PIN/password quick-switch code paths. In cloud mode
  // the router gates everything behind the Firebase login long before these
  // could run, so they simply report "no match" against member data.

  AppUser? authenticate(String pin) => null;

  /// Legacy email+password gate (the cloud login page replaces it).
  /// Kept so [SessionController] keeps compiling; never matches in cloud.
  Either<Failure, AppUser> authenticateByPassword(
          String email, String password) =>
      const Left(CacheFailure('cloud_auth_gate'));

  bool get hasPinAccounts => false;

  Future<void> stampLogin(AppUser user) async {
    final box = CloudDatabase.usersBox;
    final raw = box.get(user.id);
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw);
    map['lastLoginAt'] = DateTime.now().toIso8601String();
    await box.put(user.id, map);
  }

  String? getCurrentUserId() =>
      CloudDatabase.settingsBox.get(_currentUserKey) as String?;

  Future<void> setCurrentUserId(String? id) async {
    if (id == null) {
      await CloudDatabase.settingsBox.delete(_currentUserKey);
    } else {
      await CloudDatabase.settingsBox.put(_currentUserKey, id);
    }
  }
}
