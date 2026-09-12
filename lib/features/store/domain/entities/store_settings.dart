import 'package:equatable/equatable.dart';

import '../../../../core/supabase/row_reader.dart';
import '../../../../core/supabase/store_schema.dart';

/// One delivery zone and what it costs.
class StoreShippingOption extends Equatable {
  final String id;
  final String name;
  final double fee;
  final double freeAbove;
  final int days;
  final bool active;

  const StoreShippingOption({
    required this.id,
    required this.name,
    this.fee = 0,
    this.freeAbove = 0,
    this.days = 2,
    this.active = true,
  });

  /// The fee actually charged for a [subtotal] basket.
  double feeFor(double subtotal) =>
      freeAbove > 0 && subtotal >= freeAbove ? 0 : fee;

  Map<String, dynamic> toMap() => {
        StoreColumns.id: id,
        StoreColumns.name: name,
        StoreColumns.fee: fee,
        StoreColumns.freeAbove: freeAbove,
        'days': days,
        StoreColumns.active: active,
      };

  factory StoreShippingOption.fromMap(Map<String, dynamic> map) =>
      StoreShippingOption(
        id: Row.str(map, StoreColumns.id),
        name: Row.str(map, StoreColumns.name),
        fee: Row.num_(map, StoreColumns.fee),
        freeAbove: Row.num_(map, StoreColumns.freeAbove),
        days: Row.int_(map, 'days', 2),
        active: Row.bool_(map, StoreColumns.active, true),
      );

  @override
  List<Object?> get props => [id, name, fee, freeAbove, days, active];
}

/// Store-wide switches read by the storefront and edited by the admin.
class StoreSettings extends Equatable {
  final bool open;
  final double minOrder;
  final double freeShippingAbove;
  final double defaultShippingFee;
  final bool codEnabled;
  final bool cardEnabled;
  final bool transferEnabled;
  final String currency;
  final String supportPhone;
  final String supportEmail;
  final String announcement;
  final String facebookUrl;
  final String instagramUrl;

  const StoreSettings({
    this.open = true,
    this.minOrder = 0,
    this.freeShippingAbove = 0,
    this.defaultShippingFee = 0,
    this.codEnabled = true,
    this.cardEnabled = false,
    this.transferEnabled = false,
    this.currency = 'DA',
    this.supportPhone = '',
    this.supportEmail = '',
    this.announcement = '',
    this.facebookUrl = '',
    this.instagramUrl = '',
  });

  List<String> get enabledPayments => [
        if (codEnabled) 'cod',
        if (cardEnabled) 'card',
        if (transferEnabled) 'transfer',
      ];

  /// Only the columns `public.store_settings` actually has.
  ///
  /// That table is narrow by design — `user_id`, `store_name`, `logo_url`,
  /// the three tracking ids, `primary_color`, `currency`, `store_slug` — and
  /// `user_id` is its primary key, not `id`. Of the switches this entity
  /// carries, only `currency` has a column; the rest are the app's own and
  /// live in [localMap]. Sending them would make Postgres reject the whole
  /// upsert, including the currency that *is* supported.
  Map<String, dynamic> toMap({String? ownerId}) => {
        if (ownerId != null && ownerId.isNotEmpty) StoreColumns.userId: ownerId,
        StoreColumns.currency: currency,
        StoreColumns.updatedAt: DateTime.now().toIso8601String(),
      };

  /// Storefront switches with no column in `store_settings`. Persisted in the
  /// local settings box, so the merchant's configuration is not lost just
  /// because the site's table predates these features.
  Map<String, dynamic> localMap() => {
        'open': open,
        'min_order': minOrder,
        'free_shipping_above': freeShippingAbove,
        'default_shipping_fee': defaultShippingFee,
        'cod_enabled': codEnabled,
        'card_enabled': cardEnabled,
        'transfer_enabled': transferEnabled,
        'support_phone': supportPhone,
        'support_email': supportEmail,
        'announcement': announcement,
        'facebook_url': facebookUrl,
        'instagram_url': instagramUrl,
      };

  factory StoreSettings.fromMap(Map<String, dynamic> map) => StoreSettings(
        open: Row.bool_(map, 'open', true),
        minOrder: Row.num_(map, 'min_order'),
        freeShippingAbove: Row.num_(map, 'free_shipping_above'),
        defaultShippingFee: Row.num_(map, 'default_shipping_fee'),
        codEnabled: Row.bool_(map, 'cod_enabled', true),
        cardEnabled: Row.bool_(map, 'card_enabled'),
        transferEnabled: Row.bool_(map, 'transfer_enabled'),
        currency: Row.str(map, 'currency', 'DA'),
        supportPhone: Row.str(map, 'support_phone'),
        supportEmail: Row.str(map, 'support_email'),
        announcement: Row.str(map, 'announcement'),
        facebookUrl: Row.str(map, 'facebook_url'),
        instagramUrl: Row.str(map, 'instagram_url'),
      );

  @override
  List<Object?> get props => [
        open, minOrder, freeShippingAbove, defaultShippingFee, codEnabled,
        cardEnabled, transferEnabled, currency, supportPhone, supportEmail,
        announcement, facebookUrl, instagramUrl,
      ];
}

/// One row of `public.shipping_rates` — the site's own delivery price list.
///
/// The site prices by wilaya and by drop-off kind: `price_home` for door
/// delivery, `price_desk` for a stop-desk counter (`shipping_setup.sql`).
/// It ships all 58 wilayas pre-seeded, so the checkout can quote a real fee
/// without the merchant configuring anything.
class StoreShippingRate extends Equatable {
  final int id;
  final int wilayaCode;
  final String wilayaName;
  final double priceHome;
  final double priceDesk;
  final bool active;
  final DateTime? updatedAt;

  const StoreShippingRate({
    required this.id,
    required this.wilayaCode,
    required this.wilayaName,
    this.priceHome = 0,
    this.priceDesk = 0,
    this.active = true,
    this.updatedAt,
  });

  /// The price for a delivery kind (`home` / `desk`).
  double priceFor(String shippingType) => shippingType == StoreColumns.shippingDesk
      ? priceDesk
      : priceHome;

  Map<String, dynamic> toMap() => {
        if (id > 0) StoreColumns.id: id,
        StoreColumns.wilayaCode: wilayaCode,
        StoreColumns.wilayaName: wilayaName,
        StoreColumns.priceHome: priceHome,
        StoreColumns.priceDesk: priceDesk,
        StoreColumns.isActive: active,
        StoreColumns.updatedAt: DateTime.now().toIso8601String(),
      };

  factory StoreShippingRate.fromMap(Map<String, dynamic> map) =>
      StoreShippingRate(
        id: Row.int_(map, StoreColumns.id),
        wilayaCode: Row.int_(map, StoreColumns.wilayaCode),
        wilayaName: Row.str(map, StoreColumns.wilayaName),
        priceHome: Row.num_(map, StoreColumns.priceHome),
        priceDesk: Row.num_(map, StoreColumns.priceDesk),
        active: Row.bool_(map, StoreColumns.isActive, true),
        updatedAt: Row.date(map, StoreColumns.updatedAt),
      );

  @override
  List<Object?> get props =>
      [id, wilayaCode, wilayaName, priceHome, priceDesk, active];
}
