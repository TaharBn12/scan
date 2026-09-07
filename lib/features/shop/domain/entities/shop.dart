import 'package:equatable/equatable.dart';

class Shop extends Equatable {
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String phoneNumber;
  /// Kept for backwards compatibility (was a UPI id); now used as a free
  /// "payment info" line, e.g. CCP/BaridiMob/RIP number printed on receipts.
  final String upiId;
  final String footerText;
  final String taxId; // NIF / RC etc. shown on invoices (optional)

  const Shop({
    this.name = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.phoneNumber = '',
    this.upiId = '',
    this.footerText = '',
    this.taxId = '',
  });

  Shop copyWith({
    String? name,
    String? addressLine1,
    String? addressLine2,
    String? phoneNumber,
    String? upiId,
    String? footerText,
    String? taxId,
  }) {
    return Shop(
      name: name ?? this.name,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      upiId: upiId ?? this.upiId,
      footerText: footerText ?? this.footerText,
      taxId: taxId ?? this.taxId,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'phoneNumber': phoneNumber,
        'upiId': upiId,
        'footerText': footerText,
        'taxId': taxId,
      };

  factory Shop.fromMap(Map map) => Shop(
        name: map['name'] as String? ?? '',
        addressLine1: map['addressLine1'] as String? ?? '',
        addressLine2: map['addressLine2'] as String? ?? '',
        phoneNumber: map['phoneNumber'] as String? ?? '',
        upiId: map['upiId'] as String? ?? '',
        footerText: map['footerText'] as String? ?? '',
        taxId: map['taxId'] as String? ?? '',
      );

  @override
  List<Object?> get props =>
      [name, addressLine1, addressLine2, phoneNumber, upiId, footerText, taxId];
}
