import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/supabase/store_connection.dart';
import '../../data/repositories/store_account_repository.dart';
import '../../data/repositories/store_catalog_repository.dart';
import '../../data/repositories/store_marketing_repository.dart';
import '../../data/repositories/store_order_repository.dart';
import '../../data/repositories/store_settings_repository.dart';
import '../../data/store_sync_service.dart';
import '../../domain/entities/store_banner.dart';
import '../../domain/entities/store_category.dart';
import '../../domain/entities/store_coupon.dart';
import '../../domain/entities/store_customer.dart';
import '../../domain/entities/store_order.dart';
import '../../domain/entities/store_product.dart';
import '../../domain/entities/store_review.dart';
import '../../domain/entities/store_settings.dart';

// ------------------------------------------------------------------ events

abstract class StoreAdminEvent extends Equatable {
  const StoreAdminEvent();
  @override
  List<Object?> get props => [];
}

/// Everything the console's home screen shows, in one shot.
class LoadStoreAdmin extends StoreAdminEvent {}

class FilterAdminOrders extends StoreAdminEvent {
  final StoreOrderStatus? status;
  final String query;
  const FilterAdminOrders({this.status, this.query = ''});
  @override
  List<Object?> get props => [status, query];
}

class SetAdminOrderStatus extends StoreAdminEvent {
  final String orderId;
  final StoreOrderStatus status;
  final bool markPaid;
  const SetAdminOrderStatus(this.orderId, this.status, {this.markPaid = false});
  @override
  List<Object?> get props => [orderId, status, markPaid];
}

class AssignAdminCourier extends StoreAdminEvent {
  final String orderId;
  final String courierId;
  const AssignAdminCourier(this.orderId, this.courierId);
  @override
  List<Object?> get props => [orderId, courierId];
}

class AddAdminOrderNote extends StoreAdminEvent {
  final String orderId;
  final String note;
  const AddAdminOrderNote(this.orderId, this.note);
  @override
  List<Object?> get props => [orderId, note];
}

class DeleteAdminOrder extends StoreAdminEvent {
  final String orderId;
  const DeleteAdminOrder(this.orderId);
  @override
  List<Object?> get props => [orderId];
}

class LoadAdminCatalogue extends StoreAdminEvent {}

class PublishAdminProducts extends StoreAdminEvent {
  final List<String> ids;
  final bool published;
  const PublishAdminProducts(this.ids, this.published);
  @override
  List<Object?> get props => [ids, published];
}

class SaveAdminProduct extends StoreAdminEvent {
  final StoreProduct product;
  const SaveAdminProduct(this.product);
  @override
  List<Object?> get props => [product];
}

class DeleteAdminProduct extends StoreAdminEvent {
  final String id;
  const DeleteAdminProduct(this.id);
  @override
  List<Object?> get props => [id];
}

/// Compares the shelf with the site.
class PreviewShelfSync extends StoreAdminEvent {}

class RunShelfSync extends StoreAdminEvent {
  final List<String> productIds;
  const RunShelfSync(this.productIds);
  @override
  List<Object?> get props => [productIds];
}

class SaveAdminCoupon extends StoreAdminEvent {
  final StoreCoupon coupon;
  const SaveAdminCoupon(this.coupon);
  @override
  List<Object?> get props => [coupon];
}

class ToggleAdminCoupon extends StoreAdminEvent {
  final String id;
  final bool active;
  const ToggleAdminCoupon(this.id, this.active);
  @override
  List<Object?> get props => [id, active];
}

class DeleteAdminCoupon extends StoreAdminEvent {
  final String id;
  const DeleteAdminCoupon(this.id);
  @override
  List<Object?> get props => [id];
}

class ModerateAdminReview extends StoreAdminEvent {
  final String id;
  final bool approved;
  const ModerateAdminReview(this.id, this.approved);
  @override
  List<Object?> get props => [id, approved];
}

class DeleteAdminReview extends StoreAdminEvent {
  final String id;
  const DeleteAdminReview(this.id);
  @override
  List<Object?> get props => [id];
}

class SaveAdminBanner extends StoreAdminEvent {
  final StoreBanner banner;
  const SaveAdminBanner(this.banner);
  @override
  List<Object?> get props => [banner];
}

class DeleteAdminBanner extends StoreAdminEvent {
  final String id;
  const DeleteAdminBanner(this.id);
  @override
  List<Object?> get props => [id];
}

