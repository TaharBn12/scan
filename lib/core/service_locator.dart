import 'package:get_it/get_it.dart';
import '../features/product/data/repositories/product_repository_impl.dart';
import '../features/product/domain/repositories/product_repository.dart';
import '../features/product/domain/usecases/product_usecases.dart';
import '../features/product/presentation/bloc/product_bloc.dart';
import '../features/shop/data/repositories/shop_repository_impl.dart';
import '../features/shop/domain/repositories/shop_repository.dart';
import '../features/shop/domain/usecases/shop_usecases.dart';
import '../features/shop/presentation/bloc/shop_bloc.dart';
import '../features/settings/data/repositories/printer_repository_impl.dart';
import '../features/settings/domain/repositories/printer_repository.dart';
import '../features/settings/presentation/bloc/printer_bloc.dart';
import '../features/sales/data/repositories/sale_repository_impl.dart';
import '../features/sales/domain/repositories/sale_repository.dart';
import '../features/sales/domain/usecases/sale_usecases.dart';
import '../features/sales/presentation/bloc/sale_bloc.dart';
import '../features/customers/data/repositories/customer_repository_impl.dart';
import '../features/customers/domain/repositories/customer_repository.dart';
import '../features/customers/domain/usecases/customer_usecases.dart';
import '../features/customers/presentation/bloc/customer_bloc.dart';
import '../features/expenses/data/repositories/expense_repository_impl.dart';
import '../features/expenses/domain/repositories/expense_repository.dart';
import '../features/expenses/presentation/bloc/expense_bloc.dart';
import '../features/inventory/data/repositories/inventory_repository_impl.dart';
import '../features/inventory/domain/repositories/inventory_repository.dart';
import '../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../features/store/data/repositories/store_account_repository.dart';
import '../features/store/data/repositories/store_catalog_repository.dart';
import '../features/store/data/repositories/store_marketing_repository.dart';
import '../features/store/data/repositories/store_order_repository.dart';
import '../features/store/data/repositories/store_settings_repository.dart';
import '../features/store/data/store_sync_service.dart';
import '../features/store/presentation/bloc/store_admin_bloc.dart';
import '../features/users/data/repositories/user_repository.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Features - Product
  sl.registerFactory(
    () => ProductBloc(
      getProductsUseCase: sl(),
      addProductUseCase: sl(),
      updateProductUseCase: sl(),
      deleteProductUseCase: sl(),
      adjustStockUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => ShopBloc(
      getShopUseCase: sl(),
      updateShopUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => PrinterBloc(
      repository: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetProductsUseCase(sl()));
  sl.registerLazySingleton(() => AddProductUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProductUseCase(sl()));
  sl.registerLazySingleton(() => DeleteProductUseCase(sl()));
  sl.registerLazySingleton(() => GetProductByBarcodeUseCase(sl()));
  sl.registerLazySingleton(() => AdjustStockUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(),
  );

  // Features - Shop
  sl.registerLazySingleton(() => GetShopUseCase(sl()));
  sl.registerLazySingleton(() => UpdateShopUseCase(sl()));
  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(),
  );

  // Features - Settings / Printer
  sl.registerLazySingleton<PrinterRepository>(
    () => PrinterRepositoryImpl(),
  );

  // Features - Sales
  sl.registerFactory(
    () => SaleBloc(
      getSalesUseCase: sl(),
      addSaleUseCase: sl(),
      deleteSaleUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetSalesUseCase(sl()));
  sl.registerLazySingleton(() => AddSaleUseCase(sl()));
  sl.registerLazySingleton(() => DeleteSaleUseCase(sl()));
  sl.registerLazySingleton<SaleRepository>(
    () => SaleRepositoryImpl(),
  );

  // Features - Customers
  sl.registerFactory(
    () => CustomerBloc(
      getCustomersUseCase: sl(),
      addCustomerUseCase: sl(),
      updateCustomerUseCase: sl(),
      deleteCustomerUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetCustomersUseCase(sl()));
  sl.registerLazySingleton(() => AddCustomerUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCustomerUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCustomerUseCase(sl()));
  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(),
  );

  // Features - Expenses
  sl.registerFactory(() => ExpenseBloc(repository: sl()));
  sl.registerLazySingleton<ExpenseRepository>(() => ExpenseRepositoryImpl());

  // Features - Inventory (purchases / stock movements)
  sl.registerFactory(() => InventoryBloc(repository: sl()));
  sl.registerLazySingleton<InventoryRepository>(
      () => InventoryRepositoryImpl());

  // Features - E-commerce (Supabase storefront + its console).
  // Lazy singletons: the link is only opened when somebody actually opens the
  // shop, so a POS-only install never touches the network.
  sl.registerLazySingleton(() => StoreCatalogRepository());
  sl.registerLazySingleton(() => StoreOrderRepository());
  sl.registerLazySingleton(() => StoreAccountRepository());
  sl.registerLazySingleton(() => StoreMarketingRepository());
  sl.registerLazySingleton(() => StoreSettingsRepository());
  sl.registerLazySingleton(() => StoreSyncService(catalog: sl()));
  sl.registerLazySingleton(
    () => StoreAdminBloc(
      orders: sl(),
      catalog: sl(),
      account: sl(),
      marketing: sl(),
      settings: sl(),
      sync: sl(),
    ),
  );

  // Features - Users
  sl.registerLazySingleton(() => UserRepository());
}
