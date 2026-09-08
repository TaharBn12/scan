import 'package:go_router/go_router.dart';
import '../../core/security/session_controller.dart';
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
import '../../features/users/domain/entities/app_user.dart';
import '../../features/users/presentation/pages/login_page.dart';
import '../../features/users/presentation/pages/user_form_page.dart';
import '../../features/sales/presentation/pages/invoice_page.dart';
import '../../features/expenses/presentation/pages/expenses_page.dart';
import '../../features/inventory/presentation/pages/purchases_page.dart';
import '../../features/inventory/presentation/pages/new_purchase_page.dart';
import '../../features/inventory/presentation/pages/stock_movements_page.dart';
import '../../features/labels/presentation/pages/labels_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import '../../features/users/presentation/pages/lock_page.dart';

/// Routes only an admin may open when multi-user mode is on. Cashiers get
/// bounced to the menu (the menu hides these entries anyway).

final router = GoRouter(
  initialLocation: '/menu',
  refreshListenable: sessionController,
  redirect: (context, state) {
    final location = state.uri.path;
    const authRoutes = ['/login', '/lock'];

    // Signed out: accounts go to the login screen, a plain app PIN to the
    // pad. Both may hop between each other (PIN tab / password tab).
    if (sessionController.needsUnlock) {
      if (authRoutes.contains(location)) return null;
      return sessionController.isMultiUser ? '/login' : '/lock';
    }
    if (authRoutes.contains(location)) return '/menu';

    // Signed in: every screen checks the role's permissions.
    if (!sessionController.canOpen(location)) return '/menu';
    return null;
  },
  routes: [
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
      builder: (context, state) => const UsersPage(),
      routes: [
        GoRoute(
          path: 'form',
          builder: (context, state) =>
              UserFormPage(existing: state.extra as AppUser?),
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
