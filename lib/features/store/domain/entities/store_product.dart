import 'package:equatable/equatable.dart';

import '../../../../core/supabase/row_reader.dart';
import '../../../../core/supabase/store_schema.dart';

/// A product as the *storefront* sees it.
///
/// It is deliberately separate from the POS `Product`: the counter cares
/// about barcode, cost and units, the website cares about images, SEO slug,
/// rating and whether the listing is published. [fromPosProduct] bridges the
/// two so the merchant publishes his catalogue without retyping anything.
class StoreProduct extends Equatable {
  final String id;
  final String name;
  final String nameAr;
  final String nameFr;
  final String slug;
  final String description;
  final String descriptionAr;
  final double price;
  final double compareAtPrice;
  final double costPrice;
  final double stock;
  final String sku;
  final String barcode;
  final String categoryId;
  final List<String> images;
  final bool published;
  final bool featured;
  final double rating;
  final int reviewsCount;
  final int soldCount;
  final String unit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StoreProduct({
    required this.id,
    required this.name,
    this.nameAr = '',
    this.nameFr = '',
    this.slug = '',
    this.description = '',
    this.descriptionAr = '',
    this.price = 0,
    this.compareAtPrice = 0,
    this.costPrice = 0,
    this.stock = 0,
    this.sku = '',
    this.barcode = '',
    this.categoryId = '',
    this.images = const [],
    this.published = true,
    this.featured = false,
    this.rating = 0,
    this.reviewsCount = 0,
    this.soldCount = 0,
    this.unit = 'piece',
    this.createdAt,
    this.updatedAt,
  });

  /// Cover image, or '' when the listing has none (screens then draw a
  /// monochrome placeholder rather than a broken image).
  String get cover => images.isEmpty ? '' : images.first;
  List<String> get gallery => images.isEmpty ? const [] : images;

  bool get onSale => compareAtPrice > price && compareAtPrice > 0;
  double get discountPercent =>
      onSale ? (((compareAtPrice - price) / compareAtPrice) * 100).roundToDouble() : 0;
  bool get inStock => stock > 0;
  bool get lowStock => stock > 0 && stock <= 5;

