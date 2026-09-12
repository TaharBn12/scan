import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/supabase/row_reader.dart';
import '../../../../core/supabase/store_schema.dart';
import '../../domain/entities/store_settings.dart';
import 'store_repository_base.dart';

/// Store-wide switches and the delivery zones the checkout prices with.
class StoreSettingsRepository with StoreRepositoryBase {
  /// The single settings row, or the defaults when the schema has none.
  Future<Either<Failure, StoreSettings>> getSettings() {
    return guard((client) async {
      // `store_settings` is keyed by `user_id`, one row per merchant.
      var query = client.from(StoreSchema.settings).select('*');
      final owner = merchantId;
      if (owner != null) query = query.eq(StoreColumns.userId, owner);
      final row = await query.limit(1).maybeSingle();
      if (row == null) return const StoreSettings();
      return StoreSettings.fromMap(Map<String, dynamic>.from(row));
    });
  }

  Future<Either<Failure, void>> saveSettings(StoreSettings settings) {
    return guard((client) async {
      // Upsert on `user_id`: that column is the primary key, not `id`.
      final owner = merchantId;
      final payload = owner == null
          ? settings.toMap()
          : {StoreColumns.userId: owner, ...settings.toMap()};
      await client.from(StoreSchema.settings).upsert(
            payload,
            onConflict: StoreColumns.userId,
            ignoreDuplicates: false,
          );
    });
  }

  // -------------------------------------------------------- shipping zones

  /// The site's real price list: one row per wilaya, two prices each.
  Future<Either<Failure, List<StoreShippingRate>>> listShippingRates() {
    return guard((client) async {
      final rows = await client
          .from(StoreSchema.shippingZones)
          .select('*')
          .eq(StoreColumns.isActive, true)
          .order(StoreColumns.wilayaCode, ascending: true);
      return rows
          .map((r) => StoreShippingRate.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    });
  }

  /// The fee for one wilaya and one drop-off kind — what checkout needs.
  Future<Either<Failure, double>> shippingFeeFor({
    required String wilaya,
    String shippingType = StoreColumns.shippingHome,
  }) {
    return guard((client) async {
      final rate = await _rateFor(client, wilaya);
      return rate?.priceFor(shippingType) ?? 0;
    });
  }

  Future<StoreShippingRate?> _rateFor(dynamic client, String wilaya) async {
    final needle = wilaya.trim();
    if (needle.isEmpty) return null;
    // The site stores the wilaya as its Arabic name on the order, and as a
    // code + name in shipping_rates, so match on either.
    final asCode = int.tryParse(needle);
    var query = client.from(StoreSchema.shippingZones).select('*');
    query = asCode != null
        ? query.eq(StoreColumns.wilayaCode, asCode)
        : query.eq(StoreColumns.wilayaName, needle);
    final row = await query.maybeSingle();
    if (row == null) return null;
    return StoreShippingRate.fromMap(Map<String, dynamic>.from(row));
  }

  /// Kept for the generic zone UI: `shipping_rates` has no free-shipping
  /// threshold or transit days, so those come back as their defaults.
  Future<Either<Failure, List<StoreShippingOption>>> listShippingZones() {
    return guard((client) async {
      final rows = await client
          .from(StoreSchema.shippingZones)
          .select('*')
          .eq(StoreColumns.isActive, true)
          .order(StoreColumns.wilayaCode, ascending: true);
      return rows.map((r) {
        final map = Map<String, dynamic>.from(r);
        return StoreShippingOption(
          id: Row.str(map, StoreColumns.id),
          name: Row.str(map, StoreColumns.wilayaName),
          fee: Row.num_(map, StoreColumns.priceHome),
          active: Row.bool_(map, StoreColumns.isActive, true),
        );
      }).toList();
    });
  }

  Future<Either<Failure, void>> saveShippingZone(StoreShippingOption zone) {
    return guard((client) async {
      // `shipping_rates` is keyed by wilaya_code, so upsert on that.
      await client.from(StoreSchema.shippingZones).upsert(
            zone.toMap(),
            onConflict: StoreColumns.wilayaCode,
            ignoreDuplicates: false,
          );
    });
  }

  Future<Either<Failure, void>> deleteShippingZone(String id) {
    return guard((client) async {
      await client.from(StoreSchema.shippingZones).delete().eq(StoreColumns.id, id);
    });
  }

  /// Every table this module touches and whether it exists in the project —
  /// the connection screen's health panel.
  Future<Either<Failure, Map<String, bool>>> schemaHealth() {
    return guard((client) async {
      final report = <String, bool>{};
      for (final table in StoreSchema.all) {
        try {
          await client.from(table).select('*').limit(1);
          report[table] = true;
        } catch (_) {
          report[table] = false;
        }
      }
      return report;
    });
  }
}
