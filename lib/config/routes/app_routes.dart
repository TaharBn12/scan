import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../core/cloud/cloud_auth_controller.dart';
import '../../core/security/session_controller.dart';
import '../../features/auth/presentation/pages/auth_gate_page.dart';
import '../../features/billing/presentation/pages/home_page.dart';
import '../../features/product/presentation/pages/product_list_page.dart';
import '../../features/product/presentation/pages/add_product_page.dart';
import '../../features/product/presentation/pages/edit_product_page.dart';
import '../../features/product/presentation/pages/low_stock_page.dart';
import '../../features/shop/presentation/pages/shop_details_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/billing/presentation/pages/scanner_page.dart';
import '../../features/billing/presentation/pages/checkout_page.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/product/presentation/pages/no_barcode_products_page.dart';
import '../../features/sales/presentation/pages/reports_page.dart';
import '../../features/customers/domain/entities/customer.dart';
import '../../features/customers/presentation/pages/customers_page.dart';
import '../../features/customers/presentation/pages/customer_form_page.dart';
import '../../features/customers/presentation/pages/customer_detail_page.dart';
import '../../features/menu/presentation/pages/menu_page.dart';
import '../../features/customers/presentation/pages/debts_page.dart';
import '../../features/inventory/presentation/pages/stock_take_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/shifts/presentation/pages/shift_page.dart';
import '../../features/users/presentation/pages/login_page.dart';
import '../../features/sales/presentation/pages/invoice_page.dart';
import '../../features/expenses/presentation/pages/expenses_page.dart';
import '../../features/inventory/presentation/pages/purchases_page.dart';
import '../../features/inventory/presentation/pages/new_purchase_page.dart';
import '../../features/inventory/presentation/pages/stock_movements_page.dart';
import '../../features/inventory/presentation/pages/expiry_page.dart';
import '../../features/labels/presentation/pages/labels_page.dart';
import '../../features/product/presentation/pages/dead_stock_page.dart';
import '../../features/billing/domain/entities/promotion.dart';
import '../../features/promotions/presentation/pages/promotions_page.dart';
import '../../features/promotions/presentation/pages/promotion_form_page.dart';
import '../../features/sales/domain/entities/sale.dart';
import '../../features/sales/presentation/pages/return_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import '../../features/users/presentation/pages/lock_page.dart';
import '../../features/delivery/presentation/pages/deliveries_page.dart';
import '../../features/delivery/presentation/pages/delivery_tracking_page.dart';
import '../../features/delivery/presentation/pages/courier_home_page.dart';
import '../../features/delivery/presentation/pages/courier_delivery_page.dart';
import '../../features/delivery/presentation/pages/courier_earnings_page.dart';
import '../../features/delivery/presentation/pages/courier_history_page.dart';
import '../../features/delivery/presentation/pages/deliverers_page.dart';
import '../../features/storefront/presentation/pages/store_shell_page.dart';
import '../../features/storefront/presentation/pages/store_browse_page.dart';
import '../../features/storefront/presentation/pages/store_product_page.dart';
import '../../features/storefront/presentation/pages/store_cart_page.dart';
import '../../features/storefront/presentation/pages/store_checkout_page.dart';
import '../../features/storefront/presentation/pages/store_orders_page.dart';
import '../../features/storefront/presentation/pages/store_order_detail_page.dart';
import '../../features/storefront/presentation/pages/store_search_page.dart';
import '../../features/storefront/presentation/pages/store_wishlist_page.dart';
import '../../features/storefront/presentation/pages/store_offers_page.dart';
import '../../features/storefront/presentation/pages/store_support_page.dart';
import '../../features/store/domain/entities/store_order.dart';
import '../../features/store/domain/entities/store_product.dart';
import '../../features/ecom_admin/presentation/pages/ecom_admin_home_page.dart';
import '../../features/ecom_admin/presentation/pages/ecom_orders_page.dart';
import '../../features/ecom_admin/presentation/pages/ecom_order_detail_page.dart';
import '../../features/ecom_admin/presentation/pages/ecom_products_page.dart';
import '../../features/ecom_admin/presentation/pages/ecom_sync_page.dart';
import '../../features/ecom_admin/presentation/pages/ecom_settings_page.dart';
import '../../features/ecom_admin/presentation/pages/ecom_product_form_page.dart';
import '../../features/ecom_admin/presentation/pages/ecom_marketing_page.dart';
import '../../features/ecom_admin/presentation/pages/ecom_crm_page.dart';
import '../../features/ecom_admin/presentation/pages/ecom_schema_page.dart';

/// Routes only an admin may open when multi-user mode is on. Cashiers get
/// bounced to the menu (the menu hides these entries anyway).

// The global `cloudAuth` session lives in cloud_auth_controller.dart and is
// assigned once in main().

