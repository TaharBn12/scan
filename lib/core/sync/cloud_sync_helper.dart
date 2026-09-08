import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../features/product/domain/entities/product.dart';
import '../data/hive_database.dart';
import '../utils/sync_helper.dart';
import 'firebase_config_helper.dart';
import 'sync_queue.dart';

/// Cloud sync engine: pushes the shared outbox ([SyncQueue]) to Cloud
/// Firestore and pulls product changes back down.
///
/// This is a second transport next to the merchant-website sync
/// ([SyncHelper]); both drain the same outbox so the app's data can be
/// mirrored to the shop's own Firebase project, which the live web
/// dashboard (`web-dashboard/`) reads in real time.
///
/// Firestore layout (document id = record id, same maps the website sync
/// uses):
/// ```
/// products/{id}         full product map, incl. updatedAt
/// sales/{id}            full sale map
/// customers/{id}        full customer map
/// expenses/{id}         full expense map
/// purchases/{id}        full purchase map
/// stock_movements/{id}  full stock movement map
/// meta/shop             shop info + currency (dashboard header)
/// ```
class CloudSyncHelper {
  CloudSyncHelper._();

  static const _configKey = 'cloud_firebase_config';
  static const _projectIdKey = 'cloud_project_id';
  static const _dashboardUrlKey = 'cloud_dashboard_url';
  static const _autoKey = 'cloud_auto_sync';
  static const _lastSyncKey = 'cloud_last_sync_at';

  /// Project id of the app instance we initialized, to detect config
  /// changes at runtime.
  static String? _initializedProjectId;

  // ----------------------------------------------------------- settings

  static bool hasConfig() =>
      (HiveDatabase.settingsBox.get(_configKey) as String?)?.isNotEmpty ??
      false;

  static String? configJson() =>
      HiveDatabase.settingsBox.get(_configKey) as String?;

  static String? projectId() {
    final fromBox = HiveDatabase.settingsBox.get(_projectIdKey) as String?;
    if (fromBox != null && fromBox.isNotEmpty) return fromBox;
    final json = configJson();
    if (json == null) return null;
    return FirebaseAppConfig.parse(json).projectId;
  }

  /// Validates [raw], stores it and (re)initializes the Firebase app so a
  /// changed project takes effect immediately.
  /// Throws [FormatException] when [raw] is not a usable config.
  static Future<void> saveConfig(String raw) async {
    final config = FirebaseAppConfig.parse(raw.trim());
    final box = HiveDatabase.settingsBox;
    await box.put(_configKey, raw.trim());
    await box.put(_projectIdKey, config.projectId);
    await _ensureInitialized(force: true);
  }

  static bool isAutoSyncEnabled() =>
      HiveDatabase.settingsBox.get(_autoKey) as bool? ?? false;

  static Future<void> setAutoSyncEnabled(bool value) async {
    await HiveDatabase.settingsBox.put(_autoKey, value);
  }

  static String? dashboardUrl() =>
      HiveDatabase.settingsBox.get(_dashboardUrlKey) as String?;

  static Future<void> setDashboardUrl(String url) async {
    await HiveDatabase.settingsBox.put(_dashboardUrlKey, url.trim());
  }

