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

  // Names below are the storefront's real ones, read out of the site's own
  // `tables_only.sql`, `shipping_setup.sql`, `confirmer_schema.sql`,
  // `packer_schema.sql`, `add_order_columns.sql`, `add_product_offers.sql`,
  // `add_store_slug.sql` and `setup_bottom_images.sql`.

  static String get products => _name('products', 'products');
  static String get orders => _name('orders', 'orders');
  static String get customers => _name('customers', 'customers');
  static String get profiles => _name('profiles', 'profiles');
  static String get settings => _name('settings', 'store_settings');
  static String get shippingZones => _name('shippingZones', 'shipping_rates');
  static String get platformAdmins =>
      _name('platformAdmins', 'platform_admins');
  static String get modulesConfig => _name('modulesConfig', 'modules_config');

  /// Confirmers and packers are *not* their own tables: they are rows in
  /// [profiles] with `role = 'confirmer' | 'packer'` and a `merchant_id`
  /// pointing at the shop they work for (`confirmer_schema.sql`,
  /// `packer_schema.sql`).
  static String get confirmers => profiles;
  static String get packers => profiles;
  static const String confirmerRole = 'confirmer';
  static const String packerRole = 'packer';
  static const String merchantRole = 'merchant';

  // ------------------------------------------------- app-owned tables
  //
  // The storefront has no table for these features. Rather than drop them, the
  // app keeps them in its own `store_*` tables inside the *same* Supabase
  // project — created by `supabase_optional_tables.sql` in the repo root. Until
  // that script has been run the repositories fail softly into a localized
  // ServerFailure and the screens show the notice, so nothing crashes.

  static String get categories => _name('categories', 'store_categories');
  static String get orderItems => _name('orderItems', 'store_order_items');
  static String get addresses => _name('addresses', 'store_addresses');
  static String get coupons => _name('coupons', 'store_coupons');
  static String get banners => _name('banners', 'store_banners');
  static String get reviews => _name('reviews', 'store_reviews');
  static String get wishlists => _name('wishlists', 'store_wishlist');
  static String get payouts => _name('payouts', 'store_payouts');

  /// Logical keys, in the order the health panel lists them.
  static const List<String> keys = [
    'products', 'orders', 'customers', 'profiles', 'settings', 'shippingZones',
    'platformAdmins', 'modulesConfig',
  ];

  /// Every resolved table name (what the health panel actually queries).
  static List<String> get all => [
        products, orders, customers, profiles, settings, shippingZones,
        platformAdmins, modulesConfig,
      ];

  // --------------------------------------------------- absent tables
  //
  // The storefront has no table for these: `category` is a plain TEXT column
  // on `products`, an order carries its single product inline, and shipping
  // prices live in `shipping_rates` keyed by wilaya code. Anything the app
  // offers for them is kept local (Hive) rather than inventing a table.

  /// True when the site itself provides a table for [key].
  static bool has(String key) => keys.contains(key);

  /// True for the app-owned extras: the feature works, but only once
  /// `supabase_optional_tables.sql` has been run in the project.
  static bool isOptional(String key) => optional.contains(key);

  /// Features the site does not provide, served from the app's own tables.
  static const List<String> optional = [
    'categories', 'orderItems', 'addresses', 'coupons', 'banners',
    'reviews', 'wishlists', 'payouts',
  ];

  /// Every optional table name, for the health panel.
  static List<String> get optionalTables => [
        categories, orderItems, addresses, coupons, banners, reviews,
        wishlists, payouts,
      ];

  /// `products.status` doubles as the publish switch: the storefront only
  /// ever selects `.eq('status', 'active')` (see `shop.html`).
  static const String productStatusColumn = 'status';
  static const String publishedValue = 'active';
  static const String draftValue = 'draft';

  /// One order = one product, repeated [StoreColumns.quantity] times. There
  /// is no `order_items` table in this schema.
  static const bool singleLineOrders = true;

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

  /// The overrides currently in force — shown by the schema screen and
  /// echoed in the exported report.
  static Map<String, String> get currentOverrides =>
      Map<String, String>.unmodifiable(_overrides);

  static final Map<String, String> _overrides = {};

  static String _name(String key, String fallback) => _overrides[key] ?? fallback;
}

/// Column names, with the aliases tolerated on read.
class StoreColumns {
  const StoreColumns._();

  static const String id = 'id';

  /// The shop that owns the row. Every table in this schema is scoped by
  /// `user_id` — the storefront is multi-tenant, so no query may omit it.
  static const String userId = 'user_id';

  // ---- product / catalogue (`tables_only.sql` §6, `add_product_*`) ----
  static const String name = 'title';
  static const String slug = 'slug';
  static const String description = 'description';
  static const String price = 'price';
  static const String compareAtPrice = 'compare_at_price';
  static const String costPrice = 'cost_price';
  static const String stock = 'stock_quantity';
  static const String sku = 'sku';

