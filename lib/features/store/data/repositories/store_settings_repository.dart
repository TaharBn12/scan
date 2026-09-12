import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/supabase/store_schema.dart';
import '../../domain/entities/store_settings.dart';
import 'store_repository_base.dart';

/// Store-wide switches and the delivery zones the checkout prices with.
class StoreSettingsRepository with StoreRepositoryBase {
  /// The single settings row, or the defaults when the schema has none.
  Future<Either<Failure, StoreSettings>> getSettings() {
    return guard((client) async {
      final row =
          await client.from(StoreSchema.settings).select('*').limit(1).maybeSingle();
      if (row == null) return const StoreSettings();
      return StoreSettings.fromMap(Map<String, dynamic>.from(row));
    });
  }

  Future<Either<Failure, void>> saveSettings(StoreSettings settings) {
    return guard((client) async {
      final row = await client.from(StoreSchema.settings).select('id').limit(1).maybeSingle();
      final payload = settings.toMap();
      if (row == null) {
        await client.from(StoreSchema.settings).insert(payload);
      } else {
        await client.from(StoreSchema.settings).update(payload).eq('id', row['id']);
      }
    });
  }

  // -------------------------------------------------------- shipping zones

  Future<Either<Failure, List<StoreShippingOption>>> listShippingZones() {
    return guard((client) async {
      final rows = await client
          .from(StoreSchema.shippingZones)
          .select('*')
          .eq(StoreColumns.active, true)
          .order(StoreColumns.fee, ascending: true);
      return rows
          .map((r) => StoreShippingOption.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    });
  }

  Future<Either<Failure, void>> saveShippingZone(StoreShippingOption zone) {
    return guard((client) async {
      await upsert(client, StoreSchema.shippingZones, zone.toMap());
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
