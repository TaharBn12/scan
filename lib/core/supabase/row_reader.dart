import 'store_schema.dart';

/// Tolerant readers for Supabase rows.
///
/// A storefront schema arrives in many shapes (numbers come back as `int`,
/// `double` or `String`; booleans as `true`/`1`/`'t'`; timestamps as ISO or
/// epoch millis). These helpers keep repositories one line per field and
/// never throw on a missing or oddly typed column.
class Row {
  const Row._();

  static String str(Map<String, dynamic> row, String column, [String fallback = '']) {
    final value = StoreColumns.read(row, column);
    if (value == null) return fallback;
    if (value is String) return value;
    return '$value';
  }

  static String? strOrNull(Map<String, dynamic> row, String column) {
    final value = StoreColumns.read(row, column);
    if (value == null) return null;
    final text = value is String ? value : '$value';
    return text.isEmpty ? null : text;
  }

  static double num_(Map<String, dynamic> row, String column, [double fallback = 0]) {
    final value = StoreColumns.read(row, column);
    return _toDouble(value) ?? fallback;
  }

  static int int_(Map<String, dynamic> row, String column, [int fallback = 0]) =>
      num_(row, column, fallback.toDouble()).round();

  static bool bool_(Map<String, dynamic> row, String column, [bool fallback = false]) {
    final value = StoreColumns.read(row, column);
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().toLowerCase().trim();
    if (text.isEmpty) return fallback;
    return text == 'true' || text == 't' || text == 'yes' || text == '1' ||
        text == 'published' || text == 'active' || text == 'completed';
  }

  static DateTime? date(Map<String, dynamic> row, String column) {
    final value = StoreColumns.read(row, column);
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) {
      // Postgres sometimes arrives as epoch seconds, JS templates as millis.
      final ms = value > 1e12 ? value.toInt() : (value * 1000).round();
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toLocal();
  }

  /// A JSON array column that may also arrive as a JSON *string*.
  static List<String> list(Map<String, dynamic> row, String column) {
    final value = StoreColumns.read(row, column);
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e == null ? '' : '$e')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String) {
      var text = value.trim();
      if (text.isEmpty) return const [];
      // Comma separated list: "a.jpg, b.jpg"
      if (!text.startsWith('[')) {
        return text
            .split(',')
            .map((e) => e.trim().replaceAll(RegExp(r'^"|"$/'), ''))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      final decoded = _decodeJsonList(text);
      return decoded ?? _splitBrackets(text);
    }
    return const [];
  }

  /// A JSON object column, returned empty when absent or malformed.
  static Map<String, dynamic> map(Map<String, dynamic> row, String column) {
    final value = StoreColumns.read(row, column);
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static List<Map<String, dynamic>> mapList(Map<String, dynamic> row, String column) {
    final value = StoreColumns.read(row, column);
    if (value is List) {
      return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    return const [];
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString().replaceAll(',', ''));
    return parsed;
  }

  static List<String>? _decodeJsonList(String text) {
    // Kept dependency-free: a bracketed list of quoted strings is all a
    // storefront gallery column ever holds.
    final cleaned = text.substring(1, text.length - 1);
    if (cleaned.trim().isEmpty) return const [];
    return cleaned
        .split(',')
        .map((e) => e.trim().replaceAll(RegExp(r'^"|"$/'), '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<String> _splitBrackets(String text) =>
      text.replaceAll(RegExp(r'[\[\]"]'), '').split(',').where((e) => e.trim().isNotEmpty).toList();
}

/// Writes: strips nulls/empties so an `update()` never blanks a column the
/// merchant did not touch.
Map<String, dynamic> compactRow(Map<String, dynamic> row) {
  row.removeWhere((_, v) => v == null);
  return row;
}
