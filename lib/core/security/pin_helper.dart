import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../cloud/cloud_database.dart';

/// PIN hashing + the single "app lock" PIN (used when multi-user mode is
/// off). PINs are stored as salted SHA-256 hashes, never in clear text.
class PinHelper {
  PinHelper._();

  static const _appPinHashKey = 'app_pin_hash';
  static const _appPinSaltKey = 'app_pin_salt';

  static String newSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hash(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  static bool verify(String pin, String salt, String expectedHash) {
    return hash(pin, salt) == expectedHash;
  }

  static bool isValidPin(String pin) =>
      RegExp(r'^\d{4,6}$').hasMatch(pin);

  // ---- app-level lock PIN ----

  static bool get hasAppPin =>
      (CloudDatabase.settingsBox.get(_appPinHashKey) as String?)?.isNotEmpty ??
      false;

  static Future<void> setAppPin(String pin) async {
    final salt = newSalt();
    await CloudDatabase.settingsBox.put(_appPinSaltKey, salt);
    await CloudDatabase.settingsBox.put(_appPinHashKey, hash(pin, salt));
  }

  static Future<void> clearAppPin() async {
    await CloudDatabase.settingsBox.delete(_appPinSaltKey);
    await CloudDatabase.settingsBox.delete(_appPinHashKey);
  }

  static bool verifyAppPin(String pin) {
    final salt = CloudDatabase.settingsBox.get(_appPinSaltKey) as String? ?? '';
    final expected =
        CloudDatabase.settingsBox.get(_appPinHashKey) as String? ?? '';
    if (expected.isEmpty) return true;
    return verify(pin, salt, expected);
  }
}
