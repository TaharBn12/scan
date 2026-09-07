enum PaymentMethod { cash, credit }

extension PaymentMethodLabel on PaymentMethod {
  /// Localization key; use `context.l10n.t(method.labelKey)`.
  String get labelKey {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.credit:
        return 'credit_pay_later';
    }
  }

  /// Plain ASCII label for thermal receipts (which can't render Arabic).
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.credit:
        return 'Credit';
    }
  }
}
