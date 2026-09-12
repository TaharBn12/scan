import 'package:equatable/equatable.dart';

import '../../../../core/supabase/row_reader.dart';
import '../../../../core/supabase/store_schema.dart';

/// A promotional block on the storefront home page.
///
/// [productId] / [categoryId] let the merchant deep-link a banner straight to
/// a listing or a department; when both are empty the banner opens [link].
class StoreBanner extends Equatable {
  final String id;
  final String title;
  final String titleAr;
  final String subtitle;
  final String imageUrl;
  final String link;
  final String productId;
  final String categoryId;
  final int position;
  final bool active;

  const StoreBanner({
    required this.id,
    required this.title,
    this.titleAr = '',
    this.subtitle = '',
    this.imageUrl = '',
    this.link = '',
    this.productId = '',
    this.categoryId = '',
    this.position = 0,
    this.active = true,
  });

  String localizedTitle(String languageCode) =>
      languageCode == 'ar' && titleAr.isNotEmpty ? titleAr : title;

  Map<String, dynamic> toMap() => {
        StoreColumns.id: id,
        'title': title,
        'title_ar': titleAr,
        'subtitle': subtitle,
        StoreColumns.imageUrl: imageUrl,
        StoreColumns.link: link,
        'product_id': productId,
        'category_id': categoryId,
        StoreColumns.position: position,
        StoreColumns.active: active,
      };

  factory StoreBanner.fromMap(Map<String, dynamic> map) => StoreBanner(
        id: Row.str(map, StoreColumns.id),
        title: Row.str(map, 'title'),
        titleAr: Row.str(map, 'title_ar'),
        subtitle: Row.str(map, 'subtitle'),
        imageUrl: Row.str(map, StoreColumns.imageUrl),
        link: Row.str(map, StoreColumns.link),
        productId: Row.str(map, 'product_id'),
        categoryId: Row.str(map, 'category_id'),
        position: Row.int_(map, StoreColumns.position),
        active: Row.bool_(map, StoreColumns.active, true),
      );

  @override
  List<Object?> get props =>
      [id, title, titleAr, subtitle, imageUrl, link, productId, categoryId, position, active];
}
