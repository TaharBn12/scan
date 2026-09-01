import 'package:go_router/go_router.dart';
import '../../features/billing/presentation/pages/home_page.dart';
import '../../features/product/presentation/pages/product_list_page.dart';
import '../../features/product/presentation/pages/add_product_page.dart';
import '../../features/product/presentation/pages/edit_product_page.dart';
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
import '../../features/sales/presentation/pages/invoice_page.dart';

final router = GoRouter(
  initialLocation: '/menu',
  routes: [
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
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductListPage(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddProductPage(),
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
          path: 'edit/:id',
          builder: (context, state) {
            final product = state.extra as Product?;
            if (product == null) {
              // If we land here without extra (e.g. deep link), go back to products for now.
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
      path: '/customers',
      builder: (context, state) => const CustomersPage(),
      routes: [
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
