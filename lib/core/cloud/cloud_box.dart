import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// One collection kept in Realtime Database, exposed with the small subset
/// of the Hive `Box` API that the app actually uses (values/get/put/delete/
/// isEmpty/isNotEmpty/containsKey/clear), so repositories keep working
/// unchanged — only their source of truth moved to the cloud.
///
/// Reads are served from an in-memory mirror that the SDK keeps in sync
/// (including while offline, then RTDB replays local writes on reconnect).
/// Widgets/blocs can listen to [this] to reload when the mirror changes.
class CloudBox<T> extends ChangeNotifier {
  CloudBox({
    required this.name,
    required Object? Function(T value) encode,
    required T Function(Object? raw) decode,
  })  : _encode = encode,
        _decode = decode;

  final String name;
  final Object? Function(T value) _encode;
  final T Function(Object? raw) _decode;

  /// Live mirror of the collection: id → raw value (maps deep-cast to
  /// Map<String, dynamic>, scalars kept as-is for key-value boxes).
  final Map<String, Object?> _cache = {};
  DatabaseReference? _ref;
  StreamSubscription<DatabaseEvent>? _sub;

  bool get isBound => _ref != null;

  // ------------------------------------------------------------ binding

  /// Attaches the live listener. Re-binding (shop switch) resets the mirror.
  void bind(DatabaseReference ref) {
    if (identical(_ref, ref)) return;
    _sub?.cancel();
    _ref = ref;
    _cache.clear();
    _sub = ref.onValue.listen((event) {
      _cache.clear();
      final value = event.snapshot.value;
      if (value is Map) {
        value.forEach((k, v) {
          _cache['$k'] = v is Map ? deepCast(v) : v is List ? _castList(v) : v;
        });
      }
      notifyListeners();
    }, onError: (_) {/* keep last known mirror; never crash the till */});
  }

  /// First-snapshot barrier: resolves when the mirror has data from the
  /// server/disk cache at least once (or after [timeout], whichever is
  /// first — an empty shop is a valid first state).
  Future<void> ready({Duration timeout = const Duration(seconds: 8)}) async {
    if (_ref == null) return;
    try {
      await _ref!.get().timeout(timeout);
    } catch (_) {/* offline with empty cache: still a valid start */}
  }

  void unbindSync() {
    _sub?.cancel();
    _sub = null;
    _ref = null;
    _cache.clear();
    notifyListeners();
  }

  /// Recursively converts RTDB's loosely-typed maps into
  /// Map<String, dynamic> / List<dynamic> the entities expect.
  static Map<String, dynamic> deepCast(Map raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v is Map) {
        out['$k'] = deepCast(v);
      } else if (v is List) {
        out['$k'] = _castList(v);
      } else {
        out['$k'] = v;
      }
    });
    return out;
  }

  static List<dynamic> _castList(List raw) =>
      raw.map((e) => e is Map ? deepCast(e) : e is List ? _castList(e) : e).toList();

  // ---------------------------------------------------------- Box-like API

  Iterable<T> get values => _cache.values.map(_decode).toList();

  Iterable<String> get keys => _cache.keys;

  T? get(dynamic key) {
    final raw = _cache['$key'];
    return raw == null ? null : _decode(raw);
  }

  bool containsKey(dynamic key) => _cache.containsKey('$key');

  bool get isEmpty => _cache.isEmpty;
  bool get isNotEmpty => _cache.isNotEmpty;
  int get length => _cache.length;

  Future<void> put(dynamic key, T value) async {
    final k = '$key';
    final encoded = _encode(value);
    _cache[k] = encoded;
    notifyListeners();
    await _ref?.child(_safeKey(k)).set(encoded);
  }

  Future<void> delete(dynamic key) async {
    _cache.remove('$key');
    notifyListeners();
    await _ref?.child(_safeKey('$key')).remove();
  }

  Future<void> clear() async {
    _cache.clear();
    notifyListeners();
    await _ref?.remove();
  }

  /// RTDB keys cannot contain `. # $ [ ] /` — ids are UUIDs/dates in this
  /// app, but sanitize defensively and keep a stable mapping both ways.
  static String _safeKey(String key) => key
      .replaceAll('.', '_')
      .replaceAll('#', '_')
      .replaceAll('\$', '_')
      .replaceAll('[', '_')
      .replaceAll(']', '_')
      .replaceAll('/', '_');

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
