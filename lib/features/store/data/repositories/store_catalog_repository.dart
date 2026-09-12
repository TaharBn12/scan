import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/supabase/store_schema.dart';
import '../../domain/entities/store_banner.dart';
import '../../domain/entities/store_category.dart';
import '../../domain/entities/store_product.dart';
import 'store_repository_base.dart';

/// How the catalogue can be sorted on the storefront.
enum StoreSort { newest, priceAsc, priceDesc, bestSelling, rating, name }

extension StoreSortX on StoreSort {
  String get labelKey => 'store_sort_$name';
}

/// Reads and writes the public catalogue: products, categories, banners.
class StoreCatalogRepository with StoreRepositoryBase {
  /// Published products for shoppers.
  ///
  /// [query] filters on name / SKU / barcode; the search box and the category
  /// grid share this one entry point so both stay consistent.
  Future<Either<Failure, List<StoreProduct>>> listProducts({
    String? categoryId,
    String? query,
    bool featuredOnly = false,
    bool onSaleOnly = false,
    bool inStockOnly = false,
    bool includeUnpublished = false,
    StoreSort sort = StoreSort.newest,
    int limit = 60,
    int offset = 0,
  }) {
    return guard((client) async {
      var builder = client.from(StoreSchema.products).select('*');
      if (!includeUnpublished) {
        builder = builder.eq(StoreColumns.published, true);
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        builder = builder.eq(StoreColumns.categoryId, categoryId);
      }
      if (featuredOnly) {
        builder = builder.eq(StoreColumns.featured, true);
      }
      if (onSaleOnly) {
        builder = builder.gt(StoreColumns.compareAtPrice, 0);
      }
      if (inStockOnly) {
        builder = builder.gt(StoreColumns.stock, 0);
      }
      if (query != null && query.trim().isNotEmpty) {
        final needle = query.trim().replaceAll(',', ' ');
        builder = builder.or(
          'name.ilike.%$needle%,sku.ilike.%$needle%,barcode.ilike.%$needle%',
        );
      }
      builder = _ordered(builder, sort).range(offset, offset + limit - 1);
      final rows = await builder;
      return rows.map((r) => StoreProduct.fromMap(Map<String, dynamic>.from(r))).toList();
    });
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _ordered(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> builder,
    StoreSort sort,
  ) {
    switch (sort) {
      case StoreSort.priceAsc:
        return builder.order(StoreColumns.price, ascending: true);
      case StoreSort.priceDesc:
        return builder.order(StoreColumns.price, ascending: false);
      case StoreSort.bestSelling:
        return builder.order(StoreColumns.soldCount, ascending: false);
      case StoreSort.rating:
        return builder.order(StoreColumns.rating, ascending: false);
      case StoreSort.name:
        return builder.order(StoreColumns.name, ascending: true);
      case StoreSort.newest:
        return builder.order(StoreColumns.createdAt, ascending: false);
    }
  }

  Future<Either<Failure, StoreProduct?>> getProduct(String id) {
    return guard((client) async {
      final row = await client
          .from(StoreSchema.products)
          .select('*')
          .eq(StoreColumns.id, id)
          .maybeSingle();
      if (row == null) return null;
      return StoreProduct.fromMap(Map<String, dynamic>.from(row));
    });
  }

  /// Live feed, so a product edited in the admin console updates a shopper's
  /// screen without a pull-to-refresh.
  Stream<List<StoreProduct>> watchProducts({String? categoryId}) {
    if (!isLinked) return const Stream.empty();
    final stream = storeConnection.watch(
      StoreSchema.products,
      filter: categoryId == null ? null : {StoreColumns.categoryId: categoryId},
    );
    return stream.map(
      (rows) => rows.map(StoreProduct.fromMap).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000))),
    );
  }

  // --------------------------------------------------------- categories

  Future<Either<Failure, List<StoreCategory>>> listCategories({
    bool activeOnly = true,
  }) {
    return guard((client) async {
      var builder = client.from(StoreSchema.categories).select('*');
      if (activeOnly) builder = builder.eq(StoreColumns.active, true);
      final rows = await builder.order(StoreColumns.position, ascending: true);
      return rows.map((r) => StoreCategory.fromMap(Map<String, dynamic>.from(r))).toList();
    });
  }

  Future<Either<Failure, void>> saveCategory(StoreCategory category) {
    return guard((client) async {
      await upsert(client, StoreSchema.categories, category.toMap());
    });
  }

  Future<Either<Failure, void>> deleteCategory(String id) {
    return guard((client) async {
      await client.from(StoreSchema.categories).delete().eq(StoreColumns.id, id);
    });
  }

  // ------------------------------------------------------------ banners

  Future<Either<Failure, List<StoreBanner>>> listBanners({bool activeOnly = true}) {
    return guard((client) async {
      var builder = client.from(StoreSchema.banners).select('*');
      if (activeOnly) builder = builder.eq(StoreColumns.active, true);
      final rows = await builder.order(StoreColumns.position, ascending: true);
      return rows.map((r) => StoreBanner.fromMap(Map<String, dynamic>.from(r))).toList();
    });
  }

  Future<Either<Failure, void>> saveBanner(StoreBanner banner) {
    return guard((client) async {
      await upsert(client, StoreSchema.banners, banner.toMap());
    });
  }

  Future<Either<Failure, void>> deleteBanner(String id) {
    return guard((client) async {
      await client.from(StoreSchema.banners).delete().eq(StoreColumns.id, id);
    });
  }

  // ------------------------------------------- admin catalogue mutations

  /// Creates or updates a listing.
  Future<Either<Failure, void>> saveProduct(StoreProduct product) {
    return guard((client) async {
      await upsert(client, StoreSchema.products, product.toMap());
    });
  }

  /// Publishes / unpublishes in bulk (the catalogue screen's multi-select).
  Future<Either<Failure, void>> setPublished(List<String> ids, bool published) {
    return guard((client) async {
      if (ids.isEmpty) return;
      await client
          .from(StoreSchema.products)
          .update({StoreColumns.published: published})
          .inFilter(StoreColumns.id, ids);
    });
  }

  /// Marks products as featured / removes them from the home rail.
  Future<Either<Failure, void>> setFeatured(String id, bool featured) {
    return guard((client) async {
      await client
          .from(StoreSchema.products)
          .update({StoreColumns.featured: featured})
          .eq(StoreColumns.id, id);
    });
  }

  /// Bumps the sold counter after a delivery, so "best sellers" stay honest.
  ///
  /// Read-modify-write rather than an RPC: it works on any schema without
  /// asking the merchant to install a database function first.
  Future<Either<Failure, void>> registerSales(
    List<({String productId, double qty})> lines,
  ) {
    return guard((client) async {
      for (final line in lines) {
        if (line.productId.isEmpty) continue;
        final row = await client
            .from(StoreSchema.products)
            .select(StoreColumns.soldCount)
            .eq(StoreColumns.id, line.productId)
            .maybeSingle();
        final current = (row?[StoreColumns.soldCount] as num?)?.toDouble() ?? 0;
        await client
            .from(StoreSchema.products)
            .update({StoreColumns.soldCount: current + line.qty})
            .eq(StoreColumns.id, line.productId);
      }
    });
  }

  Future<Either<Failure, void>> deleteProduct(String id) {
    return guard((client) async {
      await client.from(StoreSchema.products).delete().eq(StoreColumns.id, id);
    });
  }

  /// How many listings exist, split by visibility — the admin KPI tiles.
  Future<Either<Failure, ({int total, int published, int outOfStock})>> catalogueCounts() {
    return guard((client) async {
      final rows = await client
          .from(StoreSchema.products)
          .select('${StoreColumns.published},${StoreColumns.stock}');
      var published = 0, outOfStock = 0;
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        if (row[StoreColumns.published] == true) published++;
        final stock = (row[StoreColumns.stock] as num?)?.toDouble() ?? 0;
        if (stock <= 0) outOfStock++;
      }
      return (total: rows.length, published: published, outOfStock: outOfStock);
    });
  }
}
