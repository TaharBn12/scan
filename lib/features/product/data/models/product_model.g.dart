// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 0;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      id: fields[0] as String,
      name: fields[1] as String,
      barcode: fields[2] as String,
      price: fields[3] as double,
      stock: fields[4] as int,
      // Fields 5-8 won't exist on records written before they were added,
      // so we fall back to safe defaults for older data.
      hasBarcode: fields[5] == null ? true : fields[5] as bool,
      costPrice: fields[6] == null ? 0 : (fields[6] as num).toDouble(),
      category: fields[7] == null ? '' : fields[7] as String,
      lowStockThreshold: fields[8] == null ? 5 : fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.lowStockThreshold);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
