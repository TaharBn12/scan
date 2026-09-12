import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/shop/domain/entities/shop.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String salesBoxName = 'sales';
  static const String customersBoxName = 'customers';
  static const String expensesBoxName = 'expenses';
  static const String purchasesBoxName = 'purchases';
  static const String stockMovementsBoxName = 'stock_movements';
  static const String usersBoxName = 'users';
  static const String heldCartsBoxName = 'held_carts';
  static const String shiftsBoxName = 'shifts';
  static const String promotionsBoxName = 'promotions';
  // E-commerce module: the shopper's basket and guest wishlist survive a
  // restart so an interrupted checkout is never lost.
  static const String storeCartBoxName = 'store_cart';
  static const String storeWishlistBoxName = 'store_wishlist';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters (hand-written, byte-compatible with the old
    // generated ones so existing databases keep loading).
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProductAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ShopAdapter());

    // Open Boxes
    await Hive.openBox<Product>(productBoxName);
    await Hive.openBox<Shop>(shopBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    // Everything else is stored as plain Maps (no TypeAdapter needed) -
    // simpler, safer to evolve, and trivially JSON-exportable for backups.
    await Hive.openBox(salesBoxName);
    await Hive.openBox(customersBoxName);
    await Hive.openBox(expensesBoxName);
    await Hive.openBox(purchasesBoxName);
    await Hive.openBox(stockMovementsBoxName);
    await Hive.openBox(usersBoxName);
    // Parked (held) invoices waiting to be resumed at the till.
    await Hive.openBox(heldCartsBoxName);
    // Cash-drawer sessions (open float -> counted cash -> variance).
    await Hive.openBox(shiftsBoxName);
    // Automatic price offers ("pay 2 take 3", category discounts...).
    await Hive.openBox(promotionsBoxName);
    await Hive.openBox(storeCartBoxName);
    await Hive.openBox(storeWishlistBoxName);

    // Legacy: the app used to keep an outbox for the removed website /
    // cloud sync. Drop it so old installs stop carrying dead data.
    await _deleteLegacyBox('sync_queue');
  }

  /// Best effort: a missing box (fresh install) must never break startup.
  static Future<void> _deleteLegacyBox(String name) async {
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (_) {}
  }

  static Box<Product> get productBox => Hive.box<Product>(productBoxName);
  static Box<Shop> get shopBox => Hive.box<Shop>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box get salesBox => Hive.box(salesBoxName);
  static Box get customersBox => Hive.box(customersBoxName);
  static Box get expensesBox => Hive.box(expensesBoxName);
  static Box get purchasesBox => Hive.box(purchasesBoxName);
  static Box get stockMovementsBox => Hive.box(stockMovementsBoxName);
  static Box get usersBox => Hive.box(usersBoxName);
  static Box get heldCartsBox => Hive.box(heldCartsBoxName);
  static Box get shiftsBox => Hive.box(shiftsBoxName);
  static Box get promotionsBox => Hive.box(promotionsBoxName);
  static Box get storeCartBox => Hive.box(storeCartBoxName);
  static Box get storeWishlistBox => Hive.box(storeWishlistBoxName);
}
