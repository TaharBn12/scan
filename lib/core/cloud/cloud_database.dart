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
    decode: (raw) => Product.fromMap(raw),
  );

  static final CloudBox<Shop> shopBox = CloudBox<Shop>(
    name: 'shop',
    encode: (s) => s.toMap(),
    decode: (raw) => Shop.fromMap(raw),
  );

  static final CloudBox<Map> settingsBox = _mapBox('settings');
  static final CloudBox<Map> salesBox = _mapBox('sales');
  static final CloudBox<Map> customersBox = _mapBox('customers');
  static final CloudBox<Map> expensesBox = _mapBox('expenses');
  static final CloudBox<Map> purchasesBox = _mapBox('purchases');
  static final CloudBox<Map> stockMovementsBox = _mapBox('stock_movements');
  static final CloudBox<Map> heldCartsBox = _mapBox('held_carts');
  static final CloudBox<Map> shiftsBox = _mapBox('shifts');
  static final CloudBox<Map> promotionsBox = _mapBox('promotions');

  /// Shop members (/shops/{shopId}/members) — the users of legacy Hive now
  /// live cloud-side too (name/role/active per member; secrets stay in
  /// Firebase Auth, never in the database).
  static final CloudBox<Map> usersBox = _mapBox('members');

  static CloudBox<Map> _mapBox(String name) => CloudBox<Map>(
        name: name,
        encode: (m) => Map<String, dynamic>.from(m),
        decode: (raw) => raw,
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
