import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/routes/app_routes.dart';
import 'core/data/hive_database.dart';
import 'core/l10n/app_localizations.dart';
import 'core/security/session_controller.dart';
import 'core/service_locator.dart' as di;
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/backup_helper.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/expenses/presentation/bloc/expense_bloc.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';
import 'features/sales/presentation/bloc/sale_bloc.dart';
import 'features/customers/presentation/bloc/customer_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatabase.init();
  await di.init();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        BlocProvider<ProductBloc>(
            create: (context) => di.sl<ProductBloc>()..add(LoadProducts())),
        BlocProvider<ShopBloc>(
            create: (context) => di.sl<ShopBloc>()..add(LoadShopEvent())),
        BlocProvider<BillingBloc>(
            create: (context) =>
                BillingBloc(getProductByBarcodeUseCase: di.sl())),
        BlocProvider<PrinterBloc>(
            create: (context) => di.sl<PrinterBloc>()..add(InitPrinterEvent())),
        BlocProvider<SaleBloc>(
            create: (context) => di.sl<SaleBloc>()..add(LoadSales())),
        BlocProvider<CustomerBloc>(
            create: (context) => di.sl<CustomerBloc>()..add(LoadCustomers())),
        BlocProvider<ExpenseBloc>(
            create: (context) => di.sl<ExpenseBloc>()..add(LoadExpenses())),
        BlocProvider<InventoryBloc>(
            create: (context) =>
                di.sl<InventoryBloc>()..add(LoadInventory())),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeController,
        builder: (context, mode, _) {
          return ValueListenableBuilder<AppSettings>(
            valueListenable: appSettings,
            builder: (context, settings, _) {
              return MaterialApp.router(
                onGenerateTitle: (context) => context.l10n.appTitle,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: mode,
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
