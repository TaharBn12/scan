import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/supabase/store_connection.dart';
import '../../data/repositories/store_catalog_repository.dart';
import '../../data/repositories/store_settings_repository.dart';
import '../../domain/entities/store_banner.dart';
import '../../domain/entities/store_category.dart';
import '../../domain/entities/store_product.dart';
import '../../domain/entities/store_settings.dart';

// ------------------------------------------------------------------ events

abstract class StoreCatalogEvent extends Equatable {
  const StoreCatalogEvent();
  @override
  List<Object?> get props => [];
}

/// Loads categories, banners and store settings; safe to call on every visit.
class LoadStorefront extends StoreCatalogEvent {}

class SearchStore extends StoreCatalogEvent {
  final String query;
  const SearchStore(this.query);
  @override
  List<Object?> get props => [query];
}

class FilterStoreCategory extends StoreCatalogEvent {
  final String categoryId;
  const FilterStoreCategory(this.categoryId);
  @override
  List<Object?> get props => [categoryId];
}

class SortStore extends StoreCatalogEvent {
  final StoreSort sort;
  const SortStore(this.sort);
  @override
  List<Object?> get props => [sort];
}

class ToggleOnSaleOnly extends StoreCatalogEvent {}

class LoadMoreStoreProducts extends StoreCatalogEvent {}

class OpenProduct extends StoreCatalogEvent {
  final String id;
  const OpenProduct(this.id);
  @override
  List<Object?> get props => [id];
}

// ------------------------------------------------------------------- state

enum StoreCatalogStatus { initial, loading, ready, error, offline }

class StoreCatalogState extends Equatable {
  final StoreCatalogStatus status;
  final List<StoreProduct> products;
  final List<StoreCategory> categories;
  final List<StoreBanner> banners;
  final StoreSettings settings;
  final StoreProduct? selected;
  final String query;
  final String categoryId;
  final StoreSort sort;
  final bool onSaleOnly;
  final bool hasMore;
  final bool loadingMore;
  final String? message;

  const StoreCatalogState({
    this.status = StoreCatalogStatus.initial,
    this.products = const [],
    this.categories = const [],
    this.banners = const [],
    this.settings = const StoreSettings(),
    this.selected,
    this.query = '',
    this.categoryId = '',
    this.sort = StoreSort.newest,
    this.onSaleOnly = false,
    this.hasMore = true,
    this.loadingMore = false,
    this.message,
  });

  bool get isEmpty => status == StoreCatalogStatus.ready && products.isEmpty;
  bool get browsingAll => categoryId.isEmpty && query.isEmpty && !onSaleOnly;

  StoreCatalogState copyWith({
    StoreCatalogStatus? status,
    List<StoreProduct>? products,
    List<StoreCategory>? categories,
    List<StoreBanner>? banners,
    StoreSettings? settings,
    StoreProduct? selected,
    bool clearSelected = false,
    String? query,
    String? categoryId,
    StoreSort? sort,
    bool? onSaleOnly,
    bool? hasMore,
    bool? loadingMore,
    String? message,
    bool clearMessage = false,
  }) =>
      StoreCatalogState(
        status: status ?? this.status,
        products: products ?? this.products,
        categories: categories ?? this.categories,
        banners: banners ?? this.banners,
        settings: settings ?? this.settings,
        selected: clearSelected ? null : (selected ?? this.selected),
        query: query ?? this.query,
        categoryId: categoryId ?? this.categoryId,
        sort: sort ?? this.sort,
        onSaleOnly: onSaleOnly ?? this.onSaleOnly,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        message: clearMessage ? null : (message ?? this.message),
      );

  @override
  List<Object?> get props => [
        status, products, categories, banners, settings, selected, query,
        categoryId, sort, onSaleOnly, hasMore, loadingMore, message,
      ];
}

// -------------------------------------------------------------------- bloc

/// Drives every storefront browsing screen (home, category, search, offers).
class StoreCatalogBloc extends Bloc<StoreCatalogEvent, StoreCatalogState> {
  StoreCatalogBloc({
    StoreCatalogRepository? catalog,
    StoreSettingsRepository? settings,
  })  : _catalog = catalog ?? StoreCatalogRepository(),
        _settings = settings ?? StoreSettingsRepository(),
        super(const StoreCatalogState()) {
    on<LoadStorefront>(_onLoad);
    on<SearchStore>(_onSearch);
    on<FilterStoreCategory>(_onFilter);
    on<SortStore>(_onSort);
    on<ToggleOnSaleOnly>(_onToggleSale);
    on<LoadMoreStoreProducts>(_onLoadMore);
    on<OpenProduct>(_onOpen);
  }

  static const int _pageSize = 24;

  final StoreCatalogRepository _catalog;
  final StoreSettingsRepository _settings;
  StreamSubscription<List<StoreProduct>>? _live;

