import 'package:equatable/equatable.dart';

/// The two offers a small shop actually runs:
///  * [buyXPayY]  — "ادفع X وخذ Y" (pay for X, take Y). e.g. pay 2 take 3.
///  * [percentOff] — a straight % off a product or a whole category.
enum PromoType { buyXPayY, percentOff }

extension PromoTypeX on PromoType {
  String get labelKey =>
      this == PromoType.buyXPayY ? 'promo_type_bxpy' : 'promo_type_percent';

  static PromoType fromName(String? name) {
    if (name == null) return PromoType.buyXPayY;
    return PromoType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => PromoType.buyXPayY,
    );
  }
}

/// A price offer applied automatically at the till — the cashier never has
/// to remember it. Targets either one product ([productId]) or a whole
/// [category]. Product offers win over category offers for the same line.
class Promotion extends Equatable {
  final String id;
  final String name;

  /// '': the whole shop (percentOff only).
  final String productId;
  final String category;

  final PromoType type;

  /// buyXPayY: quantity the customer pays for...
  final int payQty;

  /// ...and the quantity they actually take home (must be > [payQty]).
  final int getQty;

  /// percentOff: the discount percentage (1-100).
  final double percent;

  /// Optional validity window (both inclusive, date part only).
  final DateTime? startAt;
  final DateTime? endAt;

  final bool active;

  const Promotion({
    required this.id,
    required this.name,
    this.productId = '',
    this.category = '',
    this.type = PromoType.buyXPayY,
    this.payQty = 2,
    this.getQty = 3,
    this.percent = 0,
    this.startAt,
    this.endAt,
    this.active = true,
  });

  bool get targetsProduct => productId.isNotEmpty;
  bool get targetsCategory => !targetsProduct && category.isNotEmpty;
  bool get targetsAll => !targetsProduct && !targetsCategory;

  bool isValidOn(DateTime now) {
    if (!active) return false;
    final day = DateTime(now.year, now.month, now.day);
    if (startAt != null) {
      final s = DateTime(startAt!.year, startAt!.month, startAt!.day);
      if (day.isBefore(s)) return false;
    }
    if (endAt != null) {
      final e = DateTime(endAt!.year, endAt!.month, endAt!.day);
      if (day.isAfter(e)) return false;
    }
    return true;
  }

  Promotion copyWith({
    String? name,
    String? productId,
    String? category,
    PromoType? type,
    int? payQty,
    int? getQty,
    double? percent,
    DateTime? startAt,
    DateTime? endAt,
    bool? active,
    bool clearWindow = false,
  }) =>
      Promotion(
        id: id,
        name: name ?? this.name,
        productId: productId ?? this.productId,
        category: category ?? this.category,
        type: type ?? this.type,
        payQty: payQty ?? this.payQty,
        getQty: getQty ?? this.getQty,
        percent: percent ?? this.percent,
        startAt: clearWindow ? null : (startAt ?? this.startAt),
        endAt: clearWindow ? null : (endAt ?? this.endAt),
        active: active ?? this.active,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'productId': productId,
        'category': category,
        'type': type.name,
        'payQty': payQty,
        'getQty': getQty,
        'percent': percent,
        'startAt': startAt?.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'active': active,
      };

  factory Promotion.fromMap(Map map) => Promotion(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        productId: map['productId'] as String? ?? '',
        category: map['category'] as String? ?? '',
        type: PromoTypeX.fromName(map['type'] as String?),
        payQty: (map['payQty'] as num?)?.toInt() ?? 2,
        getQty: (map['getQty'] as num?)?.toInt() ?? 3,
        percent: (map['percent'] as num?)?.toDouble() ?? 0,
        startAt: map['startAt'] != null
            ? DateTime.tryParse(map['startAt'] as String)
            : null,
        endAt: map['endAt'] != null
            ? DateTime.tryParse(map['endAt'] as String)
            : null,
        active: map['active'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        productId,
        category,
        type,
        payQty,
        getQty,
        percent,
        startAt,
        endAt,
        active,
      ];
}
