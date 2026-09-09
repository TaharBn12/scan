import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'pin_helper.dart';

/// Account passwords for the login screen.
///
/// Everything stays on the device, so there is no server to trust: the
/// password is never stored, only a salted hash stretched over many SHA-256
/// rounds (cheap on a phone, expensive for anyone brute-forcing a stolen
/// backup file).
class AuthHelper {
  AuthHelper._();

  /// Cost factor. 20k rounds is a few milliseconds on a low-end phone.
  static const int rounds = 20000;

  static const int minPasswordLength = 6;

  static String newSalt() => PinHelper.newSalt();

  /// Stretched hash: sha256^rounds("<salt>:<password>").
  static String hashPassword(String password, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$password')).bytes;
    for (var i = 1; i < rounds; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Encode(digest);
  }

  static bool verifyPassword(String password, String salt, String expected) {
    if (expected.isEmpty) return false;
    return _constantTimeEquals(hashPassword(password, salt), expected);
  }

  static bool isValidPassword(String password) =>
      password.trim().length >= minPasswordLength;

  /// Login identifiers are case-insensitive and trimmed. A plain username
  /// works as well as a real e-mail (shops are offline, not everyone has
  /// an address).
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static bool isValidEmail(String email) {
    final value = normalizeEmail(email);
    if (value.length < 3) return false;
    if (value.contains(' ')) return false;
    if (!value.contains('@')) {
      // Plain username: letters, digits, dot, dash, underscore.
      return RegExp(r'^[a-z0-9._-]+$').hasMatch(value);
    }
    return RegExp(r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$').hasMatch(value);
  }

  /// Rough strength meter for the password field (0 = weak, 3 = strong).
  static int strength(String password) {
    if (password.length < minPasswordLength) return 0;
    var score = 1;
    if (password.length >= 10) score++;
    final hasLetters = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigits = RegExp(r'\d').hasMatch(password);
    final hasSymbols = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    if (hasLetters && hasDigits) score++;
    if (hasSymbols && score < 3) score++;
    return score.clamp(0, 3);
  }

  /// Comparison that doesn't leak how many characters matched.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