  static DateTime? lastSyncAt() {
    final raw = HiveDatabase.settingsBox.get(_lastSyncKey) as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// The website/cloud sync share one outbox, so this is the number of
  /// local changes still waiting for the cloud.
  static int get pendingCount => SyncQueue.length;

  // --------------------------------------------------------- lifecycle

  static Future<void> _ensureInitialized({bool force = false}) async {
    final json = configJson();
    if (json == null) {
      throw StateError('no firebase config saved');
    }
    final config = FirebaseAppConfig.parse(json);
    if (!force &&
        _initializedProjectId == config.projectId &&
        Firebase.apps.isNotEmpty) {
      return;
    }
    // (Re)create the app instance so a changed project takes effect.
    for (final app in Firebase.apps) {
      await app.delete();
    }
    await Firebase.initializeApp(options: config.toOptions());
    _initializedProjectId = config.projectId;
  }

  // ------------------------------------------------------------ sync run

  /// Pushes every queued change to Firestore, then pulls the most recently
  /// updated products back (last-write-wins, same policy as the website
  /// sync). Never throws.
  static Future<SyncResult> syncAll() async {
    if (!hasConfig()) {
      return const SyncResult(ok: false, error: 'no_config');
    }
    try {
      await _ensureInitialized();
    } catch (e) {
      return SyncResult(ok: false, error: e.toString());
    }
    try {
      final db = FirebaseFirestore.instance;
      final pushed = await _push(db);
      final pulled = await _pullProducts(db);
      await HiveDatabase.settingsBox
          .put(_lastSyncKey, DateTime.now().toIso8601String());
      return SyncResult(ok: true, pushed: pushed, pulledProducts: pulled);
    } catch (e) {
      return SyncResult(ok: false, error: e.toString());
    }
  }

  /// Called after a sale is saved when cloud auto-sync is on. Never
  /// throws, never blocks the UI (callers don't await).
  static Future<void> autoSync() async {
    if (!isAutoSyncEnabled() || !hasConfig()) return;
    try {
      await syncAll();
    } catch (_) {}
  }

  // -------------------------------------------------------------- push

  static const _collectionFor = {
    'product': 'products',
    'sale': 'sales',
    'customer': 'customers',
    'expense': 'expenses',
    'purchase': 'purchases',
    'stock_movement': 'stock_movements',
  };

  static Future<int> _push(FirebaseFirestore db) async {
    final pending = SyncQueue.pending();
    int done = 0;
    if (pending.isNotEmpty) {
      final now = DateTime.now().toUtc().toIso8601String();
      // WriteBatch allows at most 500 operations; 200 keeps payloads small.
      for (int i = 0; i < pending.length; i += 200) {
        final end = i + 200 > pending.length ? pending.length : i + 200;
        final items = pending.sublist(i, end);
        final batch = db.batch();
        for (final item in items) {
          final entity = item['entity'] as String;
          final id = item['id'] as String;
          final collection = _collectionFor[entity];
          if (collection == null) continue;
          final ref = db.collection(collection).doc(id);
          if (item['op'] == SyncQueue.opDelete) {
            batch.delete(ref);
          } else {
            final data = SyncHelper.dataFor(entity, id);
            if (data == null) {
              // The record vanished locally: mirror that in the cloud.
              batch.delete(ref);
            } else {
              final docData = Map<String, dynamic>.from(data);
              docData['syncedAt'] = now;
              batch.set(ref, docData);
            }
          }
        }
        await batch.commit();
        for (final item in items) {
          await SyncQueue.remove(
              item['entity'] as String, item['id'] as String);
        }
        done += items.length;
      }
    }
    await _pushShop(db);
    return done;
  }

  /// Keeps the dashboard header fresh: shop info + currency symbol.
  static Future<void> _pushShop(FirebaseFirestore db) async {
    try {
      final shopBox = HiveDatabase.shopBox;
      final shopMap = shopBox.values.isNotEmpty
          ? Map<String, dynamic>.from(shopBox.values.first.toMap())
          : <String, dynamic>{};
      await db.collection('meta').doc('shop').set({
        ...shopMap,
        'currencySymbol':
            HiveDatabase.settingsBox.get('currency_symbol') as String? ??
                'DA',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Cosmetic for the dashboard; never fail the whole sync over it.
    }
  }

  // -------------------------------------------------------------- pull

  static Future<int> _pullProducts(FirebaseFirestore db) async {
    // Most recently updated products first (max 1000 per query) — enough for
    // small/medium shops, and new products are always fresh.
    final snapshot = await db
        .collection('products')
        .orderBy('updatedAt', descending: true)
        .limit(1000)
        .get();
    final box = HiveDatabase.productBox;
    int count = 0;
    for (final doc in snapshot.docs) {
      final raw = doc.data();
      if (raw['id'] == null) raw['id'] = doc.id;
      final map = Map<String, dynamic>.from(raw);
      if ((map['id'] as String?)?.isEmpty ?? true) continue;
      final remote = Product.fromMap(map);
      final local = box.get(remote.id);
      // Last-write-wins on updatedAt; local edits made after the cloud's
      // version are kept (and will be pushed on the next run).
      if (local != null &&
          local.updatedAt != null &&
          remote.updatedAt != null &&
          local.updatedAt!.isAfter(remote.updatedAt!)) {
        continue;
      }
      await box.put(remote.id, remote);
      // Don't echo the change straight back to the cloud.
      await SyncQueue.remove('product', remote.id);
      count++;
    }
    return count;
  }
}