  /// The name to show for [languageCode] ('ar' / 'fr' / anything else).
  String localizedName(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return nameAr.isNotEmpty ? nameAr : name;
      case 'fr':
        return nameFr.isNotEmpty ? nameFr : name;
      default:
        return name;
    }
  }

  String localizedDescription(String languageCode) {
    if (languageCode == 'ar' && descriptionAr.isNotEmpty) return descriptionAr;
    return description;
  }

  /// SEO-friendly slug derived from the name when the schema has none.
  String get effectiveSlug => slug.isNotEmpty ? slug : _slugify(name);

  static String _slugify(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9\u0600-\u06FF]+"), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  /// Only the columns `public.products` actually has.
  ///
  /// The translated names, barcode, rating and unit are kept in memory (and in
  /// the local Hive cache) but are *not* sent: the site's table has no such
  /// column, and Postgres rejects an insert that names one. `published` is
  /// written as the `status` text the storefront filters on.
  Map<String, dynamic> toMap({String? ownerId}) => {
        StoreColumns.id: id,
        if (ownerId != null && ownerId.isNotEmpty) StoreColumns.userId: ownerId,
        StoreColumns.name: name,
        StoreColumns.slug: effectiveSlug,
        StoreColumns.description: description,
        StoreColumns.price: price,
        StoreColumns.compareAtPrice: compareAtPrice,
        StoreColumns.costPrice: costPrice,
        StoreColumns.stock: stock,
        StoreColumns.sku: sku,
        StoreColumns.categoryId: categoryId,
        StoreColumns.image: images.isEmpty ? '' : images.first,
        StoreColumns.images: images,
        StoreColumns.published: statusValue,
        StoreColumns.updatedAt: DateTime.now().toIso8601String(),
      };

  /// `status` doubles as the publish switch — `shop.html` only ever selects
  /// rows where it equals `active`.
  String get statusValue =>
      published ? StoreSchema.publishedValue : StoreSchema.draftValue;

  /// Reads the publish state from either shape: the `status` text this schema
  /// uses, or a boolean column if a project was set up from an older copy.
  static bool publishedFrom(Map<String, dynamic> map) {
    final raw = map[StoreSchema.productStatusColumn];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim().toLowerCase() == StoreSchema.publishedValue;
    }
    return Row.bool_(map, StoreColumns.published, true);
  }

  factory StoreProduct.fromMap(Map<String, dynamic> map) {
    final images = Row.list(map, StoreColumns.images);
    final single = Row.str(map, StoreColumns.image);
    final gallery = [
      ...images,
      if (single.isNotEmpty && !images.contains(single)) single,
    ];
    return StoreProduct(
      id: Row.str(map, StoreColumns.id),
      name: Row.str(map, StoreColumns.name),
      nameAr: Row.str(map, StoreColumns.nameAr),
      nameFr: Row.str(map, StoreColumns.nameFr),
      slug: Row.str(map, StoreColumns.slug),
      description: Row.str(map, StoreColumns.description),
      descriptionAr: Row.str(map, StoreColumns.descriptionAr),
      price: Row.num_(map, StoreColumns.price),
      compareAtPrice: Row.num_(map, StoreColumns.compareAtPrice),
      costPrice: Row.num_(map, StoreColumns.costPrice),
      stock: Row.num_(map, StoreColumns.stock),
      sku: Row.str(map, StoreColumns.sku),
      barcode: Row.str(map, StoreColumns.barcode),
      categoryId: Row.str(map, StoreColumns.categoryId),
      images: gallery,
      published: publishedFrom(map),
      featured: Row.bool_(map, StoreColumns.featured),
      rating: Row.num_(map, StoreColumns.rating),
      reviewsCount: Row.int_(map, 'reviews_count'),
      soldCount: Row.int_(map, StoreColumns.soldCount),
      unit: Row.str(map, StoreColumns.unit, 'piece'),
      createdAt: Row.date(map, StoreColumns.createdAt),
      updatedAt: Row.date(map, StoreColumns.updatedAt),
    );
  }

  StoreProduct copyWith({
    String? id,
    String? name,
    String? nameAr,
    String? nameFr,
    String? slug,
    String? description,
    String? descriptionAr,
    double? price,
    double? compareAtPrice,
    double? costPrice,
    double? stock,
    String? sku,
    String? barcode,
    String? categoryId,
    List<String>? images,
    bool? published,
    bool? featured,
    double? rating,
    int? reviewsCount,
    int? soldCount,
    String? unit,
  }) =>
      StoreProduct(
        id: id ?? this.id,
        name: name ?? this.name,
        nameAr: nameAr ?? this.nameAr,
        nameFr: nameFr ?? this.nameFr,
        slug: slug ?? this.slug,
        description: description ?? this.description,
        descriptionAr: descriptionAr ?? this.descriptionAr,
        price: price ?? this.price,
        compareAtPrice: compareAtPrice ?? this.compareAtPrice,
        costPrice: costPrice ?? this.costPrice,
        stock: stock ?? this.stock,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
        categoryId: categoryId ?? this.categoryId,
        images: images ?? this.images,
        published: published ?? this.published,
        featured: featured ?? this.featured,
        rating: rating ?? this.rating,
        reviewsCount: reviewsCount ?? this.reviewsCount,
        soldCount: soldCount ?? this.soldCount,
        unit: unit ?? this.unit,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props => [
        id, name, nameAr, nameFr, slug, description, descriptionAr, price,
        compareAtPrice, costPrice, stock, sku, barcode, categoryId, images,
        published, featured, rating, reviewsCount, soldCount, unit, updatedAt,
      ];
}
