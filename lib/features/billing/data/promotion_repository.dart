import '../../../core/cloud/cloud_database.dart';
import '../domain/entities/promotion.dart';

/// Offers live in a plain Hive box (maps, like sales) so they ride along in
/// backups without any extra work.
class PromotionRepository {
  List<Promotion> getAll() {
    final promos = CloudDatabase.promotionsBox.values
        .map((raw) => Promotion.fromMap(raw))
        .where((p) => p.id.isNotEmpty)
        .toList();
    // Product offers first so the engine sees the most specific rule first.
    promos.sort((a, b) {
      if (a.targetsProduct != b.targetsProduct) return a.targetsProduct ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return promos;
  }

  /// Offers that could fire right now (used by the till on every cart edit).
  List<Promotion> activeOn(DateTime now) =>
      getAll().where((p) => p.isValidOn(now)).toList();

  Future<void> save(Promotion promo) async {
    await CloudDatabase.promotionsBox.put(promo.id, promo.toMap());
  }

  Future<void> delete(String id) async {
    await CloudDatabase.promotionsBox.delete(id);
  }
}
