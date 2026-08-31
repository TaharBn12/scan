import 'dart:convert';
import '../data/hive_database.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';

/// Exports/imports everything stored locally (products, sales, customers,
/// shop details) as a single JSON blob. There's no file-picker/path_provider
/// dependency in this project, so backup goes through the clipboard: copy
/// the JSON out, paste it back in (e.g. via a notes app, WhatsApp to
/// yourself, etc.) to move data between devices or restore after a
/// reinstall.
class BackupHelper {
  static const int backupVersion = 1;

  static String exportAsJson() {
    final products = HiveDatabase.productBox.values
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'barcode': p.barcode,
              'price': p.price,
              'stock': p.stock,
              'hasBarcode': p.hasBarcode,
            })
        .toList();

    final sales = HiveDatabase.salesBox.values
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();

    final customers = HiveDatabase.customersBox.values
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();

    final shopModel = HiveDatabase.shopBox.get('shop_details');
    final shop = shopModel != null
        ? {
            'name': shopModel.name,
            'addressLine1': shopModel.addressLine1,
            'addressLine2': shopModel.addressLine2,
            'phoneNumber': shopModel.phoneNumber,
            'upiId': shopModel.upiId,
            'footerText': shopModel.footerText,
          }
        : null;

    final backup = {
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'products': products,
      'sales': sales,
      'customers': customers,
      'shop': shop,
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// Merges a previously exported backup into local storage. Existing
  /// records with a matching id are overwritten; anything already on the
  /// device that isn't in the backup is left untouched (nothing is deleted).
  /// Throws a [FormatException] (or similar) if [jsonString] isn't a backup
  /// produced by [exportAsJson] - the caller is expected to show that error.
  static Future<BackupImportSummary> importFromJson(String jsonString) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw const FormatException('This does not look like a backup file.');
    }

    int productsImported = 0;
    int salesImported = 0;
    int customersImported = 0;
    bool shopImported = false;

    final products = decoded['products'];
    if (products is List) {
      for (final raw in products) {
        final map = Map<String, dynamic>.from(raw as Map);
        final model = ProductModel(
          id: map['id'] as String,
          name: map['name'] as String? ?? '',
          barcode: map['barcode'] as String? ?? '',
          price: (map['price'] as num?)?.toDouble() ?? 0,
          stock: (map['stock'] as num?)?.toInt() ?? 0,
          hasBarcode: map['hasBarcode'] as bool? ?? true,
        );
        await HiveDatabase.productBox.put(model.id, model);
        productsImported++;
      }
    }

    final sales = decoded['sales'];
    if (sales is List) {
      for (final raw in sales) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id'] as String;
        await HiveDatabase.salesBox.put(id, map);
        salesImported++;
      }
    }

    final customers = decoded['customers'];
    if (customers is List) {
      for (final raw in customers) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id'] as String;
        await HiveDatabase.customersBox.put(id, map);
        customersImported++;
      }
    }

    final shop = decoded['shop'];
    if (shop is Map) {
      final model = ShopModel(
        name: shop['name'] as String? ?? '',
        addressLine1: shop['addressLine1'] as String? ?? '',
        addressLine2: shop['addressLine2'] as String? ?? '',
        phoneNumber: shop['phoneNumber'] as String? ?? '',
        upiId: shop['upiId'] as String? ?? '',
        footerText: shop['footerText'] as String? ?? '',
      );
      await HiveDatabase.shopBox.put('shop_details', model);
      shopImported = true;
    }

    return BackupImportSummary(
      productsImported: productsImported,
      salesImported: salesImported,
      customersImported: customersImported,
      shopImported: shopImported,
    );
  }
}

class BackupImportSummary {
  final int productsImported;
  final int salesImported;
  final int customersImported;
  final bool shopImported;

  const BackupImportSummary({
    required this.productsImported,
    required this.salesImported,
    required this.customersImported,
    required this.shopImported,
  });
}
