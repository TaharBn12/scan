import 'package:flutter/material.dart';

import '../cloud/cloud_database.dart';
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

  /// When the app runs in cloud mode, sign-in is mandatory and the signed-in
  /// member always drives permissions (multi-user semantics by default).
  bool _cloudMode = false;

  SessionController() {
    final id = _users.getCurrentUserId();
    if (id != null) _currentUser = _users.getUser(id);
  }

  /// Called by the cloud auth controller on sign-in/out. A null user
  /// returns to local-only behavior (offline start without session).
  void setCloudUser(AppUser? user, {bool cloudMode = true}) {
    _cloudMode = cloudMode;
    _currentUser = user;
    _unlocked = user != null;
    notifyListeners();
  }

  AppUser? get currentUser => _currentUser;

  /// True as soon as accounts exist and the shop hasn't opted out.
  bool get isMultiUser =>
      _cloudMode ||
      ((CloudDatabase.settingsBox.get(_multiUserKey) as bool? ?? false) &&
          CloudDatabase.usersBox.isNotEmpty);

  /// At least one account exists (so the login screen makes sense).
  bool get hasAccounts => CloudDatabase.usersBox.isNotEmpty;

  /// At least one account can be unlocked with a quick PIN.
  bool get hasPinAccounts => _users.hasPinAccounts;

  Future<void> setMultiUser(bool enabled) async {
    await CloudDatabase.settingsBox.put(_multiUserKey, enabled);
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

  /// The role driving permissions. Without multi-user accounts the owner is
  /// using their own phone, so they get everything.
  UserRole get role =>
      isMultiUser ? (_currentUser?.role ?? UserRole.cashier) : UserRole.admin;

  bool get canViewReports => !isMultiUser || role.canViewReports;
  bool get canManageExpenses => !isMultiUser || role.canManageExpenses;
  bool get canManageProducts => !isMultiUser || role.canManageProducts;
  bool get canManageInventory => !isMultiUser || role.canManageInventory;
  bool get canManageCustomers => !isMultiUser || role.canManageCustomers;
  bool get canChangeSettings => !isMultiUser || role.canChangeSettings;
  bool get canManageUsers => !isMultiUser || role.canManageUsers;

  /// Courier session: the router funnels him to his own screens.
  bool get isDeliverer => isMultiUser && role == UserRole.deliverer;

  /// Route guard used by the router: which screens this session may open.
  bool canOpen(String location) {
    if (!isMultiUser) return true;
    bool starts(String prefix) => location.startsWith(prefix);
    if (starts('/settings') || starts('/shop') || starts('/users')) {
      return canChangeSettings || canManageUsers;
    }
    if (starts('/reports')) return canViewReports;
    if (starts('/expenses')) return canManageExpenses;
    if (starts('/inventory')) return canManageInventory;
    if (starts('/promotions')) return canManageProducts;
    if (starts('/products/add') ||
        starts('/products/edit') ||
        starts('/products/low-stock') ||
        starts('/products/dead-stock') ||
        starts('/labels')) {
      return canManageProducts;
    }
    if (starts('/customers/debts')) return canManageCustomers;
    // Delivery board + live tracking: who is trusted with the money view.
    if (starts('/deliveries')) return canViewReports;
    // The courier's own screens: himself, or an admin looking over.
    if (starts('/courier')) return role == UserRole.deliverer || isAdmin;
    return true;
  }

  /// Whether a "lock" action makes sense right now (some PIN is configured).
  bool get canLock =>
      isMultiUser || (appSettings.value.pinEnabled && PinHelper.hasAppPin);

  String? get cashierId => isMultiUser ? _currentUser?.id : null;
  String? get cashierName => isMultiUser ? _currentUser?.name : null;

  /// Signs in with the account identifier + password. Returns null on
  /// success, or a localization key describing the failure.
  Future<String?> signInWithPassword(String email, String password) async {
    final result = _users.authenticateByPassword(email, password);
    String? failureKey;
    AppUser? user;
    result.fold<void>(
      (failure) {
        failureKey = failure.message;
      },
      (value) {
        user = value;
      },
    );
    final signedIn = user;
    if (signedIn == null) return failureKey ?? 'error';

    _currentUser = signedIn;
    await _users.setCurrentUserId(signedIn.id);
    await _users.stampLogin(signedIn);
    _unlocked = true;
    notifyListeners();
    return null;
  }

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