  Future<void> _onLoad(LoadStorefront event, Emitter<StoreCatalogState> emit) async {
    emit(state.copyWith(status: StoreCatalogStatus.loading, clearMessage: true));

    if (!storeConnection.isOnline) {
      final linked = await storeConnection.connect();
      if (!linked.isLive) {
        emit(state.copyWith(
          status: StoreCatalogStatus.offline,
          message: linked.labelKey,
        ));
        return;
      }
    }

    // Four independent round trips, fired together and awaited one by one so
    // each keeps its own static type (no `dynamic` folds).
    final categoriesF = _catalog.listCategories();
    final bannersF = _catalog.listBanners();
    final settingsF = _settings.getSettings();
    final productsF = _query(offset: 0);

    final categories = await categoriesF.then<List<StoreCategory>>(
        (r) => r.fold((_) => const <StoreCategory>[], (v) => v));
    final banners = await bannersF.then<List<StoreBanner>>(
        (r) => r.fold((_) => const <StoreBanner>[], (v) => v));
    final settings = await settingsF.then<StoreSettings>(
        (r) => r.fold((_) => const StoreSettings(), (v) => v));
    final productsResult = await productsF;
    final products = productsResult.fold<List<StoreProduct>>(
        (_) => const <StoreProduct>[], (v) => v);
    final failed = productsResult.fold<String?>((f) => f.message, (_) => null);

    emit(state.copyWith(
      status: failed == null ? StoreCatalogStatus.ready : StoreCatalogStatus.error,
      categories: categories,
      banners: banners,
      settings: settings,
      products: products,
      hasMore: products.length >= _pageSize,
      message: failed,
    ));

    _watchLive(emit);
  }

  /// Keeps the grid honest while the merchant edits the catalogue elsewhere.
  void _watchLive(Emitter<StoreCatalogState> emit) {
    _live?.cancel();
    _live = _catalog.watchProducts().listen((rows) {
      final filtered = _applyClientFilters(rows);
      if (filtered.isEmpty && state.products.isEmpty) return;
      emit(state.copyWith(products: filtered, hasMore: false));
    });
  }

  List<StoreProduct> _applyClientFilters(List<StoreProduct> rows) {
    var out = rows.where((p) => p.published).toList();
    if (state.categoryId.isNotEmpty) {
      out = out.where((p) => p.categoryId == state.categoryId).toList();
    }
    if (state.onSaleOnly) {
      out = out.where((p) => p.onSale).toList();
    }
    if (state.query.trim().isNotEmpty) {
      final needle = state.query.trim().toLowerCase();
      out = out
          .where((p) =>
              p.name.toLowerCase().contains(needle) ||
              p.nameAr.contains(needle) ||
              p.sku.toLowerCase().contains(needle) ||
              p.barcode.contains(needle))
          .toList();
    }
    return _sorted(out);
  }

  List<StoreProduct> _sorted(List<StoreProduct> rows) {
    final out = [...rows];
    switch (state.sort) {
      case StoreSort.newest:
        out.sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
      case StoreSort.priceAsc:
        out.sort((a, b) => a.price.compareTo(b.price));
      case StoreSort.priceDesc:
        out.sort((a, b) => b.price.compareTo(a.price));
      case StoreSort.bestSelling:
        out.sort((a, b) => b.soldCount.compareTo(a.soldCount));
      case StoreSort.rating:
        out.sort((a, b) => b.rating.compareTo(a.rating));
      case StoreSort.name:
        out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return out;
  }

  Future<void> _onSearch(SearchStore event, Emitter<StoreCatalogState> emit) =>
      _reload(emit, query: event.query);

  Future<void> _onFilter(FilterStoreCategory event, Emitter<StoreCatalogState> emit) =>
      _reload(emit, categoryId: event.categoryId);

  Future<void> _onSort(SortStore event, Emitter<StoreCatalogState> emit) =>
      _reload(emit, sort: event.sort);

  Future<void> _onToggleSale(ToggleOnSaleOnly event, Emitter<StoreCatalogState> emit) =>
      _reload(emit, onSaleOnly: !state.onSaleOnly);

  Future<void> _reload(
    Emitter<StoreCatalogState> emit, {
    String? query,
    String? categoryId,
    StoreSort? sort,
    bool? onSaleOnly,
  }) async {
    emit(state.copyWith(
      status: StoreCatalogStatus.loading,
      query: query,
      categoryId: categoryId,
      sort: sort,
      onSaleOnly: onSaleOnly,
      clearMessage: true,
    ));
    final result = await _query(offset: 0);
    result.fold(
      (failure) => emit(state.copyWith(
        status: StoreCatalogStatus.error,
        message: failure.message,
      )),
      (rows) => emit(state.copyWith(
        status: StoreCatalogStatus.ready,
        products: rows,
        hasMore: rows.length >= _pageSize,
      )),
    );
  }

  Future<void> _onLoadMore(
    LoadMoreStoreProducts event,
    Emitter<StoreCatalogState> emit,
  ) async {
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    final result = await _query(offset: state.products.length);
    result.fold(
      (failure) =>
          emit(state.copyWith(loadingMore: false, message: failure.message)),
      (rows) => emit(state.copyWith(
        loadingMore: false,
        products: [...state.products, ...rows],
        hasMore: rows.length >= _pageSize,
      )),
    );
  }

  Future<void> _onOpen(OpenProduct event, Emitter<StoreCatalogState> emit) async {
    final result = await _catalog.getProduct(event.id);
    result.fold(
      (failure) => emit(state.copyWith(message: failure.message)),
      (product) => emit(state.copyWith(
        selected: product,
        clearSelected: product == null,
        message: product == null ? 'store_error_not_found' : null,
      )),
    );
  }

  /// One query built from the current filters; shared by every reload path.
  Future<Either<Failure, List<StoreProduct>>> _query({required int offset}) =>
      _catalog.listProducts(
        categoryId: state.categoryId.isEmpty ? null : state.categoryId,
        query: state.query.isEmpty ? null : state.query,
        onSaleOnly: state.onSaleOnly,
        sort: state.sort,
        limit: _pageSize,
        offset: offset,
      );

  @override
  Future<void> close() {
    _live?.cancel();
    return super.close();
  }
}
