import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../features/users/domain/entities/app_user.dart';
import '../security/session_controller.dart';
import '../settings/app_settings_controller.dart';
import '../theme/theme_controller.dart';
import 'cloud_database.dart';
import 'cloud_migrator.dart';
import 'firebase_layer.dart';

/// The single cloud session instance, assigned in `main()`.
late final CloudAuthController cloudAuth;

/// Fire-and-forget patch of the shop's settings document. Used by the
/// settings pages so look & behavior sync to every device of the shop.
Future<void> patchShopSettings(Map<String, dynamic> patch) async {
  final shopId = CloudDatabase.shopId;
  if (shopId == null) return;
  try {
    await CloudDatabase.shopBox(shopId, 'settings')
        .child('app_settings')
        .update(patch);
  } catch (_) {/* offline: RTDB replays it later */}
}

/// Where the sign-in process currently stands. The router redirects on
/// every transition (this controller is its `refreshListenable`).
enum CloudAuthState {
  /// Startup: not yet resolved.
  unknown,

  /// No google-services.json → Firebase could not start at all.
  configMissing,

  /// No Firebase session → the mandatory login page.
  signedOut,

  /// Signed in but the account is not (yet) an active shop member
  /// (fresh join request, or orphaned record).
  pendingApproval,

  /// Full session: profile resolved, shop attached, data mirrored.
  ready,
}

/// The cloud session driving the whole app.
///
/// Flow: FirebaseAuth → `/users/{uid}` → shopId → member doc
/// (`/shops/{sid}/members/{uid}`, role + active) → attach all CloudBoxes →
/// push shop look & feel (theme/settings) into the existing controllers →
/// bridge the role into [SessionController] so every permission check in
/// the app keeps working untouched.
class CloudAuthController extends ChangeNotifier {
  CloudAuthController({required bool firebaseAvailable})
      : _state = firebaseAvailable
            ? CloudAuthState.unknown
            : CloudAuthState.configMissing {
    if (firebaseAvailable) {
      _sub = FirebaseLayer.authStateChanges().listen(_onAuthChanged);
    }
  }

  CloudAuthState _state;
  MemberProfile? _profile;
  String? _error;
  StreamSubscription<User?>? _sub;
  StreamSubscription? _settingsSub;

  CloudAuthState get state => _state;
  MemberProfile? get profile => _profile;
  String? get error => _error;

  String? get shopId => _profile?.shopId;
  bool get isAdmin => _profile?.role == MemberRole.admin;

  // ------------------------------------------------------------- actions

  Future<String?> signIn(String email, String password) async {
    try {
      await FirebaseLayer.signIn(email.trim(), password);
      return null; // authStateChanges continues the flow
    } catch (e) {
      return AuthErrorKeys.from(e);
    }
  }

  Future<String?> register({
    required String email,
    required String password,
    required String displayName,
    required String shopName,
    String? shopCode,
  }) async {
    try {
      await FirebaseLayer.registerAccount(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
        shopName: shopName.trim(),
        shopCode: shopCode,
      );
      return null;
    } catch (e) {
      return AuthErrorKeys.from(e);
    }
  }

  Future<void> signOut() async {
    _settingsSub?.cancel();
    CloudDatabase.detach();
    sessionController.setCloudUser(null);
    await FirebaseLayer.signOut();
  }