  /// A plain TEXT column, not a foreign key — there is no categories table.
  static const String categoryId = 'category';

  static const String image = 'main_image_url';

  /// `images TEXT[]` — the gallery. `bottom_images TEXT[]` is the sticky
  /// strip the landing page renders below the fold.
  static const String images = 'images';
  static const String bottomImages = 'bottom_images';

  /// `status` doubles as the publish switch (`shop.html` selects `active`).
  static const String published = 'status';

  /// Landing-page bundles: "buy 2 for X", "buy 3 for Y"
  /// (`add_product_offers.sql`).
  static const String offer2Enabled = 'offer_2_enabled';
  static const String offer2Price = 'offer_2_price';
  static const String offer3Enabled = 'offer_3_enabled';
  static const String offer3Price = 'offer_3_price';

  /// Per-product tracking ids (`add_product_pixels_v2.sql`).
  static const String facebookPixel = 'facebook_pixel_id';
  static const String tiktokPixel = 'tiktok_pixel_id';
  static const String googleAnalytics = 'google_analytics_id';

  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';

  // ---- order (`tables_only.sql` §7 + `add_order_columns.sql` +
  //      `update_product_pixels.sql` + `confirmer_schema.sql` +
  //      `packer_schema.sql`) ----
  static const String orderNumber = 'order_number';
  static const String status = 'status';

  /// What the customer pays — there is no `total` column in this schema.
  static const String total = 'selling_price';

  static const String purchaseCost = 'purchase_cost';
  static const String shippingCost = 'shipping_cost';
  static const String profit = 'profit';

  static const String productName = 'product_name';
  static const String customerName = 'customer_name';
  static const String customerPhone = 'customer_phone';
  static const String addressLine = 'address';

  /// The commune. `commune` is the current spelling (`add_order_columns.sql`);
  /// `baladiya` is the older one (`update_product_pixels.sql`).
  static const String city = 'commune';
  static const String baladiya = 'baladiya';

  static const String wilaya = 'wilaya';

  /// `home` or `desk` — drives the shipping price.
  static const String shippingType = 'shipping_type';
  static const String shippingHome = 'home';
  static const String shippingDesk = 'desk';

  static const String quantity = 'quantity';
  static const String offerName = 'offer_name';
  static const String notes = 'notes';

  /// Who phoned the customer, who boxed the parcel.
  static const String confirmerId = 'confirmer_id';
  static const String packerId = 'packer_id';

  static const String customerId = 'customer_id';
  static const String productId = 'product_id';

  // ---- customer (`tables_only.sql` §5) ----
  static const String fullName = 'full_name';
  static const String phone = 'phone';
  static const String totalOrders = 'total_orders';
  static const String returnedOrders = 'returned_orders';
  static const String totalSpent = 'total_spent';
  static const String customerType = 'customer_type';
  static const String lastOrderAt = 'last_order_at';

  // ---- profile / merchant / confirmer / packer (§1, `confirmer_*`,
  //      `packer_schema.sql`, `confirmer_rates.sql`) ----
  static const String email = 'email';
  static const String role = 'role';
  static const String merchantId = 'merchant_id';
  static const String isApproved = 'is_approved';
  static const String packageType = 'package_type';
  static const String trialEndsAt = 'trial_ends_at';
  static const String confirmationRate = 'confirmation_rate';
  static const String followUpRate = 'follow_up_rate';
  static const String packagingRate = 'packaging_rate';
  static const String storageRate = 'storage_rate';
  static const String printingRate = 'printing_rate';
  static const String extraCommissionRate = 'extra_commission_rate';

  // ---- store settings (`tables_only.sql` §3, `add_store_slug.sql`) ----
  /// The primary key of `store_settings` is `user_id`, not `id`.
  static const String storeName = 'store_name';
  static const String storeSlug = 'store_slug';
  static const String logoUrl = 'logo_url';
  static const String primaryColor = 'primary_color';
  static const String currency = 'currency';

  // ---- shipping (`shipping_setup.sql`) ----
  /// 1–58, one row per wilaya.
  static const String wilayaCode = 'wilaya_code';
  static const String wilayaName = 'wilaya_name';
  static const String priceHome = 'price_home';
  static const String priceDesk = 'price_desk';
  static const String isActive = 'is_active';

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

  // ------------------------------------------------------------------
  // Columns with no counterpart in this schema.
  //
  // The storefront keeps no table for coupons, banners, reviews, addresses or
  // multi-line order items, so the app offers those features locally (Hive)
  // and these names only ever reach local storage — never a query. They are
  // listed here so the entities stay honest about what they persist, and so
  // the day the site does grow these tables nothing has to be renamed.
  // ------------------------------------------------------------------

  static const String nameAr = 'name_ar';
  static const String nameFr = 'name_fr';
  static const String descriptionAr = 'description_ar';
  static const String barcode = 'barcode';
  static const String featured = 'featured';
  static const String active = 'active';
  static const String rating = 'rating';
  static const String soldCount = 'sold_count';
  static const String unit = 'unit';

