import 'package:equatable/equatable.dart';

import '../../../../core/supabase/row_reader.dart';
import '../../../../core/supabase/store_schema.dart';

/// A saved delivery address of a shopper.
class StoreAddress extends Equatable {
  final String id;
  final String customerId;
  final String label;
  final String fullName;
  final String phone;
  final String address;
  final String city;
  final String wilaya;
  final bool isDefault;

  const StoreAddress({
    required this.id,
    required this.customerId,
    this.label = '',
    this.fullName = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.wilaya = '',
    this.isDefault = false,
  });

  /// Single string shown on cards and on the courier's sheet.
  String get oneLine {
    final parts = [address, city, wilaya]
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.join(' · ');
  }

  Map<String, dynamic> toMap() => {
        StoreColumns.id: id,
        StoreColumns.customerId_: customerId,
        StoreColumns.label: label,
        StoreColumns.fullName: fullName,
        StoreColumns.phone: phone,
        StoreColumns.addressLine: address,
        StoreColumns.city: city,
        StoreColumns.wilaya: wilaya,
        StoreColumns.isDefault: isDefault,
      };

  factory StoreAddress.fromMap(Map<String, dynamic> map) => StoreAddress(
        id: Row.str(map, StoreColumns.id),
        customerId: Row.str(map, StoreColumns.customerId_),
        label: Row.str(map, StoreColumns.label),
        fullName: Row.str(map, StoreColumns.fullName),
        phone: Row.str(map, StoreColumns.phone),
        address: Row.str(map, StoreColumns.addressLine),
        city: Row.str(map, StoreColumns.city),
        wilaya: Row.str(map, StoreColumns.wilaya),
        isDefault: Row.bool_(map, StoreColumns.isDefault),
      );

  @override
  List<Object?> get props =>
      [id, customerId, label, fullName, phone, address, city, wilaya, isDefault];
}

/// A shopper registered on the website.
class StoreCustomer extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime? createdAt;
  final int ordersCount;
  final double lifetimeValue;
  final bool blocked;

  const StoreCustomer({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.createdAt,
    this.ordersCount = 0,
    this.lifetimeValue = 0,
    this.blocked = false,
  });

  /// What the admin list shows when the account has no display name.
  String get displayName {
    if (name.trim().isNotEmpty) return name;
    if (email.trim().isNotEmpty) return email;
    return phone;
  }

  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        StoreColumns.id: id,
        StoreColumns.fullName: name,
        StoreColumns.customerEmail: email,
        StoreColumns.phone: phone,
        'orders_count': ordersCount,
        'lifetime_value': lifetimeValue,
        'blocked': blocked,
      };

  factory StoreCustomer.fromMap(Map<String, dynamic> map) => StoreCustomer(
        id: Row.str(map, StoreColumns.id),
        name: Row.str(map, StoreColumns.fullName),
        email: Row.str(map, StoreColumns.customerEmail),
        phone: Row.str(map, StoreColumns.phone),
        createdAt: Row.date(map, StoreColumns.createdAt),
        ordersCount: Row.int_(map, 'orders_count'),
        lifetimeValue: Row.num_(map, 'lifetime_value'),
        blocked: Row.bool_(map, 'blocked'),
      );

  @override
  List<Object?> get props =>
      [id, name, email, phone, ordersCount, lifetimeValue, blocked];
}
