import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';

/// The Firebase project configuration that the merchant pastes from the
/// Firebase console (the "Web App" snippet found under
/// Project settings → General → Your apps).
///
/// Storing the raw JSON in the settings box keeps the UI simple (a single
/// text field) and [FirebaseAppConfig.parse] validates it on save, so a
/// broken config can never reach the Firebase SDK.
class FirebaseAppConfig {
  final String apiKey;
  final String? authDomain;
  final String projectId;
  final String? storageBucket;
  final String? messagingSenderId;
  final String appId;
  final String? measurementId;
  /// Optional, when the merchant also registered a native app in the
  /// console and pasted these two extra keys into the same config object.
  final String? androidClientId;
  final String? iOSClientId;

  const FirebaseAppConfig({
    required this.apiKey,
    this.authDomain,
    required this.projectId,
    this.storageBucket,
    this.messagingSenderId,
    required this.appId,
    this.measurementId,
    this.androidClientId,
    this.iOSClientId,
  });

  /// Throws a [FormatException] with a human readable [message] when [raw]
  /// is not a usable Firebase web-app config.
  factory FirebaseAppConfig.parse(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('not valid JSON');
    }
    if (decoded is! Map) {
      throw const FormatException('expected a JSON object');
    }
    final apiKey = decoded['apiKey'];
    final projectId = decoded['projectId'];
    final appId = decoded['appId'];
    if (apiKey is! String || apiKey.isEmpty) {
      throw const FormatException('missing "apiKey"');
    }
    if (projectId is! String || projectId.isEmpty) {
      throw const FormatException('missing "projectId"');
    }
    if (appId is! String || appId.isEmpty) {
      throw const FormatException('missing "appId"');
    }
    String? str(String key) {
      final v = decoded[key];
      return v is String && v.isNotEmpty ? v : null;
    }
    return FirebaseAppConfig(
      apiKey: apiKey,
      authDomain: str('authDomain'),
      projectId: projectId,
      storageBucket: str('storageBucket'),
      messagingSenderId: str('messagingSenderId'),
      appId: appId,
      measurementId: str('measurementId'),
      androidClientId: str('androidClientId'),
      iOSClientId: str('iOSClientId'),
    );
  }

  /// Options for [Firebase.initializeApp]. Only Firestore is used, so the
  /// client ids / bucket / sender id stay inert; newer firebase_core
  /// versions require them non-null, hence the fallbacks.
  FirebaseOptions toOptions() => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        // Console configs always carry the auth domain; fall back to the
        // standard one otherwise.
        authDomain: authDomain ?? '$projectId.firebaseapp.com',
        projectId: projectId,
        storageBucket: storageBucket ?? '$projectId.appspot.com',
        // Only used by Firebase Auth / Storage; placeholders keep the SDK
        // happy when the merchant only pasted the web-app config.
        messagingSenderId: messagingSenderId ?? '0',
        androidClientId: androidClientId ?? '0',
        iosClientId: iOSClientId ?? '0',
      );
}
