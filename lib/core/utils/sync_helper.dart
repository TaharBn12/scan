import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../data/hive_database.dart';
import '../sync/cloud_sync_helper.dart';
import '../sync/sync_queue.dart';
import '../../features/product/domain/entities/product.dart';

/// Result of a full sync run, for the settings screen toast.
class SyncResult {
  final bool ok;
  final int pushed;
  final int pulledProducts;
  final String? error;

  const SyncResult({
    required this.ok,
    this.pushed = 0,
    this.pulledProducts = 0,
    this.error,
  });
}

/// Talks to the merchant's own website.
///
/// Two channels:
///  1. **Scan feed** (legacy): every barcode scanned is POSTed to the URL the
///     merchant configured. Fire and forget.
///  2. **Two-way sync**: the app keeps an outbox ([SyncQueue]) of changed
///     products / sales / customers / expenses / purchases / stock movements
///     and pushes them to `<base>/api/sync/push`; then it pulls products
///     changed on the website since the last sync from
///     `<base>/api/sync/products?since=<iso>` and merges them locally.
///
/// All requests carry `Authorization: Bearer <token>` where token is the
/// random id generated once per phone (shown in Settings so the merchant can
/// paste it into their website).
///
/// Expected JSON contract (documented for whoever builds the website):
///
/// POST /api/sync/push
///   { "token": "...", "changes": [ {"entity":"product","op":"upsert",
///     "id":"...", "data":{...}}, {"entity":"sale","op":"delete","id":"..."} ] }
///   -> 200 { "ok": true }
///
/// GET /api/sync/products?since=2024-01-01T00:00:00.000Z
///   -> 200 { "products": [ {product map...}, ... ], "deleted": ["id", ...] }
class SyncHelper {
  static const _tokenKey = 'sync_token';
  static const _urlKey = 'sync_url';
  static const _enabledKey = 'sync_enabled';
  static const _fullSyncEnabledKey = 'full_sync_enabled';
  static const _autoSyncKey = 'auto_sync_enabled';
  static const _lastSyncKey = 'last_sync_at';
  static const _lastPullKey = 'last_pull_at';

  static bool _running = false;

  /// The token identifying this phone/shop.
  static String getOrCreateToken() {
    final existing = HiveDatabase.settingsBox.get(_tokenKey) as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final token = const Uuid().v4();
    HiveDatabase.settingsBox.put(_tokenKey, token);
    return token;
  }

  static String? getUrl() => HiveDatabase.settingsBox.get(_urlKey) as String?;

  static Future<void> setUrl(String url) async {
    await HiveDatabase.settingsBox.put(_urlKey, url.trim());
  }

  static bool isEnabled() =>
      HiveDatabase.settingsBox.get(_enabledKey) as bool? ?? false;

  static Future<void> setEnabled(bool value) async {
    await HiveDatabase.settingsBox.put(_enabledKey, value);
  }

  static bool isFullSyncEnabled() =>
      HiveDatabase.settingsBox.get(_fullSyncEnabledKey) as bool? ?? false;

  static Future<void> setFullSyncEnabled(bool value) async {
    await HiveDatabase.settingsBox.put(_fullSyncEnabledKey, value);
  }

  static bool isAutoSyncEnabled() =>
      HiveDatabase.settingsBox.get(_autoSyncKey) as bool? ?? false;

  static Future<void> setAutoSyncEnabled(bool value) async {
    await HiveDatabase.settingsBox.put(_autoSyncKey, value);
  }

  static DateTime? lastSyncAt() {
    final raw = HiveDatabase.settingsBox.get(_lastSyncKey) as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static int get pendingCount => SyncQueue.length;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${getOrCreateToken()}',
      };

  /// Base URL without trailing slash and without a legacy "/api/scan" path,
  /// so both "https://shop.example.com" and ".../api/scan" work.
  static String? _baseUrl() {
    final raw = getUrl();
    if (raw == null || raw.trim().isEmpty) return null;
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    for (final suffix in ['/api/scan', '/api/scans', '/scan']) {
      if (url.endsWith(suffix)) {
        url = url.substring(0, url.length - suffix.length);
        break;
      }
    }
    return url;
  }

  // ---------------------------------------------------------------- scans

