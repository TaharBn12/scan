import '../settings/app_settings_controller.dart';

/// Formats amounts consistently everywhere (UI, receipts, PDFs, CSV).
///
/// Uses the currency symbol / position / decimals from [appSettings] so the
/// merchant can switch from "DA" to "DZD", "€", etc. in Settings and every
/// screen follows. Digits are always Western (0-9) so thermal printers and
/// spreadsheets read them without surprises.
class Money {
  Money._();

  static String format(num amount, {bool withSymbol = true}) {
    final s = appSettings.value;
    final text = amount.toStringAsFixed(s.decimalDigits);
    final grouped = _group(text);
    if (!withSymbol || s.currencySymbol.isEmpty) return grouped;
    return s.currencySymbolBefore
        ? '${s.currencySymbol}$grouped'
        : '$grouped ${s.currencySymbol}';
  }

  /// Plain number with the configured number of decimals, no grouping, no
  /// symbol - for CSV/printer columns.
  static String plain(num amount) =>
      amount.toStringAsFixed(appSettings.value.decimalDigits);

  static String get symbol => appSettings.value.currencySymbol;

  static String _group(String fixed) {
    final parts = fixed.split('.');
    final intPart = parts[0];
    final negative = intPart.startsWith('-');
    final digits = negative ? intPart.substring(1) : intPart;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    final grouped = (negative ? '-' : '') + buffer.toString();
    return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  }
}

/// Quantity formatting: "2" for whole numbers, "1.25" / "0.5" otherwise.
String formatQty(num qty) {
  if (qty == qty.roundToDouble()) return qty.toInt().toString();
  String s = qty.toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