class SaveAdminCategory extends StoreAdminEvent {
  final StoreCategory category;
  const SaveAdminCategory(this.category);
  @override
  List<Object?> get props => [category];
}

class DeleteAdminCategory extends StoreAdminEvent {
  final String id;
  const DeleteAdminCategory(this.id);
  @override
  List<Object?> get props => [id];
}

class SaveAdminSettings extends StoreAdminEvent {
  final StoreSettings settings;
  const SaveAdminSettings(this.settings);
  @override
  List<Object?> get props => [settings];
}

class SaveAdminShippingZone extends StoreAdminEvent {
  final StoreShippingOption zone;
  const SaveAdminShippingZone(this.zone);
  @override
  List<Object?> get props => [zone];
}

class DeleteAdminShippingZone extends StoreAdminEvent {
  final String id;
  const DeleteAdminShippingZone(this.id);
  @override
  List<Object?> get props => [id];
}

/// Re-tests the Supabase link and re-reads which tables exist.
class RecheckStoreLink extends StoreAdminEvent {}

// ------------------------------------------------------------------- state

enum StoreAdminStatus { initial, loading, ready, busy, error, offline }

class StoreAdminState extends Equatable {
  final StoreAdminStatus status;
  final StoreLinkState link;
  final List<StoreOrder> orders;
  final StoreOrderStatus? statusFilter;
  final String query;
  final List<StoreOrder> recentOrders;
  final StoreOrderStats stats;
  final List<({DateTime day, double revenue, int orders})> dailyRevenue;
  final List<StoreProduct> products;
  final ({int total, int published, int outOfStock}) catalogueCounts;
  final List<SyncRow> syncRows;
  final int syncPushed;
  final List<StoreCoupon> coupons;
  final List<StoreReview> reviews;
  final List<StoreCustomer> customers;
  final List<StoreBanner> banners;
  final List<StoreCategory> categories;
  final StoreSettings settings;
  final List<StoreShippingOption> shippingZones;
  final Map<String, bool> schemaHealth;
  final String? message;

  const StoreAdminState({
    this.status = StoreAdminStatus.initial,
    this.link = StoreLinkState.unknown,
    this.orders = const [],
    this.statusFilter,
    this.query = '',
    this.recentOrders = const [],
    this.stats = const StoreOrderStats(),
    this.dailyRevenue = const [],
    this.products = const [],
    this.catalogueCounts = (total: 0, published: 0, outOfStock: 0),
    this.syncRows = const [],
    this.syncPushed = 0,
    this.coupons = const [],
    this.reviews = const [],
    this.customers = const [],
    this.banners = const [],
    this.categories = const [],
    this.settings = const StoreSettings(),
    this.shippingZones = const [],
    this.schemaHealth = const {},
    this.message,
  });

  bool get isLinked => link.isLive;
  int get pendingCount =>
      orders.where((o) => o.status == StoreOrderStatus.pending).length;
  int get pendingReviews => reviews.where((r) => !r.approved).length;
  int get syncPending => syncRows.where((r) => r.reason.needsPush).length;
  List<StoreProduct> get unpublished =>
      products.where((p) => !p.published).toList();
  List<StoreProduct> get outOfStockListings =>
      products.where((p) => p.published && !p.inStock).toList();

  StoreAdminState copyWith({
    StoreAdminStatus? status,
    StoreLinkState? link,
    List<StoreOrder>? orders,
    StoreOrderStatus? statusFilter,
    bool clearFilter = false,
    String? query,
    List<StoreOrder>? recentOrders,
    StoreOrderStats? stats,
    List<({DateTime day, double revenue, int orders})>? dailyRevenue,
    List<StoreProduct>? products,
    ({int total, int published, int outOfStock})? catalogueCounts,
    List<SyncRow>? syncRows,
    int? syncPushed,
    List<StoreCoupon>? coupons,
    List<StoreReview>? reviews,
    List<StoreCustomer>? customers,
    List<StoreBanner>? banners,
    List<StoreCategory>? categories,
    StoreSettings? settings,
    List<StoreShippingOption>? shippingZones,
    Map<String, bool>? schemaHealth,
    String? message,
    bool clearMessage = false,
  }) =>
      StoreAdminState(
        status: status ?? this.status,
        link: link ?? this.link,
        orders: orders ?? this.orders,
        statusFilter: clearFilter ? null : (statusFilter ?? this.statusFilter),
        query: query ?? this.query,
        recentOrders: recentOrders ?? this.recentOrders,
        stats: stats ?? this.stats,
        dailyRevenue: dailyRevenue ?? this.dailyRevenue,
        products: products ?? this.products,
        catalogueCounts: catalogueCounts ?? this.catalogueCounts,
        syncRows: syncRows ?? this.syncRows,
        syncPushed: syncPushed ?? this.syncPushed,
        coupons: coupons ?? this.coupons,
        reviews: reviews ?? this.reviews,
        customers: customers ?? this.customers,
        banners: banners ?? this.banners,
        categories: categories ?? this.categories,
        settings: settings ?? this.settings,
        shippingZones: shippingZones ?? this.shippingZones,
        schemaHealth: schemaHealth ?? this.schemaHealth,
        message: clearMessage ? null : (message ?? this.message),
      );