  /// Fire-and-forget: sends the scan to the configured website. Never
  /// throws - a slow/unreachable website should never block or crash the
  /// scanning/checkout flow.
  static Future<void> sendScan({
    required String barcode,
    String? productName,
    double? price,
  }) async {
    if (!isEnabled()) return;
    final url = getUrl();
    if (url == null || url.trim().isEmpty) return;

    try {
      await http
          .post(
            Uri.parse(url.trim()),
            headers: _headers,
            body: jsonEncode({
              'token': getOrCreateToken(),
              'barcode': barcode,
              'productName': productName,
              'price': price,
              'scannedAt': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Silently ignore network errors - best-effort side channel.
    }
  }

  // ------------------------------------------------------------ full sync

  /// Called after every sale/product change when auto-sync is on. Never
  /// throws, never blocks the UI (caller doesn't await). Runs every
  /// channel that is switched on: the merchant website and/or the cloud
  /// (Firebase) sync — both drain the same outbox.
  static Future<void> autoSync() async {
    final websiteOn = isFullSyncEnabled() && isAutoSyncEnabled();
    final cloudOn =
        CloudSyncHelper.isAutoSyncEnabled() && CloudSyncHelper.hasConfig();
    if (!websiteOn && !cloudOn) return;
    if (websiteOn) {
      try {
        await syncAll();
      } catch (_) {}
    }
    if (cloudOn) {
      try {
        await CloudSyncHelper.syncAll();
      } catch (_) {}
    }
  }

  /// Pushes all queued changes, then pulls product changes from the website.
  static Future<SyncResult> syncAll() async {
    final base = _baseUrl();
    if (base == null) {
      return const SyncResult(ok: false, error: 'No website URL configured');
    }
    if (_running) return const SyncResult(ok: true);
    _running = true;
    try {
      final pushed = await _push(base);
      final pulled = await _pullProducts(base);
      await HiveDatabase.settingsBox
          .put(_lastSyncKey, DateTime.now().toIso8601String());
      return SyncResult(ok: true, pushed: pushed, pulledProducts: pulled);
    } catch (e) {
      return SyncResult(ok: false, error: e.toString());
    } finally {
      _running = false;
    }
  }

  static Future<int> _push(String base) async {
    final pending = SyncQueue.pending();
    if (pending.isEmpty) return 0;

    int pushedTotal = 0;
    // Send in batches so a big backlog doesn't create one giant request.
    for (int i = 0; i < pending.length; i += 100) {
      final batch = pending.sublist(
          i, i + 100 > pending.length ? pending.length : i + 100);
      final changes = <Map<String, dynamic>>[];
      for (final item in batch) {
        final entity = item['entity'] as String;
        final id = item['id'] as String;
        final op = item['op'] as String;
        changes.add({
          'entity': entity,
          'op': op,
          'id': id,
          if (op == SyncQueue.opUpsert) 'data': dataFor(entity, id),
          'queuedAt': item['queuedAt'],
        });
      }

      final response = await http
          .post(
            Uri.parse('$base/api/sync/push'),
            headers: _headers,
            body: jsonEncode({
              'token': getOrCreateToken(),
              'deviceTime': DateTime.now().toIso8601String(),
              'changes': changes,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode} from /api/sync/push');
      }

      for (final item in batch) {
        await SyncQueue.remove(item['entity'] as String, item['id'] as String);
      }
      pushedTotal += batch.length;
    }
    return pushedTotal;
  }

  /// Current local map for one outbox record. Public because the cloud
  /// sync (CloudSyncHelper) pushes the exact same payload to Firestore.
  static Map<String, dynamic>? dataFor(String entity, String id) {
    switch (entity) {
      case 'product':
        return HiveDatabase.productBox.get(id)?.toMap();
      case 'sale':
        return _mapFrom(HiveDatabase.salesBox.get(id));
      case 'customer':
        return _mapFrom(HiveDatabase.customersBox.get(id));
      case 'expense':
        return _mapFrom(HiveDatabase.expensesBox.get(id));
      case 'purchase':
        return _mapFrom(HiveDatabase.purchasesBox.get(id));
      case 'stock_movement':
        return _mapFrom(HiveDatabase.stockMovementsBox.get(id));
      default:
        return null;
    }
  }

  static Map<String, dynamic>? _mapFrom(dynamic raw) =>
      raw == null ? null : Map<String, dynamic>.from(raw as Map);

  static Future<int> _pullProducts(String base) async {
    final since = HiveDatabase.settingsBox.get(_lastPullKey) as String? ?? '';
    final uri = Uri.parse('$base/api/sync/products').replace(
      queryParameters: {
        'token': getOrCreateToken(),
        if (since.isNotEmpty) 'since': since,
      },
    );
    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));

    // A website that only implements push is fine: treat 404 as "nothing".
    if (response.statusCode == 404) return 0;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode} from /api/sync/products');
    }

    final decoded = jsonDecode(response.body);
    final List list = decoded is Map
        ? (decoded['products'] as List? ?? const [])
        : (decoded is List ? decoded : const []);
    final List deleted =
        decoded is Map ? (decoded['deleted'] as List? ?? const []) : const [];

    int count = 0;
    final box = HiveDatabase.productBox;
    for (final raw in list) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      if ((map['id'] as String?)?.isEmpty ?? true) continue;
      final remote = Product.fromMap(map);
      final local = box.get(remote.id);
      // Last-write-wins on updatedAt; local edits made after the website's
      // version are kept (and will be pushed on the next run).
      if (local != null &&
          local.updatedAt != null &&
          remote.updatedAt != null &&
          local.updatedAt!.isAfter(remote.updatedAt!)) {
        continue;
      }
      await box.put(remote.id, remote);
      // Don't echo the website's own change back to it.
      await SyncQueue.remove('product', remote.id);
      count++;
    }
    for (final id in deleted) {
      if (id is String && box.containsKey(id)) {
        await box.delete(id);
        await SyncQueue.remove('product', id);
        count++;
      }
    }

    await HiveDatabase.settingsBox
        .put(_lastPullKey, DateTime.now().toUtc().toIso8601String());
    return count;
  }

  /// Queues every record for upload (first-time link of an existing shop).
  static Future<void> enqueueEverything() async {
    for (final p in HiveDatabase.productBox.values) {
      await SyncQueue.enqueue('product', p.id, SyncQueue.opUpsert);
    }
    for (final key in HiveDatabase.salesBox.keys) {
      await SyncQueue.enqueue('sale', key.toString(), SyncQueue.opUpsert);
    }
    for (final key in HiveDatabase.customersBox.keys) {
      await SyncQueue.enqueue('customer', key.toString(), SyncQueue.opUpsert);
    }
    for (final key in HiveDatabase.expensesBox.keys) {
      await SyncQueue.enqueue('expense', key.toString(), SyncQueue.opUpsert);
    }
    for (final key in HiveDatabase.purchasesBox.keys) {
      await SyncQueue.enqueue('purchase', key.toString(), SyncQueue.opUpsert);
    }
  }
}
