import 'package:flutter/material.dart';
import '../data/hive_database.dart';

/// Single source of truth for user preferences that affect the whole app:
/// language, currency symbol, and the PIN lock. All values live in the
/// settings Hive box so they survive restarts. Widgets listen through the
/// [ValueNotifier] so changing e.g. the language rebuilds MaterialApp.
class AppSettings {
  final Locale? locale; // null = follow system
  final String currencySymbol;
  final bool currencySymbolBefore;
  final int decimalDigits;
  final bool pinEnabled;
  final bool decimalQuantities;

  const AppSettings({
    this.locale,
    this.currencySymbol = 'DA',
    this.currencySymbolBefore = false,
    this.decimalDigits = 2,
    this.pinEnabled = false,
    this.decimalQuantities = true,
  });

  AppSettings copyWith({
    Locale? locale,
    bool clearLocale = false,
    String? currencySymbol,
    bool? currencySymbolBefore,
    int? decimalDigits,
    bool? pinEnabled,
    bool? decimalQuantities,
  }) {
    return AppSettings(
      locale: clearLocale ? null : (locale ?? this.locale),
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencySymbolBefore: currencySymbolBefore ?? this.currencySymbolBefore,
      decimalDigits: decimalDigits ?? this.decimalDigits,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      decimalQuantities: decimalQuantities ?? this.decimalQuantities,
    );
  }
}

class AppSettingsController extends ValueNotifier<AppSettings> {
  static const _localeKey = 'app_locale';
  static const _currencyKey = 'currency_symbol';
  static const _currencyBeforeKey = 'currency_symbol_before';
  static const _decimalsKey = 'currency_decimals';
  static const _pinEnabledKey = 'pin_enabled';
  static const _decimalQtyKey = 'decimal_quantities';

  static const supportedLocales = [Locale('ar'), Locale('fr'), Locale('en')];

  AppSettingsController() : super(_load());

  static AppSettings _load() {
    final box = HiveDatabase.settingsBox;
    final code = box.get(_localeKey) as String?;
    return AppSettings(
      locale: code == null || code.isEmpty ? null : Locale(code),
      currencySymbol: box.get(_currencyKey) as String? ?? 'DA',
      currencySymbolBefore: box.get(_currencyBeforeKey) as bool? ?? false,
      decimalDigits: box.get(_decimalsKey) as int? ?? 2,
      pinEnabled: box.get(_pinEnabledKey) as bool? ?? false,
      decimalQuantities: box.get(_decimalQtyKey) as bool? ?? true,
    );
  }

  Future<void> setLocale(Locale? locale) async {
    await HiveDatabase.settingsBox
        .put(_localeKey, locale?.languageCode ?? '');
    value = value.copyWith(locale: locale, clearLocale: locale == null);
  }

  Future<void> setCurrency({
    String? symbol,
    bool? symbolBefore,
    int? decimals,
  }) async {
    final box = HiveDatabase.settingsBox;
    if (symbol != null) await box.put(_currencyKey, symbol.trim());
    if (symbolBefore != null) await box.put(_currencyBeforeKey, symbolBefore);
    if (decimals != null) await box.put(_decimalsKey, decimals);
    value = value.copyWith(
      currencySymbol: symbol?.trim(),
      currencySymbolBefore: symbolBefore,
      decimalDigits: decimals,
    );
  }

  Future<void> setPinEnabled(bool enabled) async {
    await HiveDatabase.settingsBox.put(_pinEnabledKey, enabled);
    value = value.copyWith(pinEnabled: enabled);
  }

  Future<void> setDecimalQuantities(bool enabled) async {
    await HiveDatabase.settingsBox.put(_decimalQtyKey, enabled);
    value = value.copyWith(decimalQuantities: enabled);
  }
}

/// Shared instance, wired into MaterialApp in main.dart.
final appSettings = AppSettingsController();