  @override
  List<Object?> get props => [
        status, link, orders, statusFilter, query, recentOrders, stats,
        dailyRevenue, products, catalogueCounts, coupons, reviews, customers,
        banners, categories, settings, shippingZones, schemaHealth, message,
      ];
}

// -------------------------------------------------------------------- bloc

/// The e-commerce management console: orders, catalogue, marketing, shoppers
/// and the store's own settings — all in one bloc so the tabs stay in sync.
class StoreAdminBloc extends Bloc<StoreAdminEvent, StoreAdminState> {
  StoreAdminBloc({
    StoreOrderRepository? orders,
    StoreCatalogRepository? catalog,
    StoreAccountRepository? account,
    StoreMarketingRepository? marketing,
    StoreSettingsRepository? settings,
    StoreSyncService? sync,
  })  : _orders = orders ?? StoreOrderRepository(),
        _catalog = catalog ?? StoreCatalogRepository(),
        _account = account ?? StoreAccountRepository(),
        _marketing = marketing ?? StoreMarketingRepository(),
        _settings = settings ?? StoreSettingsRepository(),
        _sync = sync ?? StoreSyncService(),
        super(const StoreAdminState()) {
    on<LoadStoreAdmin>(_onLoad);
    on<FilterAdminOrders>(_onFilterOrders);
    on<SetAdminOrderStatus>(_onSetStatus);
    on<AssignAdminCourier>(_onAssignCourier);
    on<AddAdminOrderNote>(_onAddNote);
    on<DeleteAdminOrder>(_onDeleteOrder);
    on<LoadAdminCatalogue>(_onLoadCatalogue);
    on<PublishAdminProducts>(_onPublish);
    on<SaveAdminProduct>(_onSaveProduct);
    on<DeleteAdminProduct>(_onDeleteProduct);
    on<PreviewShelfSync>(_onPreviewSync);
    on<RunShelfSync>(_onRunSync);
    on<SaveAdminCoupon>(_onSaveCoupon);
    on<ToggleAdminCoupon>(_onToggleCoupon);
    on<DeleteAdminCoupon>(_onDeleteCoupon);
    on<ModerateAdminReview>(_onModerateReview);
    on<DeleteAdminReview>(_onDeleteReview);
    on<SaveAdminBanner>(_onSaveBanner);
    on<DeleteAdminBanner>(_onDeleteBanner);
    on<SaveAdminCategory>(_onSaveCategory);
    on<DeleteAdminCategory>(_onDeleteCategory);
    on<SaveAdminSettings>(_onSaveSettings);
    on<SaveAdminShippingZone>(_onSaveZone);
    on<DeleteAdminShippingZone>(_onDeleteZone);
    on<RecheckStoreLink>(_onRecheck);
  }

  final StoreOrderRepository _orders;
  final StoreCatalogRepository _catalog;
  final StoreAccountRepository _account;
  final StoreMarketingRepository _marketing;
  final StoreSettingsRepository _settings;
  final StoreSyncService _sync;

  StreamSubscription<List<StoreOrder>>? _liveOrders;

  // ------------------------------------------------------------- overview