  // -------------------------------------------------------------- engine

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _settingsSub?.cancel();
      CloudDatabase.detach();
      _profile = null;
      _setState(CloudAuthState.signedOut);
      return;
    }
    try {
      final profile = await FirebaseLayer.loadMemberProfile(user.uid);
      if (profile == null || !profile.active) {
        _profile = profile;
        _setState(CloudAuthState.pendingApproval);
        return;
      }
      _profile = profile;
      await CloudDatabase.attach(profile.shopId);
      _applyCloudSettings(profile.shopId);
      _bridgeSession(profile);
      CloudMigrator.migrateLocalDataOnce();
      _setState(CloudAuthState.ready);
    } catch (e) {
      _error = 'auth_error_network';
      _setState(CloudAuthState.signedOut);
    }
  }

  /// Maps the cloud member onto the legacy user entity so the entire
  /// existing permission system (`sessionController.can*`) works verbatim.
  void _bridgeSession(MemberProfile profile) {
    final role = switch (profile.role) {
      MemberRole.admin => UserRole.admin,
      MemberRole.cashier => UserRole.cashier,
      MemberRole.viewer => UserRole.accountant,
    };
    sessionController.setCloudUser(AppUser(
      id: profile.uid,
      name: profile.name,
      email: profile.email,
      role: role,
      pinHash: '',
      salt: '',
      passwordHash: '',
      passwordSalt: '',
      createdAt: DateTime.now(),
      active: profile.active,
    ));
  }

  void _applyCloudSettings(String shopId) {
    _settingsSub?.cancel();
    _settingsSub = CloudDatabase.shopBox(shopId, 'settings')
        .child('app_settings')
        .onValue
        .listen((event) {
      final map = event.snapshot.value;
      if (map is! Map) return;
      // Theme: same doc drives every device's look.
      final mode = (map['themeMode'] as String?) ?? 'system';
      final accent = (map['accentColor'] as String?) ?? 'indigo';
      final compact = map['compactMode'] == true;
      final cur = themeController.value;
      final targetMode = switch (mode) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
      if (cur.mode != targetMode ||
          cur.accentId != accent ||
          cur.compact != compact) {
        themeController.applyCloud(
            mode: targetMode, accentId: accent, compact: compact);
      }
      // App settings (locale, currency, decimals, …) — same one document:
      // whichever device changes it, every other device follows live.
      appSettings.applyCloud(
        currencySymbol: map['currencySymbol'] as String?,
        currencySymbolBefore: map['currencySymbolBefore'] as bool?,
        decimalDigits: (map['decimalDigits'] as num?)?.toInt(),
        decimalQuantities: map['decimalQuantities'] as bool?,
        localeCode: map['locale'] as String?,
      );
    });
  }

  void _setState(CloudAuthState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }
}

/// The look & behavior document stored per shop in the cloud
/// (`settings/app_settings`). Kept separate from session state so settings
/// pages can read/save it without caring about auth.
class ShopAppSettings {
  final String locale;
  final String currencySymbol;
  final bool currencySymbolBefore;
  final int decimalDigits;
  final bool decimalQuantities;
  final String themeMode;
  final String accentColor;
  final bool compactMode;

  const ShopAppSettings({
    this.locale = 'ar',
    this.currencySymbol = 'DA',
    this.currencySymbolBefore = false,
    this.decimalDigits = 2,
    this.decimalQuantities = true,
    this.themeMode = 'system',
    this.accentColor = 'indigo',
    this.compactMode = false,
  });

  factory ShopAppSettings.fromMap(Map<dynamic, dynamic> map) => ShopAppSettings(
        locale: (map['locale'] as String?) ?? 'ar',
        currencySymbol: (map['currencySymbol'] as String?) ?? 'DA',
        currencySymbolBefore: map['currencySymbolBefore'] == true,
        decimalDigits: (map['decimalDigits'] as num?)?.toInt() ?? 2,
        decimalQuantities: map['decimalQuantities'] != false,
        themeMode: (map['themeMode'] as String?) ?? 'system',
        accentColor: (map['accentColor'] as String?) ?? 'indigo',
        compactMode: map['compactMode'] == true,
      );

  Map<String, dynamic> toMap() => {
        'locale': locale,
        'currencySymbol': currencySymbol,
        'currencySymbolBefore': currencySymbolBefore,
        'decimalDigits': decimalDigits,
        'decimalQuantities': decimalQuantities,
        'themeMode': themeMode,
        'accentColor': accentColor,
        'compactMode': compactMode,
      };

  static Future<void> save(String shopId, Map<String, dynamic> patch) =>
      CloudDatabase.shopBox(shopId, 'settings')
          .child('app_settings')
          .update(patch);
}
