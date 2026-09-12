/// The single place that describes the e-commerce database layout.
///
/// Every repository in `features/store` reads its table and column names
/// from here, so pointing the app at another storefront schema (a zip from a
/// different template, a renamed table, camelCase columns…) is a matter of
/// editing this one file — no repository, bloc or page changes.
///
/// [StoreColumns.read] additionally accepts the aliases listed in [aliases],
/// which is what lets the app ingest both `snake_case` (Supabase default) and
/// `camelCase` (JS templates) rows without a migration.
class StoreSchema {
  const StoreSchema._();

  // ------------------------------------------------------------- tables
  //
  // Every name is a *getter* rather than a constant so the whole mapping can
  // be re-pointed at runtime (Settings → E-commerce → Connection) instead of
  // requiring a rebuild. A site that calls its table `orders` instead of
  // `store_orders` needs one typed line, not a refactor.

  static String get products => _name('products', 'store_products');
  static String get categories => _name('categories', 'store_categories');
  static String get orders => _name('orders', 'store_orders');
  static String get orderItems => _name('orderItems', 'store_order_items');
  static String get customers => _name('customers', 'store_customers');
  static String get profiles => _name('profiles', 'store_profiles');
  static String get addresses => _name('addresses', 'store_addresses');
  static String get coupons => _name('coupons', 'store_coupons');
  static String get banners => _name('banners', 'store_banners');
  static String get reviews => _name('reviews', 'store_reviews');
  static String get wishlists => _name('wishlists', 'store_wishlist');
  static String get shippingZones => _name('shippingZones', 'store_shipping_zones');
  static String get settings => _name('settings', 'store_settings');

  /// Roles the storefront's back office uses (confirmers phone the customer,
  /// packers box the parcel).
  static String get confirmers => _name('confirmers', 'store_confirmers');
  static String get packers => _name('packers', 'store_packers');
  static String get payouts => _name('payouts', 'store_payouts');

  /// The logical keys above, in the order the health panel lists them.
  static const List<String> keys = [
    'products', 'categories', 'orders', 'orderItems', 'customers', 'profiles',
    'addresses', 'coupons', 'banners', 'reviews', 'wishlists', 'shippingZones',
    'settings', 'confirmers', 'packers', 'payouts',
  ];

  /// Every resolved table name (what the health panel actually queries).
  static List<String> get all => [
        products, categories, orders, orderItems, customers, profiles,
        addresses, coupons, banners, reviews, wishlists, shippingZones,
        settings, confirmers, packers, payouts,
      ];

  /// Applies an override map, e.g. `{'orders': 'commandes'}`.
  static void applyOverrides(Map<String, String> overrides) {
    _overrides
      ..clear()
      ..addAll({
        for (final entry in overrides.entries)
          if (keys.contains(entry.key) && entry.value.trim().isNotEmpty)
            entry.key: entry.value.trim(),
      });
  }

  static final Map<String, String> _overrides = {};

  static String _name(String key, String fallback) => _overrides[key] ?? fallback;
}

/// Column names, with the aliases tolerated on read.
class StoreColumns {
  const StoreColumns._();

  static const String id = 'id';

  // ---- product / catalogue ----
  static const String name = 'name';
  static const String nameAr = 'name_ar';
  static const String nameFr = 'name_fr';
  static const String slug = 'slug';
  static const String description = 'description';
  static const String descriptionAr = 'description_ar';
  static const String price = 'price';
  static const String compareAtPrice = 'compare_at_price';
  static const String costPrice = 'cost_price';
  static const String stock = 'stock';
  static const String sku = 'sku';
  static const String barcode = 'barcode';
  static const String categoryId = 'category_id';
  static const String image = 'image';
  static const String images = 'images';
  static const String published = 'published';
  static const String featured = 'featured';
  static const String active = 'active';
  static const String rating = 'rating';
  static const String soldCount = 'sold_count';
  static const String unit = 'unit';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';

