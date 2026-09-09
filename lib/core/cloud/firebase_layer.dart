import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'cloud_database.dart';

/// A shop member: who the person is and what they are allowed to do.
enum MemberRole { admin, cashier, accountant, stockkeeper, deliverer, viewer }

MemberRole memberRoleFromName(String? name) {
  switch (name) {
    case 'admin':
      return MemberRole.admin;
    case 'accountant':
      return MemberRole.accountant;
    case 'stockkeeper':
      return MemberRole.stockkeeper;
    case 'deliverer':
      return MemberRole.deliverer;
    case 'viewer':
      return MemberRole.viewer;
    default:
      return MemberRole.cashier;
  }
}

class MemberProfile {
  final String uid;
  final String name;
  final String email;
  final MemberRole role;
  final bool active;
  final String shopId;

  const MemberProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.shopId,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role.name,
        'active': active,
        'shopId': shopId,
        'updatedAt': ServerValue.timestamp,
      };

  factory MemberProfile.fromMap(String uid, Map<dynamic, dynamic> map) {
    return MemberProfile(
      uid: uid,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      role: memberRoleFromName(map['role'] as String?),
      active: map['active'] != false,
      shopId: (map['shopId'] as String?) ?? '',
    );
  }
}

/// Everything the login/registration flow needs from Firebase.
class FirebaseLayer {
  FirebaseLayer._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  // ------------------------------------------------------------ sessions

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  static Future<void> signOut() => _auth.signOut();

  // -------------------------------------------------------- registration

  /// Creates the Firebase account, then either:
  ///  * [_bootstrapShop] — no shop code given → a brand new shop owned by
  ///    this first user (admin + active immediately); or
  ///  * [_joinShop] — code given → membership recorded, pending until an
  ///    admin of that shop approves it.
  static Future<UserCredential> register({
    required String email,
    required String password,
  }) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  static Future<void> _bootstrapShop({
    required User user,
    required String name,
    required String shopName,
  }) async {
    // New shop id = the owner's uid keeps things simple & unique.
    final shopId = user.uid;
    final now = ServerValue.timestamp;
    final updates = <String, dynamic>{
      'shops/$shopId/meta/name': shopName.isEmpty ? 'My shop' : shopName,
      'shops/$shopId/meta/owner': user.uid,
      'shops/$shopId/meta/createdAt': now,
      'shops/$shopId/members/${user.uid}': {
        'name': name,
        'email': user.email,
        'role': 'admin',
        'active': true,
        'joinedAt': now,
      },
      'users/${user.uid}': {
        'name': name,
        'email': user.email,
        'shopId': shopId,
        'createdAt': now,
      },
    };
    await FirebaseDatabase.instance.ref().update(updates);
  }

  /// Generates a memorable join code for a shop, e.g. "LT-4X9K".
  static String shopCodeOf(String shopId) {
    // Short, readable, stable: first 6 base-32-ish chars of the uid's hash.
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var h = 0;
    for (final unit in shopId.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    final buf = StringBuffer('LT-');
    for (var i = 0; i < 4; i++) {
      buf.write(alphabet[h % alphabet.length]);
      h ~/= alphabet.length;
    }
    return buf.toString();
  }

  static Future<String?> _shopIdFromCode(String code) async {
    final norm = code.trim().toUpperCase();
    if (norm.isEmpty) return null;
    // Codes are resolved through a public index written on shop creation:
    // /shop_codes/{CODE} → shopId. Admins also see the code in settings.
    final snap = await CloudDatabase.shopCode(norm).get();
    if (!snap.exists) return null;
    return snap.value as String?;
  }

  static Future<void> _joinShop({
    required User user,
    required String name,
    required String shopCode,
  }) async {
    final shopId = await _shopIdFromCode(shopCode);
    if (shopId == null) {
      throw FirebaseException(
          plugin: 'cloud', code: 'bad-shop-code', message: 'unknown code');
    }
    final now = ServerValue.timestamp;
    final updates = <String, dynamic>{
      'shops/$shopId/members/${user.uid}': {
        'name': name,
        'email': user.email,
        'role': 'cashier',
        'active': false, // admin must approve
        'joinedAt': now,
      },
      'users/${user.uid}': {
        'name': name,
        'email': user.email,
        'shopId': shopId,
        'createdAt': now,
      },
    };
    await FirebaseDatabase.instance.ref().update(updates);
  }

  /// Publishes (or refreshes) a join code for [shopId] — idempotent.
  static Future<void> ensureShopCode(String shopId) async {
    final code = shopCodeOf(shopId);
    await FirebaseDatabase.instance.ref('shop_codes/$code').set(shopId);
  }

  /// Full registration entry point used by the register page.
  static Future<UserCredential> registerAccount({
    required String email,
    required String password,
    required String displayName,
    required String shopName,
    String? shopCode,
  }) async {
    final cred = await register(email: email, password: password);
    final user = cred.user!;
    try {
      await user.updateDisplayName(displayName);
      if (shopCode == null || shopCode.trim().isEmpty) {
        await _bootstrapShop(user: user, name: displayName, shopName: shopName);
        await ensureShopCode(user.uid);
      } else {
        await _joinShop(user: user, name: displayName, shopCode: shopCode);
      }
    } catch (e) {
      // Roll the auth account back so a failed registration leaves no orphan.
      try {
        await user.delete();
      } catch (_) {}
      rethrow;
    }
    return cred;
  }

  // ------------------------------------------------------------ profiles

  /// Loads the signed-in user's member profile inside their shop, or null
  /// when the record is missing (orphaned account → treated as pending).
  static Future<MemberProfile?> loadMemberProfile(String uid) async {
    final userSnap = await CloudDatabase.userProfile(uid).get();
    if (!userSnap.exists) return null;
    final userMap = userSnap.value as Map?;
    final shopId = (userMap?['shopId'] as String?) ?? '';
    if (shopId.isEmpty) return null;
    final memberSnap = await CloudDatabase.shopMember(shopId, uid).get();
    if (!memberSnap.exists) return null;
    return MemberProfile.fromMap(uid, memberSnap.value as Map);
  }

  static Stream<DatabaseEvent> watchMemberProfile(String shopId, String uid) =>
      CloudDatabase.shopMember(shopId, uid).onValue;

  /// Admin approves / changes a teammate (writes only member fields).
  static Future<void> saveMember({
    required String shopId,
    required String uid,
    required String name,
    required MemberRole role,
    required bool active,
  }) {
    return CloudDatabase.shopMember(shopId, uid).update({
      'name': name,
      'role': role.name,
      'active': active,
      'updatedAt': ServerValue.timestamp,
    });
  }

  static Future<void> removeMember(String shopId, String uid) =>
      CloudDatabase.shopMember(shopId, uid).remove();

  // ------------------------------------------------- admin-created members

  /// Creates a Firebase Auth account for a teammate WITHOUT signing the
  /// admin out: account creation normally switches the session to the new
  /// user, so it happens on a throwaway secondary Firebase app whose own
  /// auth instance gets discarded right after.
  static Future<String> createAuthAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final secondary = await Firebase.initializeApp(
      name: 'member-creator-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final auth = FirebaseAuth.instanceFor(app: secondary);
      final cred = await auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      final user = cred.user;
      if (user == null) {
        throw FirebaseException(
            plugin: 'cloud', code: 'no-user', message: 'no user returned');
      }
      await user.updateDisplayName(displayName.trim());
      return user.uid;
    } finally {
      await secondary.delete();
    }
  }

