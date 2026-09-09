import 'package:firebase_database/firebase_database.dart';

import '../../features/product/domain/entities/product.dart';
import '../../features/shop/domain/entities/shop.dart';
import 'cloud_box.dart';

/// The shop's single source of truth in Firebase Realtime Database.
///
/// For repositories this mirrors the old `HiveDatabase` API one-to-one:
/// same box names, same getters (`values/get/put/delete/...`), so the only
/// change in a repository is the class it imports. Everything lives under
/// `/shops/{shopId}/<boxName>`; each box keeps a live in-memory mirror
/// (RTDB caches to disk, so the till works offline and syncs later).
class CloudDatabase {
  CloudDatabase._();

  static FirebaseDatabase get _db => FirebaseDatabase.instance;

  static String? _shopId;

  /// The shop the signed-in user belongs to (null = not attached yet).
  static String? get shopId => _shopId;

  /// Enables disk persistence so the app keeps working without a network.
  /// Call once, right after Firebase.initializeApp, before any other use.
  static Future<void> enableOfflinePersistence() async {
    try {
      _db.setPersistenceEnabled(true);
      _db.setPersistenceCacheSizeBytes(100 * 1024 * 1024); // 100 MB cap
    } catch (_) {
      // Persistence must never block startup.
    }
  }

  // -------------------------------------------------------------- boxes
  //
  // Names intentionally identical to the legacy Hive boxes.

  static final CloudBox<Product> productBox = CloudBox<Product>(
    name: 'products',
    encode: (p) => p.toMap(),
    decode: (raw) => Product.fromMap(raw is Map ? raw : const {}),
  );

  static final CloudBox<Shop> shopBox = CloudBox<Shop>(
    name: 'shop',
    encode: (s) => s.toMap(),
    decode: (raw) => Shop.fromMap(raw is Map ? raw : const {}),
  );

  /// Key-value preferences (language, currency, counters, PIN hash…):
  /// values are scalars, so the box is dynamic.
  static final CloudBox<dynamic> settingsBox = CloudBox<dynamic>(
    name: 'settings',
    encode: (v) => v,
    decode: (raw) => raw,
  );

  static final CloudBox<Map> salesBox = _mapBox('sales');
  static final CloudBox<Map> customersBox = _mapBox('customers');
  static final CloudBox<Map> expensesBox = _mapBox('expenses');
  static final CloudBox<Map> purchasesBox = _mapBox('purchases');
  static final CloudBox<Map> stockMovementsBox = _mapBox('stock_movements');
  static final CloudBox<Map> heldCartsBox = _mapBox('held_carts');
  static final CloudBox<Map> shiftsBox = _mapBox('shifts');
  static final CloudBox<Map> promotionsBox = _mapBox('promotions');

  /// Delivery orders (/shops/{shopId}/deliveries) — one live row per order,
  /// watched simultaneously by the till, the admin tracker and the
  /// deliverer's phone.
  static final CloudBox<Map> deliveriesBox = _mapBox('deliveries');

  /// Money the shop hands to its deliverers (/shops/{shopId}/delivery_payouts).
  static final CloudBox<Map> deliveryPayoutsBox = _mapBox('delivery_payouts');

  /// Shop members (/shops/{shopId}/members) — the users of legacy Hive now
  /// live cloud-side too (name/role/active per member; secrets stay in
  /// Firebase Auth, never in the database).
  static final CloudBox<Map> usersBox = _mapBox('members');

  static CloudBox<Map> _mapBox(String name) => CloudBox<Map>(
        name: name,
        encode: (m) => Map<String, dynamic>.from(m),
        decode: (raw) => raw is Map ? raw : const <String, dynamic>{},
      );

  static List<CloudBox<dynamic>> get _all => [
        productBox,
        shopBox,
        settingsBox,
        salesBox,
        customersBox,
        expensesBox,
        purchasesBox,
        stockMovementsBox,
        heldCartsBox,
        shiftsBox,
        promotionsBox,
        deliveriesBox,
        deliveryPayoutsBox,
        usersBox,
      ];

  // ------------------------------------------------------------ binding

  /// Attaches every box to this shop's data and waits for the first
  /// snapshots so screens open with real data (offline: disk cache).
  static Future<void> attach(String shopId) async {
    _shopId = shopId;
    for (final box in _all) {
      box.bind(_db.ref('shops/$shopId/${box.name}'));
    }
    // First-load barrier, per box, all in parallel.
    await Future.wait(_all.map((b) => b.ready()));
  }

