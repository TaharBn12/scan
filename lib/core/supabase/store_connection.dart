import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store_schema.dart';
import 'supabase_config.dart';

/// Live state of the link with the e-commerce site.
enum StoreLinkState {
  /// Nothing has been tried yet.
  unknown,

  /// No URL / anon key available — the merchant must fill the connection form.
  notConfigured,

  /// Handshake in flight.
  connecting,

  /// Talking to Supabase.
  online,

  /// Configured but unreachable (offline, wrong key, project paused).
  offline,
}

extension StoreLinkStateX on StoreLinkState {
  String get labelKey => switch (this) {
        StoreLinkState.unknown => 'store_link_unknown',
        StoreLinkState.notConfigured => 'store_link_not_configured',
        StoreLinkState.connecting => 'store_link_connecting',
        StoreLinkState.online => 'store_link_online',
        StoreLinkState.offline => 'store_link_offline',
      };

  bool get isLive => this == StoreLinkState.online;
}

/// The storefront account currently signed in (a shopper, or the merchant
/// browsing his own store). Null = guest checkout.
class StoreSession {
  final String id;
  final String email;
  final String name;

  const StoreSession({required this.id, required this.email, this.name = ''});

  bool get isGuest => false;

  @override
  String toString() => 'StoreSession($email)';
}

/// Single gateway to the e-commerce Supabase project.
///
/// Everything the store features do goes through [client], and every screen
/// watches [state] so an offline phone degrades to empty states instead of
/// throwing. Initialisation is lazy and never blocks app start: a shop with
/// no storefront configured keeps using the POS exactly as before.
class StoreConnection extends ChangeNotifier {
  StoreConnection._();

  static final StoreConnection instance = StoreConnection._();

  SupabaseClient? _client;
  ResolvedSupabaseConfig _config = const ResolvedSupabaseConfig(url: '', anonKey: '');
  StoreLinkState _state = StoreLinkState.unknown;
  StoreSession? _session;
  String? _lastError;
  DateTime? _connectedAt;

  /// True when the link answered but this schema has no settings table.
  bool missingSettingsTable = false;
  StreamSubscription<AuthState>? _authSub;

  StoreLinkState get state => _state;
  ResolvedSupabaseConfig get config => _config;
  StoreSession? get session => _session;
  String? get lastError => _lastError;
  DateTime? get connectedAt => _connectedAt;
  bool get isConfigured => _config.isConfigured;
  bool get isOnline => _state == StoreLinkState.online;

  /// Throws-safe accessor: repositories check [isOnline] before using it.
  SupabaseClient? get client => _client;

  /// Brings the link up. Safe to call repeatedly (settings changes, retries).
  /// Returns the resulting state so callers can react immediately.
  Future<StoreLinkState> connect({bool force = false}) async {
    final resolved = SupabaseConfig.resolve();
    if (!resolved.isConfigured) {
      _config = resolved;
      _set(StoreLinkState.notConfigured);
      return _state;
    }
    if (!force && _client != null && resolved.url == _config.url && _state == StoreLinkState.online) {
      return _state;
    }
    _config = resolved;
    _set(StoreLinkState.connecting);
    try {
      if (force || _client == null) {
        await Supabase.initialize(
          url: resolved.url,
          anonKey: resolved.anonKey,
          // PKCE + the default on-device storage, so a shopper stays signed
          // in across restarts without the POS owning any of it.
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
        _client = Supabase.instance.client;
      }
      await _probe();
      _lastError = null;
      _connectedAt = DateTime.now();
      _listenAuth();
      _set(StoreLinkState.online);
      debugPrint('[store] connected to ${resolved.projectRef}');
    } catch (error) {
      _lastError = '$error';
      _client = null;
      _set(StoreLinkState.offline);
      debugPrint('[store] connect failed: $error');
    }
    return _state;
  }

  /// Round trip that proves the URL + anon key are accepted.
  ///
  /// A missing table is *not* a connection failure: PostgREST answered, so
  /// the link is up and only the schema differs (see [missingSettingsTable]).
  Future<void> _probe() async {
    try {
      await _client!.from(StoreSchema.settings).select('*').limit(1).maybeSingle();
      missingSettingsTable = false;
    } on PostgrestException catch (error) {
      missingSettingsTable = true;
      debugPrint('[store] settings table absent: ${error.message}');
    }
  }

  void _listenAuth() {
    _authSub?.cancel();
    final auth = _client?.auth;
    if (auth == null) return;
    _syncSession(auth.currentUser);
    _authSub = auth.onAuthStateChange.listen((event) {
      _syncSession(event.session?.user);
    });
  }

  void _syncSession(User? user) {
    if (user == null) {
      if (_session != null) {
        _session = null;
        notifyListeners();
      }
      return;
    }
    final meta = user.userMetadata ?? const {};
    _session = StoreSession(
      id: user.id,
      email: user.email ?? '',
      name: (meta['full_name'] ?? meta['name'] ?? '').toString(),
    );
    notifyListeners();
  }

  // ------------------------------------------------------------- auth

  Future<void> signIn({required String email, required String password}) async {
    await _requireClient();
    await _client!.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    await _requireClient();
    await _client!.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name, 'phone': phone},
    );
  }

  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {
      // Signing out must never strand the user in the app.
    }
    _session = null;
    notifyListeners();
  }

  void _requireClient() {
    if (_client == null) {
      throw StateError('StoreConnection: not connected');
    }
  }

  /// Realtime feed for a table, filtered by column when provided.
  Stream<List<Map<String, dynamic>>> watch(
    String table, {
    Map<String, Object?>? filter,
  }) {
    final from = _client?.from(table);
    if (from == null) return const Stream.empty();
    return from.stream(primaryKey: const ['id']).map((rows) {
      final list = rows.whereType<Map<String, dynamic>>().toList();
      if (filter == null) return list;
      return list.where((row) {
        return filter.entries.every((e) => '${row[e.key]}' == '${e.value}');
      }).toList();
    });
  }

  void _set(StoreLinkState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

/// Convenience global, mirroring `cloudAuth` / `sessionController`.
final StoreConnection storeConnection = StoreConnection.instance;
