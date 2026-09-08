import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/security/auth_helper.dart';
import '../../../../core/security/pin_helper.dart';
import '../../domain/entities/app_user.dart';

/// Users live in a plain Hive box. Small feature, so repository interface and
/// implementation share one file.
class UserRepository {
  static const _currentUserKey = 'current_user_id';

  Future<Either<Failure, List<AppUser>>> getUsers() async {
    try {
      final users = HiveDatabase.usersBox.values
          .map((raw) => AppUser.fromMap(Map<String, dynamic>.from(raw as Map)))
          .toList()
        ..sort((a, b) {
          if (a.role != b.role) return a.isAdmin ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return Right(users);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  /// Creates or updates an account.
  ///
  /// [password] and [pin] are optional on update (empty keeps the current
  /// one). The login identifier must be unique, and so must the PIN — it is
  /// what identifies a cashier at the quick-switch screen.
  Future<Either<Failure, AppUser>> saveUser({
    String? id,
    required String name,
    required UserRole role,
    String? email,
    String? password,
    String? pin,
    bool? active,
  }) async {
    try {
      final box = HiveDatabase.usersBox;
      final existing = id == null ? null : box.get(id);
      final normalizedEmail =
          email == null ? null : AuthHelper.normalizeEmail(email);

      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        if (!AuthHelper.isValidEmail(normalizedEmail)) {
          return const Left(CacheFailure('invalid_email'));
        }
        for (final raw in box.values) {
          final other = AppUser.fromMap(Map<String, dynamic>.from(raw as Map));
          if (other.id != id && other.email == normalizedEmail) {
            return const Left(CacheFailure('email_in_use'));
          }
        }
      }

      AppUser user;
      if (existing != null) {
        user = AppUser.fromMap(Map<String, dynamic>.from(existing as Map))
            .copyWith(
          name: name.trim(),
          role: role,
          email: normalizedEmail,
          active: active,
        );
      } else {
        final hasPassword =
            password != null && AuthHelper.isValidPassword(password);
        final hasPin = pin != null && PinHelper.isValidPin(pin);
        // A brand new account needs at least one way to sign in.
        if (!hasPassword && !hasPin) {
          return const Left(CacheFailure('password_or_pin_required'));
        }
        if (password != null &&
            password.isNotEmpty &&
            !AuthHelper.isValidPassword(password)) {
          return const Left(CacheFailure('password_too_short'));
        }
        if (hasPassword && (normalizedEmail == null || normalizedEmail.isEmpty)) {
          return const Left(CacheFailure('email_required'));
        }
        user = AppUser(
          id: const Uuid().v4(),
          name: name.trim(),
          email: normalizedEmail ?? '',
          role: role,
          pinHash: '',
          salt: '',
          createdAt: DateTime.now(),
          active: active ?? true,
        );
      }

      if (password != null && password.isNotEmpty) {
        if (!AuthHelper.isValidPassword(password)) {
          return const Left(CacheFailure('password_too_short'));
        }
        if (user.email.isEmpty) {
          return const Left(CacheFailure('email_required'));
        }
        final passwordSalt = AuthHelper.newSalt();
        user = user.copyWith(
          passwordSalt: passwordSalt,
          passwordHash: AuthHelper.hashPassword(password, passwordSalt),
        );
      }

      if (pin != null && pin.isNotEmpty) {
        if (!PinHelper.isValidPin(pin)) {
          return const Left(CacheFailure('pin_too_short'));
        }
        // A PIN must identify a single user at the "who is working" screen.
        for (final raw in box.values) {
          final other = AppUser.fromMap(Map<String, dynamic>.from(raw as Map));
          if (other.id != user.id &&
              other.pinHash.isNotEmpty &&
              PinHelper.verify(pin, other.salt, other.pinHash)) {
            return const Left(CacheFailure('pin_in_use'));
          }
        }
        final salt = PinHelper.newSalt();
        user = user.copyWith(salt: salt, pinHash: PinHelper.hash(pin, salt));
      }

      await box.put(user.id, user.toMap());
      return Right(user);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> deleteUser(String id) async {
    try {
      final box = HiveDatabase.usersBox;
      final users = box.values
          .map((raw) => AppUser.fromMap(Map<String, dynamic>.from(raw as Map)))
          .toList();
      final target = users.where((u) => u.id == id).firstOrNull;
      if (target == null) return const Right(null);
      final adminsLeft = users.where((u) => u.isAdmin && u.id != id).length;
      if (target.isAdmin && adminsLeft == 0 && users.length > 1) {
        return const Left(CacheFailure('cannot_delete_last_admin'));
      }
      await box.delete(id);
      if (getCurrentUserId() == id) await setCurrentUserId(null);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  /// Signs in with the login identifier + password.
  ///
  /// Returns a failure key so the UI can tell "unknown account" from
  /// "wrong password" from "account disabled".
  Either<Failure, AppUser> authenticateByPassword(
      String email, String password) {
    final target = AuthHelper.normalizeEmail(email);
    AppUser? match;
    for (final raw in HiveDatabase.usersBox.values) {
      final user = AppUser.fromMap(Map<String, dynamic>.from(raw as Map));
      if (user.email == target && user.email.isNotEmpty) {
        match = user;
        break;
      }
    }
    if (match == null) return const Left(CacheFailure('account_not_found'));
    if (!match.active) return const Left(CacheFailure('account_disabled'));
    if (!match.hasPassword) {
      return const Left(CacheFailure('account_has_no_password'));
    }
    if (!AuthHelper.verifyPassword(
        password, match.passwordSalt, match.passwordHash)) {
      return const Left(CacheFailure('wrong_password'));
    }
    return Right(match);
  }

  /// Any account able to sign in with a PIN (drives the PIN tab).
  bool get hasPinAccounts => HiveDatabase.usersBox.values.any((raw) =>
      (AppUser.fromMap(Map<String, dynamic>.from(raw as Map))).hasPin);

  Future<void> stampLogin(AppUser user) async {
    await HiveDatabase.usersBox
        .put(user.id, user.copyWith(lastLoginAt: DateTime.now()).toMap());
  }

  /// Finds the user whose PIN matches, or null.
  AppUser? authenticate(String pin) {
    for (final raw in HiveDatabase.usersBox.values) {
      final user = AppUser.fromMap(Map<String, dynamic>.from(raw as Map));
      if (user.active &&
          user.pinHash.isNotEmpty &&
          PinHelper.verify(pin, user.salt, user.pinHash)) {
        return user;
      }
    }
    return null;
  }

  String? getCurrentUserId() =>
      HiveDatabase.settingsBox.get(_currentUserKey) as String?;

  Future<void> setCurrentUserId(String? id) async {
    if (id == null) {
      await HiveDatabase.settingsBox.delete(_currentUserKey);
    } else {
      await HiveDatabase.settingsBox.put(_currentUserKey, id);
    }
  }

  AppUser? getUser(String id) {
    final raw = HiveDatabase.usersBox.get(id);
    if (raw == null) return null;
    return AppUser.fromMap(Map<String, dynamic>.from(raw as Map));
  }
}
