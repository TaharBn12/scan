import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

/// Hive adapter for [Product], written by hand (no build_runner needed).
///
/// Binary layout is a field-count byte followed by (fieldId, value) pairs,
/// identical to what hive_generator produces, so databases written by the
/// previous generated adapter (fields 0-8) load unchanged. New fields
/// (9 = unit, 10 = trackStock, 11 = updatedAt) default when absent.
class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 0;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      id: fields[0] as String,
      name: fields[1] as String? ?? '',
      barcode: fields[2] as String? ?? '',
      price: (fields[3] as num?)?.toDouble() ?? 0,
      stock: (fields[4] as num?)?.toDouble() ?? 0,
      hasBarcode: fields[5] == null ? true : fields[5] as bool,
      costPrice: fields[6] == null ? 0 : (fields[6] as num).toDouble(),
      category: fields[7] == null ? '' : fields[7] as String,
      lowStockThreshold: fields[8] == null ? 5 : (fields[8] as num).toInt(),
      unit: ProductUnitX.fromName(fields[9] as String?),
      trackStock: fields[10] == null ? true : fields[10] as bool,
      updatedAt: fields[11] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[11] as int),
      wholesalePrice: (fields[12] as num?)?.toDouble() ?? 0,
      wholesaleMinQty: (fields[13] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.barcode)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.stock)
      ..writeByte(5)
      ..write(obj.hasBarcode)
      ..writeByte(6)
      ..write(obj.costPrice)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.lowStockThreshold)
      ..writeByte(9)
      ..write(obj.unit.name)
      ..writeByte(10)
      ..write(obj.trackStock)
      ..writeByte(11)
      ..write(obj.updatedAt?.millisecondsSinceEpoch)
      ..writeByte(12)
      ..write(obj.wholesalePrice)
      ..writeByte(13)
      ..write(obj.wholesaleMinQty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