final router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: Listenable.merge([cloudAuth, sessionController]),
  redirect: (context, state) {
    final location = state.uri.path;
    const authRoutes = ['/login', '/lock'];
    const cloudRoutes = ['/splash', '/cloud-login', '/pending'];

    // ---- Cloud auth gate (runs first, login is mandatory) ----
    switch (cloudAuth.state) {
      case CloudAuthState.unknown:
      case CloudAuthState.configMissing:
        return location == '/splash' ? null : '/splash';
      case CloudAuthState.signedOut:
        return location == '/cloud-login' ? null : '/cloud-login';
      case CloudAuthState.pendingApproval:
        return location == '/pending' ? null : '/pending';
      case CloudAuthState.ready:
        break;
    }
    if (cloudRoutes.contains(location)) return '/menu';

    // ---- Legacy in-app locks (PIN / quick account switch) ----
    if (sessionController.needsUnlock) {
      if (authRoutes.contains(location)) return null;
      return sessionController.isMultiUser ? '/login' : '/lock';
    }
    if (authRoutes.contains(location)) return '/menu';

    // The courier experience: a deliverer only sees his own screens.
    if (sessionController.isDeliverer && !location.startsWith('/courier')) {
      return '/courier';
    }

    // Signed in: every screen checks the role's permissions.
    if (!sessionController.canOpen(location)) return '/menu';
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => SplashPage(controller: cloudAuth),
    ),
    GoRoute(
      path: '/cloud-login',
      builder: (context, state) => CloudLoginPage(controller: cloudAuth),
    ),
    GoRoute(
      path: '/pending',
      builder: (context, state) => PendingApprovalPage(controller: cloudAuth),
    ),
    GoRoute(
      path: '/lock',
      builder: (context, state) => const LockPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'scanner',
          builder: (context, state) => const ScannerPage(),
        ),
        GoRoute(
          path: 'checkout',
          builder: (context, state) => const CheckoutPage(),
        ),
        GoRoute(
          path: 'no-barcode',
          builder: (context, state) =>
              const NoBarcodeProductsPage(selectionMode: true),
        ),
        GoRoute(
          path: 'menu',
          builder: (context, state) => const MenuPage(),
        ),
        GoRoute(
          path: 'invoice',
          builder: (context, state) {
            final args = state.extra as InvoiceRouteArgs;
            return InvoicePage(args: args);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/deliveries',
      builder: (context, state) => const DeliveriesPage(),
      routes: [
        GoRoute(
          path: 'map',
          builder: (context, state) => const DeliveryTrackingPage(),
        ),
        GoRoute(
          path: 'couriers',
          builder: (context, state) => const DeliverersPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/courier',
      builder: (context, state) => const CourierHomePage(),
      routes: [
        GoRoute(
          path: 'map',
          builder: (context, state) => const DeliveryTrackingPage(),
        ),
        GoRoute(
          path: 'earnings',
          builder: (context, state) => const CourierEarningsPage(),
        ),
        GoRoute(
          path: 'history',
          builder: (context, state) => const CourierHistoryPage(),
        ),
        GoRoute(
          path: 'detail',
          builder: (context, state) => CourierDeliveryPage(
            deliveryId: state.extra as String? ?? '',
            readOnly: !sessionController.isDeliverer,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/shift',
      builder: (context, state) => const ShiftPage(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: '/promotions',
      builder: (context, state) => const PromotionsPage(),
      routes: [
        GoRoute(
          path: 'form',
          builder: (context, state) =>
              PromotionFormPage(existing: state.extra as Promotion?),
        ),
      ],
    ),
    GoRoute(
      path: '/returns/new',
      builder: (context, state) => ReturnPage(sale: state.extra as Sale),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductListPage(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) {
            final barcode = state.uri.queryParameters['barcode'];
            return AddProductPage(initialBarcode: barcode);
          },
        ),
        GoRoute(
          path: 'add-no-barcode',
          builder: (context, state) =>
              const AddProductPage(startWithoutBarcode: true),
        ),
        GoRoute(
          path: 'no-barcode',
          builder: (context, state) =>
              const NoBarcodeProductsPage(selectionMode: false),
        ),
        GoRoute(
          path: 'low-stock',
          builder: (context, state) => const LowStockPage(),
        ),
        GoRoute(
          path: 'dead-stock',
          builder: (context, state) => const DeadStockPage(),
        ),
        GoRoute(
          path: 'movements/:id',
          builder: (context, state) {
            final product = state.extra as Product?;
            return StockMovementsPage(
                productId: state.pathParameters['id']!, product: product);
          },
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final product = state.extra as Product?;
            if (product == null) {
              // Without extra (e.g. deep link), go back to the list.
              return const ProductListPage();
            }
            return EditProductPage(product: product);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => const ShopDetailsPage(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsPage(),
    ),
    GoRoute(
      path: '/expenses',
      builder: (context, state) => const ExpensesPage(),
    ),
    GoRoute(
      path: '/inventory',
      builder: (context, state) => const PurchasesPage(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) {
            final product = state.extra as Product?;
            return NewPurchasePage(initialProduct: product);
          },
        ),
        GoRoute(
          path: 'stocktake',
          builder: (context, state) => const StockTakePage(),
        ),
        GoRoute(
          path: 'expiry',
          builder: (context, state) => const ExpiryPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/labels',
      builder: (context, state) {
        final product = state.extra as Product?;
        return LabelsPage(initialProduct: product);
      },
    ),
    GoRoute(
      path: '/users',
      builder: (context, state) => UsersPage(controller: cloudAuth),
    ),
    // ---- E-commerce: the customer-facing shop ----
    //
    // Hosted inside the POS so the owner can walk his own site exactly as a
    // shopper sees it. Deep links (/store/product/:id, /store/order/:id) work
    // on their own, wrapped in the monochrome theme by the shell.
    GoRoute(
      path: '/store',
      builder: (context, state) => const StoreShellPage(),
      routes: [
        GoRoute(
          path: 'browse',
          builder: (context, state) => const StoreBrowsePage(),
        ),
        GoRoute(
          path: 'category/:id',
          builder: (context, state) =>
              StoreBrowsePage(categoryId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'offers',
          builder: (context, state) => const StoreOffersPage(),
        ),
        GoRoute(
          path: 'search',
          builder: (context, state) => const StoreSearchPage(),
        ),
        GoRoute(
          path: 'wishlist',
          builder: (context, state) => const StoreWishlistPage(),
        ),
        GoRoute(
          path: 'cart',
          builder: (context, state) => const StoreCartPage(),
        ),
        GoRoute(
          path: 'addresses',
          builder: (context, state) => const StoreAddressesPage(),
        ),
        GoRoute(
          path: 'support',
          builder: (context, state) => const StoreSupportPage(),
        ),
        GoRoute(
          path: 'checkout',
          builder: (context, state) => const StoreCheckoutPage(),
        ),
        GoRoute(
          path: 'orders',
          builder: (context, state) => const StoreOrdersPage(),
        ),
        GoRoute(
          path: 'order/:id',
          builder: (context, state) =>
              StoreOrderDetailPage(order: state.extra as StoreOrder?),
        ),
        GoRoute(
          path: 'product/:id',
          builder: (context, state) =>
              StoreProductPage(productId: state.pathParameters['id']!),
        ),
      ],
    ),

    // ---- E-commerce: the management console ----
    GoRoute(
      path: '/ecom',
      builder: (context, state) => const EcomAdminHomePage(),
      routes: [
        GoRoute(
          path: 'orders',
          builder: (context, state) => const EcomOrdersPage(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  EcomOrderDetailPage(order: state.extra as StoreOrder?),
            ),
          ],
        ),
        GoRoute(
          path: 'products',
          builder: (context, state) => const EcomProductsPage(),
          routes: [
            GoRoute(
              path: 'form',
              builder: (context, state) {
                final product = state.extra as StoreProduct?;
                return EcomProductFormPage(product: product);
              },
            ),
          ],
        ),
        GoRoute(
          path: 'categories',
          builder: (context, state) => const EcomCategoriesPage(),
        ),
        GoRoute(
          path: 'coupons',
          builder: (context, state) => const EcomCouponsPage(),
        ),
        GoRoute(
          path: 'banners',
          builder: (context, state) => const EcomBannersPage(),
        ),
        GoRoute(
          path: 'customers',
          builder: (context, state) => const EcomCustomersPage(),
        ),
        GoRoute(
          path: 'reviews',
          builder: (context, state) => const EcomReviewsPage(),
        ),
        GoRoute(
          path: 'sync',
          builder: (context, state) => const EcomSyncPage(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const EcomSettingsPage(),
        ),
        GoRoute(
          path: 'schema',
          builder: (context, state) => const EcomSchemaPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomersPage(),
      routes: [
        GoRoute(
          path: 'debts',
          builder: (context, state) => const DebtsPage(),
        ),
        GoRoute(
          path: 'picker',
          builder: (context, state) => const CustomersPage(selectionMode: true),
        ),
        GoRoute(
          path: 'add',
          builder: (context, state) => const CustomerFormPage(),
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final customer = state.extra as Customer?;
            return CustomerFormPage(customer: customer);
          },
        ),
        GoRoute(
          path: 'detail/:id',
          builder: (context, state) {
            final customer = state.extra as Customer;
            return CustomerDetailPage(customer: customer);
          },
        ),
      ],
    ),
  ],
);
