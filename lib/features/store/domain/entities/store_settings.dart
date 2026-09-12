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

  Map<String, dynamic> toMap() => {
        'open': open,
        'min_order': minOrder,
        'free_shipping_above': freeShippingAbove,
        'default_shipping_fee': defaultShippingFee,
        'cod_enabled': codEnabled,
        'card_enabled': cardEnabled,
        'transfer_enabled': transferEnabled,
        'currency': currency,
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
