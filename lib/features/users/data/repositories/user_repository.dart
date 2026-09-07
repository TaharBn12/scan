import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
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

  /// Creates or updates a user. [pin] is optional on update (keeps the old
  /// one when null/empty). Fails if the PIN collides with another user's.
  Future<Either<Failure, AppUser>> saveUser({
    String? id,
    required String name,
    required UserRole role,
    String? pin,
  }) async {
    try {
      final box = HiveDatabase.usersBox;
      final existing = id == null ? null : box.get(id);
      AppUser user;
      if (existing != null) {
        user = AppUser.fromMap(Map<String, dynamic>.from(existing as Map))
            .copyWith(name: name.trim(), role: role);
      } else {
        if (pin == null || !PinHelper.isValidPin(pin)) {
          return const Left(CacheFailure('pin_too_short'));
        }
        user = AppUser(
          id: const Uuid().v4(),
          name: name.trim(),
          role: role,
          pinHash: '',
          salt: '',
          createdAt: DateTime.now(),
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

  /// Finds the user whose PIN matches, or null.
  AppUser? authenticate(String pin) {
    for (final raw in HiveDatabase.usersBox.values) {
      final user = AppUser.fromMap(Map<String, dynamic>.from(raw as Map));
      if (user.active && PinHelper.verify(pin, user.salt, user.pinHash)) {
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