  Future<void> _onLoad(LoadStoreAdmin event, Emitter<StoreAdminState> emit) async {
    emit(state.copyWith(status: StoreAdminStatus.loading, clearMessage: true));

    if (!storeConnection.isOnline) {
      final link = await storeConnection.connect();
      emit(state.copyWith(link: link));
      if (!link.isLive) {
        emit(state.copyWith(status: StoreAdminStatus.offline));
        return;
      }
    }

    final ordersF = _orders.listOrders();
    final revenueF = _orders.dailyRevenue(days: 7);
    final catalogueF = _catalog.listProducts(includeUnpublished: true, limit: 500);
    final countsF = _catalog.catalogueCounts();
    final couponsF = _marketing.listCoupons();
    final reviewsF = _account.allReviews();
    final customersF = _account.listCustomers();
    final settingsF = _settings.getSettings();
    final zonesF = _settings.listShippingZones();

    final ordersResult = await ordersF;
    final all = ordersResult.fold<List<StoreOrder>>((_) => const [], (v) => v);

    emit(state.copyWith(
      status: ordersResult.fold<bool>((_) => false, (_) => true)
          ? StoreAdminStatus.ready
          : StoreAdminStatus.error,
      link: storeConnection.state,
      orders: all,
      recentOrders: all.take(6).toList(),
      stats: StoreOrderStats.fromOrders(all),
      dailyRevenue: await revenueF.then((r) => r.fold(
          (_) => const <({DateTime day, double revenue, int orders})>[], (v) => v)),
      products: await catalogueF
          .then((r) => r.fold((_) => const <StoreProduct>[], (v) => v)),
      catalogueCounts: await countsF.then((r) => r.fold(
          (_) => (total: 0, published: 0, outOfStock: 0), (v) => v)),
      coupons: await couponsF.then((r) => r.fold((_) => const <StoreCoupon>[], (v) => v)),
      reviews: await reviewsF.then((r) => r.fold((_) => const <StoreReview>[], (v) => v)),
      customers:
          await customersF.then((r) => r.fold((_) => const <StoreCustomer>[], (v) => v)),
      settings: await settingsF
          .then((r) => r.fold((_) => const StoreSettings(), (v) => v)),
      shippingZones: await zonesF
          .then((r) => r.fold((_) => const <StoreShippingOption>[], (v) => v)),
      message: ordersResult.fold<String?>((f) => f.message, (_) => null),
    ));

    _watchOrders(emit);
  }

  /// New web orders land on the board without a refresh.
  void _watchOrders(Emitter<StoreAdminState> emit) {
    _liveOrders?.cancel();
    _liveOrders = _orders.watchOrders().listen((rows) {
      if (rows.isEmpty && state.orders.isEmpty) return;
      emit(state.copyWith(
        orders: rows,
        recentOrders: rows.take(6).toList(),
        stats: StoreOrderStats.fromOrders(rows),
      ));
    });
  }

  // --------------------------------------------------------------- orders

