import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../data/hive_database.dart';

/// Sends scan events to an external website the merchant controls.
///
/// Design on purpose kept dead simple (no Firebase, no accounts): the app
/// generates a random token once, the merchant copies it into their own
/// website, and every barcode scan is POSTed there with that token so the
/// website knows which shop it came from.
class SyncHelper {
  static const _tokenKey = 'sync_token';
  static const _urlKey = 'sync_url';
  static const _enabledKey = 'sync_enabled';

  /// The token identifying this phone/shop. Generated once and persisted;
  /// the merchant copies this into their website to link the two.
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
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${getOrCreateToken()}',
            },
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
      // Silently ignore network errors - this is a best-effort side
      // channel, not something that should interrupt billing.
    }
  }
}
