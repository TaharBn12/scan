import 'dart:async';

import '../data/hive_database.dart';
import 'cloud_database.dart';

/// One-shot import of the legacy local (Hive) data into the shop's cloud
/// collections. Runs automatically the first time a freshly-bootstrapped
/// shop attaches with empty collections while local data still exists —
/// upgrading devices keep their whole history without any user action.
class CloudMigrator {
  CloudMigrator._();

  static bool _ran = false;

  static Future<void> migrateLocalDataOnce() async {
    if (_ran) return;
    _ran = true;
    final shopId = CloudDatabase.shopId;
    if (shopId == null) return;
    try {
      // Already migrated before (flag stored in the cloud settings)?
      final settingsSnap = await CloudDatabase.ref(shopId, 'settings')
          .child('migrated_from_hive_at')
          .get();
      if (settingsSnap.exists) return;

      // Only migrate into an EMPTY shop, and only when local data exists.
      if (CloudDatabase.productBox.isNotEmpty ||
          CloudDatabase.salesBox.isNotEmpty) {
        return; // cloud already has data — nothing to do
      }
      final localProducts = HiveDatabase.productBox;
      if (localProducts.isEmpty) return; // brand new shop, nothing local

      final payload = <String, dynamic>{};
      for (final p in localProducts.values) {
        payload['products/${p.id}'] = p.toMap();
      }
      final shop = HiveDatabase.shopBox.get('current');
      if (shop != null) payload['shop/current'] = shop.toMap();
      for (final box in HiveDatabase.salesBox.toMap().entries) {
        payload['sales/${box.key}'] = _safe(box.value);
      }
      for (final e in HiveDatabase.customersBox.toMap().entries) {
        payload['customers/${e.key}'] = _safe(e.value);
      }
      for (final e in HiveDatabase.expensesBox.toMap().entries) {
        payload['expenses/${e.key}'] = _safe(e.value);
      }
      for (final e in HiveDatabase.purchasesBox.toMap().entries) {
        payload['purchases/${e.key}'] = _safe(e.value);
      }
      for (final e in HiveDatabase.stockMovementsBox.toMap().entries) {
        payload['stock_movements/${e.key}'] = _safe(e.value);
      }
      for (final e in HiveDatabase.promotionsBox.toMap().entries) {
        payload['promotions/${e.key}'] = _safe(e.value);
      }
      for (final e in HiveDatabase.heldCartsBox.toMap().entries) {
        payload['held_carts/${e.key}'] = _safe(e.value);
      }
      for (final e in HiveDatabase.shiftsBox.toMap().entries) {
        payload['shifts/${e.key}'] = _safe(e.value);
      }
      payload['settings/migrated_from_hive_at'] =
          DateTime.now().toIso8601String();

      await CloudDatabase.shop(shopId).update(payload);
    } catch (_) {
      // Best effort: a failed migration never blocks sign-in. It will retry
      // naturally on the next successful attach since the flag isn't set.
    }
  }

  /// Hive boxes contain [Map<dynamic, dynamic>] with non-string keys at
  /// nested levels; RTDB wants JSON-shaped maps with string keys.
  static dynamic _safe(dynamic value) {
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) => out['$k'] = _safe(v));
      return out;
    }
    if (value is List) return value.map(_safe).toList();
    return value;
  }
}
