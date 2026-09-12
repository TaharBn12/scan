import 'package:fpdart/fpdart.dart';

import '../../../core/cloud/cloud_database.dart';
import '../../../core/error/failure.dart';
import '../../product/domain/entities/product.dart';
import '../domain/entities/store_order.dart';
import '../domain/entities/store_product.dart';
import 'repositories/store_catalog_repository.dart';

/// Why a POS product would (re)publish to the site.
enum SyncReason { missing, priceChanged, stockChanged, renamed, identical }

extension SyncReasonX on SyncReason {
  String get labelKey => 'sync_reason_$name';
  bool get needsPush => this != SyncReason.identical;
}

/// One row of the sync preview: a POS product and what the site holds.
class SyncRow {
  final Product pos;
  final StoreProduct? listing;
  final SyncReason reason;

  const SyncRow({required this.pos, required this.listing, required this.reason});

  String get id => pos.id;
}

/// The bridge between the till and the website.
///
/// **The join key is the product id**: a listing published from the POS keeps
/// the very same id, so a web order's `product_id` points straight at the POS
/// product. That single decision is what lets a delivery on the site decrement
/// the shop's real shelf stock, and what keeps the two catalogues from
/// drifting into "the same thing under two names".
class StoreSyncService {
  StoreSyncService({StoreCatalogRepository? catalog})
      : _catalog = catalog ?? StoreCatalogRepository();

  final StoreCatalogRepository _catalog;

  /// Compares the shelf with the site.
  Future<Either<Failure, List<SyncRow>>> preview() async {
    final listings =
        await _catalog.listProducts(includeUnpublished: true, limit: 2000);
    return listings.fold(
      (failure) => Left(failure),
      (rows) {
        final byId = {for (final l in rows) l.id: l};
        final shelf = CloudDatabase.productBox.values.toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return Right(shelf.map((p) {
          final listing = byId[p.id] ?? byId[p.barcode];
          return SyncRow(
            pos: p,
            listing: listing,
            reason: _compare(p, listing),
          );
        }).toList());
      },
    );
  }

  SyncReason _compare(Product pos, StoreProduct? listing) {
    if (listing == null) return SyncReason.missing;
    if ((listing.price - pos.price).abs() > 0.001) return SyncReason.priceChanged;
    if (pos.trackStock && (listing.stock - pos.stock).abs() > 0.001) {
      return SyncReason.stockChanged;
    }
    if (listing.name.trim() != pos.name.trim()) return SyncReason.renamed;
    return SyncReason.identical;
  }

  /// Turns a shelf product into a storefront listing.
  ///
  /// Images, description and category are *kept* when the listing already
  /// exists — the merchant writes those on the site side, and a sync must
  /// never wipe his copy. Only price, stock, barcode and name flow over.
  StoreProduct toListing(Product pos, {StoreProduct? existing}) {
    final base = existing;
    return StoreProduct(
      id: pos.id,
      name: pos.name,
      nameAr: base?.nameAr ?? '',
      nameFr: base?.nameFr ?? '',
      slug: base?.slug ?? '',
      description: base?.description ?? '',
      descriptionAr: base?.descriptionAr ?? '',
      price: pos.price,
      compareAtPrice: base?.compareAtPrice ?? 0,
      costPrice: pos.costPrice,
      stock: pos.trackStock ? pos.stock : 0,
      sku: base?.sku ?? pos.barcode,
      barcode: pos.barcode,
      categoryId: base?.categoryId ?? '',
      images: base?.images ?? const [],
      published: base?.published ?? false,
      featured: base?.featured ?? false,
      rating: base?.rating ?? 0,
      soldCount: base?.soldCount ?? 0,
      unit: pos.unit.name,
    );
  }

  /// Pushes [rows] to the site. Returns how many listings were written.
  Future<Either<Failure, int>> push(List<SyncRow> rows) async {
    var written = 0;
    for (final row in rows) {
      if (!row.reason.needsPush) continue;
      final result =
          await _catalog.saveProduct(toListing(row.pos, existing: row.listing));
      final ok = result.fold((_) => false, (_) => true);
      if (!ok) {
        return result.fold<Either<Failure, int>>((f) => Left(f), (_) => Right(written));
      }
      written++;
    }
    return Right(written);
  }

  /// Publishes a single product from the product form ("show on website").
  Future<Either<Failure, void>> publish(Product pos, {bool featured = false}) {
    return _catalog.saveProduct(
      toListing(pos).copyWith(published: true, featured: featured),
    );
  }

  /// Takes a product off the site without deleting its listing (its reviews
  /// and order history stay).
  Future<Either<Failure, void>> unpublish(String productId) =>
      _catalog.setPublished([productId], false);

  /// Removes a web order's items from the shelf once it is delivered, so the
  /// counter and the site never sell the same unit twice.
  Future<int> deductStock(StoreOrder order) async {
    final box = CloudDatabase.productBox;
    var touched = 0;
    for (final item in order.items) {
      final product = box.get(item.productId);
      if (product == null || !product.trackStock) continue;
      final next = (product.stock - item.quantity).clamp(0, double.infinity);
      await box.put(product.id, product.copyWith(stock: next.toDouble()));
      touched++;
    }
    return touched;
  }

  /// Restores stock when a delivered order is cancelled or refunded.
  Future<int> restoreStock(StoreOrder order) async {
    final box = CloudDatabase.productBox;
    var touched = 0;
    for (final item in order.items) {
      final product = box.get(item.productId);
      if (product == null || !product.trackStock) continue;
      await box.put(product.id, product.copyWith(stock: product.stock + item.quantity));
      touched++;
    }
    return touched;
  }
}
