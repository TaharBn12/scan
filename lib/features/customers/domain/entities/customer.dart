import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String notes;
  final DateTime createdAt;
  /// Maximum outstanding credit allowed. 0 = unlimited.
  final double creditLimit;
  final DateTime? updatedAt;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.notes = '',
    required this.createdAt,
    this.creditLimit = 0,
    this.updatedAt,
  });

  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    String? notes,
    double? creditLimit,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      creditLimit: creditLimit ?? this.creditLimit,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'creditLimit': creditLimit,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Customer.fromMap(Map map) => Customer(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        address: map['address'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
        creditLimit: (map['creditLimit'] as num?)?.toDouble() ?? 0,
        updatedAt: map['updatedAt'] != null
            ? DateTime.tryParse(map['updatedAt'] as String)
            : null,
      );

  @override
  List<Object?> get props =>
      [id, name, phone, address, notes, createdAt, creditLimit, updatedAt];
}
