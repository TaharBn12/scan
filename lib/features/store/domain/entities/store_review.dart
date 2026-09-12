import 'package:equatable/equatable.dart';

import '../../../../core/supabase/row_reader.dart';
import '../../../../core/supabase/store_schema.dart';

/// A product review left by a shopper; the merchant moderates them.
class StoreReview extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final String customerName;
  final String customerId;
  final int rating;
  final String comment;
  final bool approved;
  final DateTime createdAt;

  const StoreReview({
    required this.id,
    required this.productId,
    this.productName = '',
    this.customerName = '',
    this.customerId = '',
    this.rating = 5,
    this.comment = '',
    this.approved = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        StoreColumns.id: id,
        StoreColumns.productId: productId,
        'product_name': productName,
        StoreColumns.customerName: customerName,
        StoreColumns.customerId_: customerId,
        'rating': rating,
        StoreColumns.comment: comment,
        StoreColumns.approved: approved,
        StoreColumns.createdAt: createdAt.toIso8601String(),
      };

  factory StoreReview.fromMap(Map<String, dynamic> map) => StoreReview(
        id: Row.str(map, StoreColumns.id),
        productId: Row.str(map, StoreColumns.productId),
        productName: Row.str(map, 'product_name'),
        customerName: Row.str(map, StoreColumns.customerName),
        customerId: Row.str(map, StoreColumns.customerId_),
        rating: Row.int_(map, 'rating', 5),
        comment: Row.str(map, StoreColumns.comment),
        approved: Row.bool_(map, StoreColumns.approved),
        createdAt: Row.date(map, StoreColumns.createdAt) ?? DateTime.now(),
      );

  @override
  List<Object?> get props =>
      [id, productId, customerName, rating, comment, approved, createdAt];
}