  Future<void> _onFilterOrders(
    FilterAdminOrders event,
    Emitter<StoreAdminState> emit,
  ) async {
    emit(state.copyWith(
      status: StoreAdminStatus.busy,
      statusFilter: event.status,
      clearFilter: event.status == null,
      query: event.query,
    ));
    final result = await _orders.listOrders(
      status: event.status,
      query: event.query.isEmpty ? null : event.query,
    );
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(
          status: StoreAdminStatus.error,
          message: value.message,
        ));
      case Right(:final value):
        emit(state.copyWith(status: StoreAdminStatus.ready, orders: value));
    }
  }

  Future<void> _onSetStatus(
    SetAdminOrderStatus event,
    Emitter<StoreAdminState> emit,
  ) async {
    final index = state.orders.indexWhere((o) => o.id == event.orderId);
    if (index < 0) {
      emit(state.copyWith(message: 'store_error_not_found'));
      return;
    }
    final before = state.orders[index];
    // Optimistic: the board updates instantly, a rollback follows on failure.
    emit(state.copyWith(
      status: StoreAdminStatus.busy,
      orders: state.orders
          .map((o) => o.id == event.orderId
              ? o.copyWith(
                  status: event.status,
                  paid: event.markPaid ? true : o.paid,
                )
              : o)
          .toList(),
    ));

    final result = await _orders.setStatus(
      event.orderId,
      event.status,
      paid: event.markPaid ? true : null,
    );
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(
          status: StoreAdminStatus.error,
          message: value.message,
          orders: [
            ...state.orders.sublist(0, index),
            before,
            ...state.orders.sublist(index + 1),
          ],
        ));
      case Right():
        // A delivery consumes real shelf stock; a refund gives it back.
        if (event.status == StoreOrderStatus.delivered) {
          await _sync.deductStock(before);
          await _catalog.registerSales(
            before.items
                .map((i) => (productId: i.productId, qty: i.quantity))
                .toList(),
          );
        } else if (event.status == StoreOrderStatus.cancelled ||
            event.status == StoreOrderStatus.refunded) {
          await _sync.restoreStock(before);
        }
        emit(state.copyWith(status: StoreAdminStatus.ready));
        add(const LoadStoreAdmin());
    }
  }

  Future<void> _onAssignCourier(
    AssignAdminCourier event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _orders.assignCourier(event.orderId, event.courierId);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        add(const LoadStoreAdmin());
    }
  }

  Future<void> _onAddNote(
    AddAdminOrderNote event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _orders.addNote(event.orderId, event.note);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        add(const LoadStoreAdmin());
    }
  }

  Future<void> _onDeleteOrder(
    DeleteAdminOrder event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _orders.deleteOrder(event.orderId);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          orders: state.orders.where((o) => o.id != event.orderId).toList(),
        ));
    }
  }

  // ------------------------------------------------------------ catalogue

  Future<void> _onLoadCatalogue(
    LoadAdminCatalogue event,
    Emitter<StoreAdminState> emit,
  ) async {
    emit(state.copyWith(status: StoreAdminStatus.busy, clearMessage: true));
    final productsF = _catalog.listProducts(includeUnpublished: true, limit: 500);
    final categoriesF = _catalog.listCategories(activeOnly: false);
    final bannersF = _catalog.listBanners(activeOnly: false);
    emit(state.copyWith(
      status: StoreAdminStatus.ready,
      products: await productsF
          .then((r) => r.fold((_) => const <StoreProduct>[], (v) => v)),
      categories: await categoriesF
          .then((r) => r.fold((_) => const <StoreCategory>[], (v) => v)),
      banners: await bannersF
          .then((r) => r.fold((_) => const <StoreBanner>[], (v) => v)),
    ));
  }

  Future<void> _onPublish(
    PublishAdminProducts event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _catalog.setPublished(event.ids, event.published);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          products: state.products
              .map((p) =>
                  event.ids.contains(p.id) ? p.copyWith(published: event.published) : p)
              .toList(),
          message: event.published ? 'store_published' : 'store_unpublished',
        ));
    }
  }

  Future<void> _onSaveProduct(
    SaveAdminProduct event,
    Emitter<StoreAdminState> emit,
  ) async {
    emit(state.copyWith(status: StoreAdminStatus.busy, clearMessage: true));
    final result = await _catalog.saveProduct(event.product);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(
          status: StoreAdminStatus.error,
          message: value.message,
        ));
      case Right():
        emit(state.copyWith(status: StoreAdminStatus.ready, message: 'store_saved'));
        add(LoadAdminCatalogue());
    }
  }

  Future<void> _onDeleteProduct(
    DeleteAdminProduct event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _catalog.deleteProduct(event.id);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          products: state.products.where((p) => p.id != event.id).toList(),
        ));
    }
  }

  // ----------------------------------------------------------------- sync

  Future<void> _onPreviewSync(
    PreviewShelfSync event,
    Emitter<StoreAdminState> emit,
  ) async {
    emit(state.copyWith(status: StoreAdminStatus.busy, clearMessage: true));
    final result = await _sync.preview();
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(
          status: StoreAdminStatus.error,
          message: value.message,
        ));
      case Right(:final value):
        emit(state.copyWith(
          status: StoreAdminStatus.ready,
          syncRows: value,
        ));
    }
  }

  Future<void> _onRunSync(RunShelfSync event, Emitter<StoreAdminState> emit) async {
    final rows = event.productIds.isEmpty
        ? state.syncRows.where((r) => r.reason.needsPush).toList()
        : state.syncRows.where((r) => event.productIds.contains(r.id)).toList();
    if (rows.isEmpty) {
      emit(state.copyWith(message: 'sync_nothing'));
      return;
    }
    emit(state.copyWith(status: StoreAdminStatus.busy, clearMessage: true));
    final result = await _sync.push(rows);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(
          status: StoreAdminStatus.error,
          message: value.message,
        ));
      case Right(:final value):
        emit(state.copyWith(
          status: StoreAdminStatus.ready,
          message: 'sync_done',
          syncPushed: value,
          syncRows: state.syncRows
              .map((r) => rows.any((p) => p.id == r.id)
                  ? SyncRow(pos: r.pos, listing: r.listing, reason: SyncReason.identical)
                  : r)
              .toList(),
        ));
    }
  }

  // ------------------------------------------------------------ marketing

  Future<void> _onSaveCoupon(
    SaveAdminCoupon event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _marketing.saveCoupon(event.coupon);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          coupons: [
            event.coupon,
            ...state.coupons.where((c) => c.id != event.coupon.id),
          ],
          message: 'store_saved',
        ));
    }
  }

  Future<void> _onToggleCoupon(
    ToggleAdminCoupon event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _marketing.setActive(event.id, event.active);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          coupons: state.coupons
              .map((c) => c.id == event.id
                  ? StoreCoupon(
                      id: c.id,
                      code: c.code,
                      type: c.type,
                      value: c.value,
                      minSpend: c.minSpend,
                      maxDiscount: c.maxDiscount,
                      usageLimit: c.usageLimit,
                      usedCount: c.usedCount,
                      expiresAt: c.expiresAt,
                      active: event.active,
                      description: c.description,
                    )
                  : c)
              .toList(),
        ));
    }
  }

  Future<void> _onDeleteCoupon(
    DeleteAdminCoupon event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _marketing.deleteCoupon(event.id);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          coupons: state.coupons.where((c) => c.id != event.id).toList(),
        ));
    }
  }

  Future<void> _onModerateReview(
    ModerateAdminReview event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _account.setApproved(event.id, event.approved);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          reviews: state.reviews
              .map((r) => r.id == event.id
                  ? StoreReview(
                      id: r.id,
                      productId: r.productId,
                      productName: r.productName,
                      customerName: r.customerName,
                      customerId: r.customerId,
                      rating: r.rating,
                      comment: r.comment,
                      approved: event.approved,
                      createdAt: r.createdAt,
                    )
                  : r)
              .toList(),
        ));
    }
  }

  Future<void> _onDeleteReview(
    DeleteAdminReview event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _account.deleteReview(event.id);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          reviews: state.reviews.where((r) => r.id != event.id).toList(),
        ));
    }
  }

  Future<void> _onSaveBanner(
    SaveAdminBanner event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _catalog.saveBanner(event.banner);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        add(LoadAdminCatalogue());
    }
  }

  Future<void> _onDeleteBanner(
    DeleteAdminBanner event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _catalog.deleteBanner(event.id);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          banners: state.banners.where((b) => b.id != event.id).toList(),
        ));
    }
  }

  Future<void> _onSaveCategory(
    SaveAdminCategory event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _catalog.saveCategory(event.category);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        add(LoadAdminCatalogue());
    }
  }

  Future<void> _onDeleteCategory(
    DeleteAdminCategory event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _catalog.deleteCategory(event.id);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          categories: state.categories.where((c) => c.id != event.id).toList(),
        ));
    }
  }

  // ------------------------------------------------------------- settings

  Future<void> _onSaveSettings(
    SaveAdminSettings event,
    Emitter<StoreAdminState> emit,
  ) async {
    emit(state.copyWith(status: StoreAdminStatus.busy, clearMessage: true));
    final result = await _settings.saveSettings(event.settings);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(
          status: StoreAdminStatus.error,
          message: value.message,
        ));
      case Right():
        emit(state.copyWith(
          status: StoreAdminStatus.ready,
          settings: event.settings,
          message: 'store_saved',
        ));
    }
  }

  Future<void> _onSaveZone(
    SaveAdminShippingZone event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _settings.saveShippingZone(event.zone);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          shippingZones: [
            event.zone,
            ...state.shippingZones.where((z) => z.id != event.zone.id),
          ],
          message: 'store_saved',
        ));
    }
  }

  Future<void> _onDeleteZone(
    DeleteAdminShippingZone event,
    Emitter<StoreAdminState> emit,
  ) async {
    final result = await _settings.deleteShippingZone(event.id);
    switch (result) {
      case Left(:final value):
        emit(state.copyWith(message: value.message));
      case Right():
        emit(state.copyWith(
          shippingZones: state.shippingZones.where((z) => z.id != event.id).toList(),
        ));
    }
  }

  Future<void> _onRecheck(
    RecheckStoreLink event,
    Emitter<StoreAdminState> emit,
  ) async {
    emit(state.copyWith(status: StoreAdminStatus.busy, clearMessage: true));
    final link = await storeConnection.connect(force: true);
    emit(state.copyWith(link: link));
    if (!link.isLive) {
      emit(state.copyWith(
        status: StoreAdminStatus.offline,
        message: storeConnection.lastError,
      ));
      return;
    }
    final health = await _settings.schemaHealth();
    emit(state.copyWith(
      status: StoreAdminStatus.ready,
      schemaHealth: health.fold((_) => const <String, bool>{}, (v) => v),
      message: 'store_link_ok',
    ));
  }

  @override
  Future<void> close() {
    _liveOrders?.cancel();
    return super.close();
  }
}