  /// One-time self-healing sweep: builds earlier than the shopId fix wrote
  /// every box to a stray top-level path (`shops/<box>` instead of
  /// `shops/<shopId>/<box>`) because the member profile carried an empty
  /// shopId. Anything missing under the real shop is copied across (never
  /// overwriting fresher rows), broken member enrollments get their users
  /// row repaired, and the stray nodes are removed. Idempotent — a flag
  /// under meta prevents repeats.
  static Future<void> migrateLegacyRootData(String shopId) async {
    if (shopId.isEmpty) return;
    try {
      final flagRef = _db.ref('shops/$shopId/meta/legacy_swept_at');
      final flag = await flagRef.get();
      if (flag.exists) return;
      for (final box in _all) {
        final legacy = _db.ref('shops/${box.name}');
        final snap = await legacy.get();
        final v = snap.value;
        if (v is! Map) continue;
        final target = _db.ref('shops/$shopId/${box.name}');
        final cur = await target.get();
        final cv = cur.value is Map ? (cur.value as Map) : const {};
        final updates = <String, dynamic>{};
        for (final e in v.entries) {
          if (!cv.containsKey(e.key)) {
            updates['shops/$shopId/${box.name}/${e.key}'] = e.value;
          }
        }
        if (updates.isNotEmpty) {
          await _db.ref().update(updates);
        }
        // Repair workers created while the bug was live: their users row
        // pointed at an empty shop, which is what trapped them on the
        // "waiting for approval" screen.
        if (box.name == 'members') {
          for (final e in v.entries) {
            final uid = e.key as String?;
            final row = e.value;
            if (uid == null || row is! Map) continue;
            final userSnap = await userProfile(uid).get();
            final uv = userSnap.value;
            final needs = !userSnap.exists ||
                uv is! Map ||
                ((uv['shopId'] as String?) ?? '').isEmpty;
            if (needs) {
              await userProfile(uid).set({
                'name': row['name'] ?? '',
                'email': row['email'] ?? '',
                'shopId': shopId,
                'createdAt': ServerValue.timestamp,
              });
            }
          }
        }
        await legacy.remove();
      }
      await flagRef.set(ServerValue.timestamp);
    } catch (_) {
      // Never block sign-in for housekeeping; a later sign-in retries.
    }
  }

  /// Drops every live mirror (sign-out / shop switch).
  static void detach() {
    _shopId = null;
    for (final box in _all) {
      box.unbindSync();
    }
  }

  // ------------------------------------------------- raw path helpers

  /// /shops/{shopId}/{boxName} — raw path helper (box getters keep the
  /// Hive-style no-arg names like [salesBox]).
  static DatabaseReference ref(String shopId, String boxName) =>
      _db.ref('shops/$shopId/$boxName');

  /// /users/{uid} — the small routing record for a user profile.
  static DatabaseReference userProfile(String uid) => _db.ref('users/$uid');

  /// Creates/merges a user profile sliver (never wipes other fields).
  static Future<void> putUserProfile(
          String uid, Map<String, dynamic> profile) =>
      userProfile(uid).update(profile);

  /// /shops/{shopId}
  static DatabaseReference shop(String shopId) => _db.ref('shops/$shopId');

  /// /shops/{shopId}/members/{uid} → role/status of a member.
  static DatabaseReference shopMember(String shopId, String uid) =>
      _db.ref('shops/$shopId/members/$uid');

  /// /shop_codes/{code} → shopId (join-by-code index).
  static DatabaseReference shopCode(String code) =>
      _db.ref('shop_codes/$code');

  /// Atomically increments a per-shop counter (invoice numbers, …).
  /// Returns the new value. Works offline by queueing; [fallback] is only
  /// used when the transaction result is unavailable offline.
  static Future<int> nextCounter(String name, {int fallback = 1}) async {
    final shopId = _shopId;
    if (shopId == null) return fallback;
    final ref = _db.ref('shops/$shopId/counters/$name');
    try {
      final result = await ref.runTransaction((value) {
        final next = ((value as num?)?.toInt() ?? 0) + 1;
        return Transaction.success(next);
      });
      final v = (result.snapshot.value as num?)?.toInt();
      return v ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
