import 'package:equatable/equatable.dart';

import '../../../../core/supabase/row_reader.dart';
import '../../../../core/supabase/store_schema.dart';

/// A storefront department. Kept flat (optional [parentId]) because shop
/// catalogues rarely need more than one level, and a flat rail is what the
/// home page renders.
class StoreCategory extends Equatable {
  final String id;
  final String name;
  final String nameAr;
  final String nameFr;
  final String image;
  final String parentId;
  final int position;
  final bool active;
  final int productsCount;

  const StoreCategory({
    required this.id,
    required this.name,
    this.nameAr = '',
    this.nameFr = '',
    this.image = '',
    this.parentId = '',
    this.position = 0,
    this.active = true,
    this.productsCount = 0,
  });

  String localizedName(String languageCode) => switch (languageCode) {
        'ar' => nameAr.isNotEmpty ? nameAr : name,
        'fr' => nameFr.isNotEmpty ? nameFr : name,
        _ => name,
      };

  Map<String, dynamic> toMap() => {
        StoreColumns.id: id,
        StoreColumns.name: name,
        StoreColumns.nameAr: nameAr,
        StoreColumns.nameFr: nameFr,
        StoreColumns.image: image,
        'parent_id': parentId,
        StoreColumns.position: position,
        StoreColumns.active: active,
      };

  factory StoreCategory.fromMap(Map<String, dynamic> map) => StoreCategory(
        id: Row.str(map, StoreColumns.id),
        name: Row.str(map, StoreColumns.name),
        nameAr: Row.str(map, StoreColumns.nameAr),
        nameFr: Row.str(map, StoreColumns.nameFr),
        image: Row.str(map, StoreColumns.image),
        parentId: Row.str(map, 'parent_id'),
        position: Row.int_(map, StoreColumns.position),
        active: Row.bool_(map, StoreColumns.active, true),
        productsCount: Row.int_(map, 'products_count'),
      );

  StoreCategory copyWith({
    String? id,
    String? name,
    String? nameAr,
    String? nameFr,
    String? image,
    String? parentId,
    int? position,
    bool? active,
  }) =>
      StoreCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        nameAr: nameAr ?? this.nameAr,
        nameFr: nameFr ?? this.nameFr,
        image: image ?? this.image,
        parentId: parentId ?? this.parentId,
        position: position ?? this.position,
        active: active ?? this.active,
        productsCount: productsCount,
      );

  @override
  List<Object?> get props =>
      [id, name, nameAr, nameFr, image, parentId, position, active];
}
