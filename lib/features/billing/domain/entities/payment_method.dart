enum PaymentMethod { cash, card, credit }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.credit:
        return 'Credit (Pay Later)';
    }
  }
}