  // ---- order ----
  static const String orderNumber = 'order_number';
  static const String status = 'status';
  static const String paymentMethod = 'payment_method';
  static const String paymentStatus = 'payment_status';
  static const String subtotal = 'subtotal';
  static const String discount = 'discount';
  static const String shippingFee = 'shipping_fee';
  static const String total = 'total';
  static const String customerName = 'customer_name';
  static const String customerPhone = 'customer_phone';
  static const String customerEmail = 'customer_email';
  static const String addressLine = 'address';
  static const String city = 'city';
  static const String wilaya = 'wilaya';
  static const String notes = 'notes';
  static const String couponCode = 'coupon_code';
  static const String items = 'items';
  static const String courierId = 'courier_id';
  static const String shopId = 'shop_id';
  static const String source = 'source';

  // ---- marketing ----
  static const String code = 'code';
  static const String type = 'type';
  static const String value = 'value';
  static const String minSpend = 'min_spend';
  static const String usageLimit = 'usage_limit';
  static const String usedCount = 'used_count';
  static const String expiresAt = 'expires_at';
  static const String imageUrl = 'image_url';
  static const String link = 'link';
  static const String position = 'position';

  // ---- review ----
  static const String productId = 'product_id';
  static const String orderId = 'order_id';
  static const String customerId_ = 'customer_id';
  static const String comment = 'comment';
  static const String approved = 'approved';

  // ---- address ----
  static const String label = 'label';
  static const String isDefault = 'is_default';
  static const String phone = 'phone';
  static const String fullName = 'full_name';

  // ---- shipping ----
  static const String fee = 'fee';
  static const String freeAbove = 'free_above';

  /// Reads the first present, non-null alias of a logical column.
  static Object? read(Map<String, dynamic> row, String column) {
    final direct = row[column];
    if (direct != null) return direct;
    for (final alias in aliases[column] ?? const <String>[]) {
      final value = row[alias];
      if (value != null) return value;
    }
    return null;
  }

  /// Accepted spellings per logical column.
  static const Map<String, List<String>> aliases = {
    nameAr: ['nameAr', 'name_in_arabic'],
    nameFr: ['nameFr', 'name_in_french'],
    descriptionAr: ['descriptionAr', 'description_in_arabic'],
    compareAtPrice: ['compareAtPrice', 'old_price', 'sale_price', 'list_price'],
    costPrice: ['costPrice', 'cost'],
    categoryId: ['categoryId', 'category'],
    imageUrl: ['imageUrl', 'img', 'image', 'photo', 'url'],
    images: ['gallery', 'photos', 'media'],
    published: ['is_published', 'visible', 'is_active', 'status'],
    featured: ['is_featured', 'is_best_seller', 'highlighted'],
    soldCount: ['soldCount', 'sales_count', 'orders_count'],
    createdAt: ['createdAt', 'inserted_at', 'date'],
    updatedAt: ['updatedAt', 'modified_at'],
    orderNumber: ['orderNumber', 'number', 'reference', 'code'],
    paymentMethod: ['paymentMethod', 'payment', 'method'],
    paymentStatus: ['paymentStatus', 'paid'],
    shippingFee: ['shippingFee', 'shipping', 'delivery_fee', 'deliveryFee'],
    customerName: ['customerName', 'name', 'full_name', 'fullName'],
    customerPhone: ['customerPhone', 'phone', 'mobile'],
    customerEmail: ['customerEmail', 'email'],
    addressLine: ['addressLine', 'address_line', 'street', 'full_address'],
    couponCode: ['couponCode', 'coupon', 'promo_code', 'promoCode'],
    courierId: ['courierId', 'deliverer_id', 'delivery_id'],
    shopId: ['shopId', 'seller_id', 'store_id'],
    minSpend: ['minSpend', 'minimum_spend', 'min_amount', 'minAmount'],
    usageLimit: ['usageLimit', 'max_uses', 'limit'],
    usedCount: ['usedCount', 'uses', 'redeemed'],
    expiresAt: ['expiresAt', 'expiry', 'valid_until', 'ends_at'],
    productId: ['productId', 'product'],
    orderId: ['orderId', 'order'],
    customerId_: ['customerId', 'user_id', 'userId', 'profile_id'],
    isDefault: ['isDefault', 'default', 'primary'],
    fullName: ['fullName', 'name', 'customer_name'],
    freeAbove: ['freeAbove', 'free_shipping_above', 'threshold'],
  };
}
