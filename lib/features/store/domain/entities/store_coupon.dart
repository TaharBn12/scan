import 'package:equatable/equatable.dart';

import '../../../../core/supabase/row_reader.dart';
import '../../../../core/supabase/store_schema.dart';

enum StoreCouponType {
  percent,
  fixed,
  freeShipping;

  String get labelKey => 'store_coupon_$name';

  static StoreCouponType fromName(String? raw) {
    final value = (raw ?? 'percent').toLowerCase().trim();
    return StoreCouponType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => switch (value) {
        'percentage' || '%' || 'discount_percent' => StoreCouponType.percent,
        'amount' || 'money' || 'flat' || 'fixed_amount' =>
          StoreCouponType.fixed,
        'shipping' || 'free_shipping' => StoreCouponType.freeShipping,
        _ => StoreCouponType.percent,
      },
    );
  }
}

/// A discount code the shopper types at checkout.
class StoreCoupon extends Equatable {
  final String id;
  final String code;
  final StoreCouponType type;
  final double value;
  final double minSpend;
  final double maxDiscount;
  final int usageLimit;
  final int usedCount;
  final DateTime? expiresAt;
  final bool active;
  final String description;

  const StoreCoupon({
    required this.id,
    required this.code,
    this.type = StoreCouponType.percent,
    this.value = 0,
    this.minSpend = 0,
    this.maxDiscount = 0,
    this.usageLimit = 0,
    this.usedCount = 0,
    this.expiresAt,
    this.active = true,
    this.description = '',
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isExhausted => usageLimit > 0 && usedCount >= usageLimit;
  bool get isUsable => active && !isExpired && !isExhausted;

  /// The amount this code takes off [subtotal] (0 when it does not apply).
  double discountFor(double subtotal) {
    if (!isUsable || subtotal < minSpend) return 0;
    switch (type) {
      case StoreCouponType.percent:
        final raw = subtotal * value / 100;
        return maxDiscount > 0 && raw > maxDiscount ? maxDiscount : raw;
      case StoreCouponType.fixed:
        return value > subtotal ? subtotal : value;
      case StoreCouponType.freeShipping:
        return 0; // handled by the checkout, which zeroes the shipping fee.
    }
  }

  bool get waivesShipping => type == StoreCouponType.freeShipping && isUsable;

  /// Short human label, e.g. "10%" or "-500 DA".
  String summary(String currency) => switch (type) {
        StoreCouponType.percent => '${value.toStringAsFixed(0)}%',
        StoreCouponType.fixed =>
          '-${value.toStringAsFixed(0)} $currency',
        StoreCouponType.freeShipping => '0 $currency',
      };

  Map<String, dynamic> toMap() => {
        StoreColumns.id: id,
        StoreColumns.code: code.toUpperCase(),
        StoreColumns.type: type.name,
        StoreColumns.value: value,
        StoreColumns.minSpend: minSpend,
        'max_discount': maxDiscount,
        StoreColumns.usageLimit: usageLimit,
        StoreColumns.usedCount: usedCount,
        StoreColumns.expiresAt: expiresAt?.toIso8601String(),
        StoreColumns.active: active,
        StoreColumns.description: description,
      };

  factory StoreCoupon.fromMap(Map<String, dynamic> map) => StoreCoupon(
        id: Row.str(map, StoreColumns.id),
        code: Row.str(map, StoreColumns.code).toUpperCase(),
        type: StoreCouponType.fromName(Row.strOrNull(map, StoreColumns.type)),
        value: Row.num_(map, StoreColumns.value),
        minSpend: Row.num_(map, StoreColumns.minSpend),
        maxDiscount: Row.num_(map, 'max_discount'),
        usageLimit: Row.int_(map, StoreColumns.usageLimit),
        usedCount: Row.int_(map, StoreColumns.usedCount),
        expiresAt: Row.date(map, StoreColumns.expiresAt),
        active: Row.bool_(map, StoreColumns.active, true),
        description: Row.str(map, StoreColumns.description),
      );

  @override
  List<Object?> get props =>
      [id, code, type, value, minSpend, maxDiscount, usageLimit, usedCount, expiresAt, active];
}