  static const String paymentMethod = 'payment_method';
  static const String paymentStatus = 'payment_status';
  static const String subtotal = 'subtotal';
  static const String discount = 'discount';
  static const String shippingFee = 'shipping_fee';
  static const String customerEmail = 'customer_email';
  static const String couponCode = 'coupon_code';
  static const String items = 'items';
  static const String courierId = 'courier_id';
  static const String shopId = 'shop_id';
  static const String source = 'source';

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

  static const String orderId = 'order_id';
  static const String customerId_ = 'customer_id';
  static const String comment = 'comment';
  static const String approved = 'approved';

  static const String label = 'label';
  static const String isDefault = 'is_default';
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

  /// Accepted spellings per logical column. The first entry of each list is
  /// this schema's own name; the rest are tolerances for a project that was
  /// set up from an older copy of the SQL.
  static const Map<String, List<String>> aliases = {
    // product
    name: ['name', 'product_name', 'label'],
    stock: ['stock', 'quantity_available', 'qty'],
    image: ['image', 'image_url', 'img', 'photo', 'main_image'],
    images: ['gallery', 'photos', 'media'],
    bottomImages: ['bottomImages', 'bottom_image', 'sticky_images'],
    categoryId: ['category_id', 'categoryId'],
    published: ['is_published', 'visible', 'is_active'],
    slug: ['permalink', 'handle'],
    compareAtPrice: ['compareAtPrice', 'old_price', 'sale_price', 'list_price'],
    costPrice: ['costPrice', 'cost'],
    createdAt: ['createdAt', 'inserted_at', 'date'],
    updatedAt: ['updatedAt', 'modified_at'],

    // order
    total: ['total', 'amount', 'sellingPrice'],
    shippingCost: ['shipping_cost', 'shipping_fee', 'shippingFee', 'delivery_fee'],
    purchaseCost: ['purchase_cost', 'cost'],
    city: ['baladiya', 'city', 'commune_name'],
    wilaya: ['wilaya_name', 'state', 'region'],
    customerName: ['customerName', 'full_name', 'name'],
    customerPhone: ['customerPhone', 'phone', 'mobile'],
    addressLine: ['address_line', 'street', 'full_address'],
    orderNumber: ['orderNumber', 'number', 'reference'],
    shippingType: ['shippingType', 'delivery_type', 'deliveryType'],
    quantity: ['qty', 'count', 'pieces'],
    confirmerId: ['confirmer', 'confirmer_uuid'],
    packerId: ['packer', 'packer_uuid'],

    // customer / profile
    fullName: ['name', 'customer_name'],
    totalOrders: ['orders_count', 'order_count'],
    returnedOrders: ['returns_count', 'returned_count'],
    totalSpent: ['spent', 'lifetime_value'],
    lastOrderAt: ['last_order_date', 'last_purchase_at'],

    // settings
    storeName: ['name', 'shop_name', 'title'],
    storeSlug: ['slug', 'handle', 'subdomain'],
    logoUrl: ['logo', 'logo_image_url'],

    // shipping
    wilayaCode: ['code', 'wilaya_id'],
    wilayaName: ['name', 'wilaya'],
    priceHome: ['home_price', 'home', 'price_to_home'],
    priceDesk: ['desk_price', 'desk', 'price_to_desk', 'stop_desk_price'],

    // local-only features
    nameAr: ['nameAr', 'name_in_arabic'],
    nameFr: ['nameFr', 'name_in_french'],
    descriptionAr: ['descriptionAr', 'description_in_arabic'],
    imageUrl: ['imageUrl', 'img', 'image', 'photo', 'url'],
    featured: ['is_featured', 'is_best_seller', 'highlighted'],
    soldCount: ['soldCount', 'sales_count', 'orders_count'],
    paymentMethod: ['paymentMethod', 'payment', 'method'],
    paymentStatus: ['paymentStatus', 'paid'],
    customerEmail: ['customerEmail', 'email'],
    couponCode: ['couponCode', 'coupon', 'promo_code', 'promoCode'],
    courierId: ['courierId', 'deliverer_id', 'delivery_id'],
    shopId: ['shopId', 'seller_id', 'store_id'],
    minSpend: ['minSpend', 'minimum_spend', 'min_amount', 'minAmount'],
    usageLimit: ['usageLimit', 'max_uses', 'limit'],
    usedCount: ['usedCount', 'uses', 'redeemed'],
    expiresAt: ['expiresAt', 'expiry', 'valid_until', 'ends_at'],
    productId: ['productId', 'product'],
    orderId: ['orderId', 'order'],
    // Deliberately NOT `user_id`: in this schema that is the merchant, and
    // confusing it with the buyer would leak one shop's orders into another.
    customerId_: ['customerId', 'buyer_id'],
    isDefault: ['isDefault', 'default', 'primary'],
    freeAbove: ['freeAbove', 'free_shipping_above', 'threshold'],
  };
}
