import 'package:hive/hive.dart';
import '../../domain/entities/shop.dart';

/// Hand-written Hive adapter for [Shop]; byte-compatible with the previous
/// generated ShopModelAdapter (fields 0-5). Field 6 (taxId) is new.
class ShopAdapter extends TypeAdapter<Shop> {
  @override
  final int typeId = 1;

  @override
  Shop read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Shop(
      name: fields[0] as String? ?? '',
      addressLine1: fields[1] as String? ?? '',
      addressLine2: fields[2] as String? ?? '',
      phoneNumber: fields[3] as String? ?? '',
      upiId: fields[4] as String? ?? '',
      footerText: fields[5] as String? ?? '',
      taxId: fields[6] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Shop obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.addressLine1)
      ..writeByte(2)
      ..write(obj.addressLine2)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.upiId)
      ..writeByte(5)
      ..write(obj.footerText)
      ..writeByte(6)
      ..write(obj.taxId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShopAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