  /// Writes the full membership for an account the admin just created:
  /// the member row inside *this* shop (active immediately — no approval
  /// round trip) and the /users routing sliver. The shop code is the
  /// admin's own: filled here, never typed, never editable.
  static Future<void> enrollMember({
    required String shopId,
    required String uid,
    required String name,
    required String email,
    required MemberRole role,
  }) {
    final now = ServerValue.timestamp;
    return FirebaseDatabase.instance.ref().update({
      'shops/$shopId/members/$uid': {
        'name': name.trim(),
        'email': email.trim(),
        'role': role.name,
        'active': true,
        'joinedAt': now,
      },
      'users/$uid': {
        'name': name.trim(),
        'email': email.trim(),
        'shopId': shopId,
        'createdAt': now,
      },
    });
  }

  // ------------------------------------------------------ deliverer state

  /// Delivers toggling themselves in/out of service (or an admin doing it
  /// for them) — drives the green "on duty" dot everywhere.
  static Future<void> setDuty(String shopId, String uid, bool onDuty) =>
      CloudDatabase.ref(shopId, 'members')
          .child(uid)
          .update({'onDuty': onDuty, 'dutyAt': ServerValue.timestamp});

  /// Live position of a deliverer, throttled by the app itself.
  /// Merged under members/{uid}/location so the member doc keeps its shape.
  static Future<void> updateMemberLocation(
          String shopId, String uid, double lat, double lng) =>
      CloudDatabase.ref(shopId, 'members').child(uid).child('location').set({
        'lat': lat,
        'lng': lng,
        'at': ServerValue.timestamp,
      });

  /// Admin blocking/unblocking an account: a blocked member keeps their
  /// record but can no longer work (the session watch kicks them out live).
  static Future<void> setMemberBlocked(String shopId, String uid, bool blocked) =>
      CloudDatabase.ref(shopId, 'members').child(uid).update({
        'active': !blocked,
        'blocked': blocked,
        'blockedAt': blocked ? ServerValue.timestamp : null,
      });
}

/// Maps Firebase error codes to localization keys for friendly messages.
class AuthErrorKeys {
  AuthErrorKeys._();

  static String from(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'auth_error_user_not_found';
        case 'wrong-password':
          return 'auth_error_wrong_password';
        case 'invalid-email':
          return 'auth_error_invalid_email';
        case 'email-already-in-use':
          return 'auth_error_email_in_use';
        case 'weak-password':
          return 'auth_error_weak_password';
        case 'network-request-failed':
          return 'auth_error_network';
        case 'too-many-requests':
          return 'auth_error_too_many';
        case 'operation-not-allowed':
          return 'auth_error_disabled';
        case 'invalid-credential':
          return 'auth_error_wrong_password';
        default:
          return 'auth_error_generic';
      }
    }
    if (error is FirebaseException) {
      if (error.code == 'bad-shop-code') return 'auth_error_shop_code';
      return 'auth_error_generic';
    }
    return 'auth_error_generic';
  }
}
