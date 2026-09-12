import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/supabase/store_schema.dart';
import '../../domain/entities/store_coupon.dart';
import 'store_repository_base.dart';

/// Discount codes: the shopper's "apply code" box and the merchant's list.
class StoreMarketingRepository with StoreRepositoryBase {
  Future<Either<Failure, List<StoreCoupon>>> listCoupons({bool activeOnly = false}) {
    return guard((client) async {
      var builder = client.from(StoreSchema.coupons).select('*');
      if (activeOnly) builder = builder.eq(StoreColumns.active, true);
      final rows = await builder.order(StoreColumns.createdAt, ascending: false);
      return rows.map((r) => StoreCoupon.fromMap(Map<String, dynamic>.from(r))).toList();
    });
  }

  /// Validates a code typed at checkout and returns it when it applies.
  Future<Either<Failure, StoreCoupon?>> validate(String code) {
    return guard((client) async {
      final row = await client
          .from(StoreSchema.coupons)
          .select('*')
          .ilike(StoreColumns.code, code.trim())
          .maybeSingle();
      if (row == null) return null;
      final coupon = StoreCoupon.fromMap(Map<String, dynamic>.from(row));
      return coupon.isUsable ? coupon : null;
    });
  }

  Future<Either<Failure, void>> saveCoupon(StoreCoupon coupon) {
    return guard((client) async {
      await upsert(client, StoreSchema.coupons, coupon.toMap());
    });
  }

  Future<Either<Failure, void>> setActive(String id, bool active) {
    return guard((client) async {
      await client
          .from(StoreSchema.coupons)
          .update({StoreColumns.active: active})
          .eq(StoreColumns.id, id);
    });
  }

  /// Burns one use of a code once an order carrying it is confirmed.
  Future<Either<Failure, void>> consume(StoreCoupon coupon) {
    return guard((client) async {
      await client
          .from(StoreSchema.coupons)
          .update({StoreColumns.usedCount: coupon.usedCount + 1})
          .eq(StoreColumns.id, coupon.id);
    });
  }

  Future<Either<Failure, void>> deleteCoupon(String id) {
    return guard((client) async {
      await client.from(StoreSchema.coupons).delete().eq(StoreColumns.id, id);
    });
  }
}
