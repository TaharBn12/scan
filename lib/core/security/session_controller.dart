import 'package:flutter/material.dart';

import '../data/hive_database.dart';
import '../../features/users/data/repositories/user_repository.dart';
import '../../features/users/domain/entities/app_user.dart';
import '../settings/app_settings_controller.dart';
import 'pin_helper.dart';

/// Who is using the app right now + whether the app is locked.
///
/// Two independent mechanisms share this controller:
///  * **App PIN lock** (settings.pinEnabled): one PIN for the whole app,
///    asked when the app opens / comes back from background.
///  * **Multi-user mode** (users box not empty + multi_user flag): each
///    cashier/admin signs in with their own PIN; permissions depend on role.
///
/// When no users exist, everyone is implicitly an admin (single-owner shop).
class SessionController extends ChangeNotifier {
  static const _multiUserKey = 'multi_user_enabled';

  final UserRepository _users = UserRepository();

  AppUser? _currentUser;
  bool _unlocked = false;

  SessionController() {
    final id = _users.getCurrentUserId();
    if (id != null) _currentUser = _users.getUser(id);
  }

  AppUser? get currentUser => _currentUser;

  bool get isMultiUser =>
      (HiveDatabase.settingsBox.get(_multiUserKey) as bool? ?? false) &&
      HiveDatabase.usersBox.isNotEmpty;

  Future<void> setMultiUser(bool enabled) async {
    await HiveDatabase.settingsBox.put(_multiUserKey, enabled);
    if (!enabled) {
      _currentUser = null;
      await _users.setCurrentUserId(null);
    }
    notifyListeners();
  }

  /// True when the app should show the lock/login screen.
  bool get needsUnlock {
    if (isMultiUser) return _currentUser == null;
    if (appSettings.value.pinEnabled && PinHelper.hasAppPin) return !_unlocked;
    return false;
  }

  bool get isAdmin => !isMultiUser || (_currentUser?.isAdmin ?? false);

  /// Whether a "lock" action makes sense right now (some PIN is configured).
  bool get canLock =>
      isMultiUser || (appSettings.value.pinEnabled && PinHelper.hasAppPin);

  String? get cashierId => isMultiUser ? _currentUser?.id : null;
  String? get cashierName => isMultiUser ? _currentUser?.name : null;

  /// Tries [pin] against the app PIN (single-user) or the users list
  /// (multi-user). Returns true when unlocked.
  Future<bool> unlockWithPin(String pin) async {
    if (isMultiUser) {
      final user = _users.authenticate(pin);
      if (user == null) return false;
      _currentUser = user;
      await _users.setCurrentUserId(user.id);
      _unlocked = true;
      notifyListeners();
      return true;
    }
    if (!PinHelper.verifyAppPin(pin)) return false;
    _unlocked = true;
    notifyListeners();
    return true;
  }

  /// Locks the app again (manual lock, or when resumed from background).
  Future<void> lock({bool signOut = true}) async {
    _unlocked = false;
    if (signOut && isMultiUser) {
      _currentUser = null;
      await _users.setCurrentUserId(null);
    }
    notifyListeners();
  }

  /// Called by settings screens after the users list changes so
  /// permissions refresh (e.g. current user was demoted/deleted).
  void refresh() {
    final id = _users.getCurrentUserId();
    _currentUser = id == null ? null : _users.getUser(id);
    notifyListeners();
  }
}

final sessionController = SessionController();
