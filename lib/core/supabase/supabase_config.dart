import '../cloud/cloud_database.dart';

/// Where the e-commerce site lives.
///
/// Nothing is hard-coded: the storefront's Supabase project is injected at
/// build time so the same source can point at a staging or a production
/// project without editing files — and no key is ever committed to git.
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://abcdefgh.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
///
/// A merchant who cannot rebuild can also paste the same two values in
/// *E-commerce → Connection*; those are stored in the settings box and take
/// precedence over the compile-time defaults (see [resolve]).
class SupabaseConfig {
  const SupabaseConfig._();

  static const String _settingsKeyUrl = 'supabase_url';
  static const String _settingsKeyAnon = 'supabase_anon_key';

  /// Compile-time values (`--dart-define`), empty when not provided.
  static const String buildUrl = String.fromEnvironment('SUPABASE_URL');
  static const String buildAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Values typed by the merchant at runtime ('' = never set).
  static String get storedUrl =>
      (CloudDatabase.settingsBox.get(_settingsKeyUrl) as String? ?? '').trim();
  static String get storedAnonKey =>
      (CloudDatabase.settingsBox.get(_settingsKeyAnonKey) as String? ?? '').trim();

  /// Runtime override wins, then the build-time default.
  static ResolvedSupabaseConfig resolve() {
    final url = storedUrl.isNotEmpty ? storedUrl : buildUrl.trim();
    final key = storedAnonKey.isNotEmpty ? storedAnonKey : buildAnonKey.trim();
    return ResolvedSupabaseConfig(url: _normalize(url), anonKey: key);
  }

  /// Persists the merchant's override so the next launch reconnects alone.
  static Future<void> save({required String url, required String anonKey}) {
    return Future.wait([
      CloudDatabase.settingsBox.put(_settingsKeyUrl, url.trim()),
      CloudDatabase.settingsBox.put(_settingsKeyAnonKey, anonKey.trim()),
    ]);
  }

  static Future<void> clear() => Future.wait([
        CloudDatabase.settingsBox.put(_settingsKeyUrl, ''),
        CloudDatabase.settingsBox.put(_settingsKeyAnonKey, ''),
      ]);

  /// Trims, drops the trailing slash and forces https — the three mistakes
  /// that break a hand-pasted project URL.
  static String _normalize(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}

/// A validated (url, anonKey) pair.
class ResolvedSupabaseConfig {
  final String url;
  final String anonKey;

  const ResolvedSupabaseConfig({required this.url, required this.anonKey});

  /// True when both halves look usable.
  bool get isConfigured =>
      url.startsWith('http') && url.contains('.') && anonKey.length > 20;

  /// The project reference shown in the UI (`abcdefgh` for
  /// `https://abcdefgh.supabase.co`), or the raw host when unparsable.
  String get projectRef {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host;
    final dot = host.indexOf('.');
    return dot > 0 ? host.substring(0, dot) : host;
  }

  @override
  String toString() => 'ResolvedSupabaseConfig($projectRef)';
}
