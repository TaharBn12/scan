import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/routes/app_routes.dart';
import 'core/cloud/cloud_auth_controller.dart';
import 'core/cloud/cloud_database.dart';
import 'core/data/hive_database.dart';
import 'core/l10n/app_localizations.dart';
import 'core/security/session_controller.dart';
import 'core/service_locator.dart' as di;
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/backup_helper.dart';
import 'features/billing/data/held_cart_store.dart';
import 'features/shifts/data/shift_store.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/expenses/presentation/bloc/expense_bloc.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';
import 'features/sales/presentation/bloc/sale_bloc.dart';
import 'features/customers/presentation/bloc/customer_bloc.dart';
import 'features/store/presentation/bloc/store_admin_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase first: everything the app does lives in Realtime Database.
  // google-services.json missing → the splash screen explains it and the
  // build still works for local development.
  var firebaseAvailable = false;
  try {
    await Firebase.initializeApp();
    await CloudDatabase.enableOfflinePersistence();
    firebaseAvailable = true;
  } catch (_) {
    firebaseAvailable = false;
  }
  // Legacy local boxes stay as the migration source + pre-login fallbacks.
  await HiveDatabase.init();
  await di.init();
  cloudAuth = CloudAuthController(firebaseAvailable: firebaseAvailable);
  // Parked invoices are restored so a restart never loses a counter queue.
  heldCarts.load();
  // Restore the open cash-drawer session, if the till was left open.
  shiftStore.load();
  // Daily safety net: writes a backup file at most once a day (best effort).
  BackupHelper.autoBackupIfDue();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  // Captured so the cloud session can (re)load everything after sign-in.
  late final ProductBloc _productBloc = di.sl<ProductBloc>();
  late final ShopBloc _shopBloc = di.sl<ShopBloc>();
  late final BillingBloc _billingBloc =
      BillingBloc(getProductByBarcodeUseCase: di.sl());
  late final PrinterBloc _printerBloc = di.sl<PrinterBloc>();
  late final SaleBloc _saleBloc = di.sl<SaleBloc>();
  late final CustomerBloc _customerBloc = di.sl<CustomerBloc>();
  late final ExpenseBloc _expenseBloc = di.sl<ExpenseBloc>();
  late final InventoryBloc _inventoryBloc = di.sl<InventoryBloc>();

  /// Shared by every `/ecom/*` route so the console's tabs never disagree.
  late final StoreAdminBloc _storeAdminBloc = di.sl<StoreAdminBloc>();

  CloudAuthState _lastAuthState = CloudAuthState.unknown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cloudAuth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cloudAuth.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Every time the cloud session becomes ready (first sign-in, hot
  /// restart with a remembered session, switching to another shop), push a
  /// fresh load through all blocs so screens show the shop's live data.
  void _onAuthChanged() {
    if (cloudAuth.state == CloudAuthState.ready &&
        _lastAuthState != CloudAuthState.ready) {
      _reloadAll();
    }
    _lastAuthState = cloudAuth.state;
  }

  void _reloadAll() {
    if (!mounted) return;
    _productBloc.add(LoadProducts());
    _shopBloc.add(LoadShopEvent());
    _saleBloc.add(LoadSales());
    _customerBloc.add(LoadCustomers());
    _expenseBloc.add(LoadExpenses());
    _inventoryBloc.add(LoadInventory());
    _printerBloc.add(InitPrinterEvent());
    heldCarts.load();
    shiftStore.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-lock the app when it was in the background for a while.
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final away = DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      final pinOn = appSettings.value.pinEnabled;
      if (pinOn && away.inMinutes >= 2 && !sessionController.isMultiUser) {
        sessionController.lock();
        router.refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProductBloc>.value(
            value: _productBloc..add(LoadProducts())),
        BlocProvider<ShopBloc>.value(value: _shopBloc..add(LoadShopEvent())),
        BlocProvider<BillingBloc>.value(value: _billingBloc),
        BlocProvider<PrinterBloc>.value(
            value: _printerBloc..add(InitPrinterEvent())),
        BlocProvider<SaleBloc>.value(value: _saleBloc..add(LoadSales())),
        BlocProvider<CustomerBloc>.value(
            value: _customerBloc..add(LoadCustomers())),
        BlocProvider<ExpenseBloc>.value(
            value: _expenseBloc..add(LoadExpenses())),
        BlocProvider<InventoryBloc>.value(
            value: _inventoryBloc..add(LoadInventory())),
        BlocProvider<StoreAdminBloc>.value(value: _storeAdminBloc),
      ],
      child: ValueListenableBuilder<ThemeSettings>(
        valueListenable: themeController,
        builder: (context, themeSettings, _) {
          final density = themeSettings.compact
              ? VisualDensity.compact
              : VisualDensity.standard;
          return ValueListenableBuilder<AppSettings>(
            valueListenable: appSettings,
            builder: (context, settings, _) {
              return MaterialApp.router(
                onGenerateTitle: (context) => context.l10n.appTitle,
                theme: AppTheme.light(themeSettings.accent)
                    .copyWith(visualDensity: density),
                darkTheme: AppTheme.dark(themeSettings.accent)
                    .copyWith(visualDensity: density),
                themeMode: themeSettings.mode,
                routerConfig: router,
                debugShowCheckedModeBanner: false,
                locale: settings.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                localeResolutionCallback: (deviceLocale, supported) {
                  // Explicit choice in Settings wins; otherwise follow the
                  // phone if we support its language, else Arabic.
                  if (settings.locale != null) return settings.locale;
                  if (deviceLocale != null) {
                    for (final l in supported) {
                      if (l.languageCode == deviceLocale.languageCode) return l;
                    }
                  }
                  return const Locale('ar');
                },
              );
            },
          );
        },
      ),
    );
  }
}
