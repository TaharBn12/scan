import '../l10n/app_localizations.dart';

/// Form validators. They take the localizations object so messages follow
/// the app language.
class AppValidators {
  static String? Function(String?) required(String message) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  static String? Function(String?) price(AppLocalizations l10n) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return l10n.t('enter_price');
      }
      final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
      if (parsed == null) return l10n.t('enter_valid_number');
      if (parsed < 0) return l10n.t('cannot_be_negative');
      return null;
    };
  }

  /// Optional non-negative decimal (empty allowed).
  static String? Function(String?) optionalAmount(AppLocalizations l10n) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) return null;
      final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
      if (parsed == null) return l10n.t('enter_valid_number');
      if (parsed < 0) return l10n.t('cannot_be_negative');
      return null;
    };
  }

  /// Required positive decimal.
  static String? Function(String?) positiveAmount(AppLocalizations l10n) {
    return (String? value) {
      final parsed =
          double.tryParse((value ?? '').trim().replaceAll(',', '.'));
      if (parsed == null) return l10n.t('enter_valid_number');
      if (parsed <= 0) return l10n.t('enter_valid_number');
      return null;
    };
  }

  static String? Function(String?) optionalWholeNumber(AppLocalizations l10n) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) return null;
      final parsed = int.tryParse(value.trim());
      if (parsed == null) return l10n.t('whole_number');
      if (parsed < 0) return l10n.t('cannot_be_negative');
      return null;
    };
  }
}

/// Parses "1,5" or "1.5" -> 1.5; empty/invalid -> [fallback].
double parseAmount(String? value, {double fallback = 0}) {
  if (value == null || value.trim().isEmpty) return fallback;
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? fallback;
}
