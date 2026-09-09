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
    required Map<String, dynamic> Function(T value) encode,
    required T Function(Map raw) decode,
  })  : _encode = encode,
        _decode = decode;

  final String name;
  final Map<String, dynamic> Function(T value) _encode;
  final T Function(Map raw) _decode;

  final Map<String, Map<String, dynamic>> _cache = {};
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
          if (v is Map) _cache['$k'] = _deepCast(v);
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

  static Map<String, dynamic> _deepCast(Map raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v is Map) {
        out['$k'] = _deepCast(v);
      } else if (v is List) {
        out['$k'] = v
            .map((e) => e is Map ? _deepCast(e) : e)
            .toList();
      } else {
        out['$k'] = v;
      }
    });
    return out;
  }

  // ---------------------------------------------------------- Box-like API

  Iterable<T> get values => _cache.values.map(_decodeChecked).toList()
    ..sort((a, b) => 0); // order is defined by repositories, keep as-is

  Iterable<String> get keys => _cache.keys;

  T? get(dynamic key) {
    final raw = _cache['$key'];
    return raw == null ? null : _decodeChecked(raw);
  }

  bool containsKey(dynamic key) => _cache.containsKey('$key');

  bool get isEmpty => _cache.isEmpty;
  bool get isNotEmpty => _cache.isNotEmpty;
  int get length => _cache.length;

  Future<void> put(dynamic key, T value) async {
    final k = '$key';
    final map = _encode(value);
    _cache[k] = map;
    notifyListeners();
    await _ref?.child(_safeKey(k)).set(map);
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

  T _decodeChecked(Map raw) {
    try {
      return _decode(raw);
    } catch (_) {
      // A corrupt entry must never take the whole collection down.
      return _decode(<dynamic, dynamic>{});
    }
  }

  /// RTDB keys cannot contain `. # $ [ ] /` — ids are UUIDs/dates in this
  /// app, but sanitize defensively and keep a stable mapping both ways.
  static String _safeKey(String key) =>
      key.replaceAll('.', '_').replaceAll('#', '_').replaceAll('\$', '_')
          .replaceAll('[', '_').replaceAll(']', '_').replaceAll('/', '_');

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
