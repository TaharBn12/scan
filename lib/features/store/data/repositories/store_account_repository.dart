import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/supabase/store_schema.dart';
import '../../domain/entities/store_customer.dart';
import '../../domain/entities/store_review.dart';
import 'store_repository_base.dart';

/// Shopper-side account data: saved addresses, wishlist, reviews.
class StoreAccountRepository with StoreRepositoryBase {
  // ------------------------------------------------------------ addresses

  Future<Either<Failure, List<StoreAddress>>> listAddresses(String customerId) {
    return guard((client) async {
      final rows = await client
          .from(StoreSchema.addresses)
          .select('*')
          .eq(StoreColumns.customerId_, customerId);
      return rows.map((r) => StoreAddress.fromMap(Map<String, dynamic>.from(r))).toList()
        ..sort((a, b) => (b.isDefault ? 1 : 0).compareTo(a.isDefault ? 1 : 0));
    });
  }

  Future<Either<Failure, void>> saveAddress(StoreAddress address) {
    return guard((client) async {
      await upsert(client, StoreSchema.addresses, address.toMap());
      // Only one address may be the default.
      if (address.isDefault) {
        await client
            .from(StoreSchema.addresses)
            .update({StoreColumns.isDefault: false})
            .eq(StoreColumns.customerId_, address.customerId)
            .neq(StoreColumns.id, address.id);
      }
    });
  }

  Future<Either<Failure, void>> deleteAddress(String id) {
    return guard((client) async {
      await client.from(StoreSchema.addresses).delete().eq(StoreColumns.id, id);
    });
  }

  // ------------------------------------------------------------- wishlist

  Future<Either<Failure, List<String>>> wishlist(String customerId) {
    return guard((client) async {
      final rows = await client
          .from(StoreSchema.wishlists)
          .select(StoreColumns.productId)
          .eq(StoreColumns.customerId_, customerId);
      return rows
          .map((r) => (r[StoreColumns.productId] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
    });
  }

  Future<Either<Failure, bool>> toggleWishlist({
    required String customerId,
    required String productId,
  }) {
    return guard((client) async {
      final existing = await client
          .from(StoreSchema.wishlists)
          .select(StoreColumns.id)
          .eq(StoreColumns.customerId_, customerId)
          .eq(StoreColumns.productId, productId)
          .maybeSingle();
      if (existing != null) {
        await client
            .from(StoreSchema.wishlists)
            .delete()
            .eq(StoreColumns.id, existing[StoreColumns.id]);
        return false;
      }
      await client.from(StoreSchema.wishlists).insert({
        StoreColumns.customerId_: customerId,
        StoreColumns.productId: productId,
        StoreColumns.createdAt: DateTime.now().toIso8601String(),
      });
      return true;
    });
  }

  // -------------------------------------------------------------- reviews

  Future<Either<Failure, List<StoreReview>>> productReviews(String productId) {
    return guard((client) async {
      final rows = await client
          .from(StoreSchema.reviews)
          .select('*')
          .eq(StoreColumns.productId, productId)
          .eq(StoreColumns.approved, true)
          .order(StoreColumns.createdAt, ascending: false);
      return rows.map((r) => StoreReview.fromMap(Map<String, dynamic>.from(r))).toList();
    });
  }

  /// The moderation queue.
  Future<Either<Failure, List<StoreReview>>> pendingReviews() {
    return guard((client) async {
      final rows = await client
          .from(StoreSchema.reviews)
          .select('*')
          .eq(StoreColumns.approved, false)
          .order(StoreColumns.createdAt, ascending: false);
      return rows.map((r) => StoreReview.fromMap(Map<String, dynamic>.from(r))).toList();
    });
  }

  Future<Either<Failure, List<StoreReview>>> allReviews() {
    return guard((client) async {
      final rows = await client
          .from(StoreSchema.reviews)
          .select('*')
          .order(StoreColumns.createdAt, ascending: false)
          .limit(200);
      return rows.map((r) => StoreReview.fromMap(Map<String, dynamic>.from(r))).toList();
    });
  }

  Future<Either<Failure, void>> setApproved(String reviewId, bool approved) {
    return guard((client) async {
      await client
          .from(StoreSchema.reviews)
          .update({StoreColumns.approved: approved})
          .eq(StoreColumns.id, reviewId);
    });
  }

  Future<Either<Failure, void>> deleteReview(String reviewId) {
    return guard((client) async {
      await client.from(StoreSchema.reviews).delete().eq(StoreColumns.id, reviewId);
    });
  }

  Future<Either<Failure, void>> submitReview(StoreReview review) {
    return guard((client) async {
      await client.from(StoreSchema.reviews).insert(review.toMap());
    });
  }

  // ------------------------------------------------------------ customers

  /// Registered shoppers with their order count and spend, for the CRM.
  Future<Either<Failure, List<StoreCustomer>>> listCustomers() {
    return guard((client) async {
      final rows = await client
          .from(StoreSchema.customers)
          .select('*')
          .order(StoreColumns.createdAt, ascending: false)
          .limit(300);
      return rows.map((r) => StoreCustomer.fromMap(Map<String, dynamic>.from(r))).toList();
    });
  }
}
