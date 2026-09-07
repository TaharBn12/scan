import 'package:flutter_test/flutter_test.dart';

import 'package:billing_app/core/l10n/strings_ar.dart';
import 'package:billing_app/core/l10n/strings_en.dart';
import 'package:billing_app/core/l10n/strings_fr.dart';
import 'package:billing_app/features/billing/domain/entities/payment_method.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/sales/domain/entities/sale.dart';
import 'package:billing_app/features/sales/domain/entities/sale_item.dart';

void main() {
  group('localization tables', () {
    test('ar and fr cover every english key', () {
      final missingAr =
          stringsEn.keys.where((k) => !stringsAr.containsKey(k)).toList();
      final missingFr =
          stringsEn.keys.where((k) => !stringsFr.containsKey(k)).toList();
      expect(missingAr, isEmpty, reason: 'Arabic is missing keys');
      expect(missingFr, isEmpty, reason: 'French is missing keys');
    });

    test('placeholders match across languages', () {
      final re = RegExp(r'\{[a-zA-Z_]+\}');
      for (final entry in stringsEn.entries) {
        final expected = re.allMatches(entry.value).map((m) => m[0]).toSet();
        for (final table in [stringsAr, stringsFr]) {
          final actual =
              re.allMatches(table[entry.key] ?? '').map((m) => m[0]).toSet();
          expect(actual, expected,
              reason: 'placeholders differ for "${entry.key}"');
        }
      }
    });
  });

  group('Sale payments', () {
    Sale credit() => Sale(
          id: 's1',
          dateTime: DateTime(2026, 1, 1),
          items: const [
            SaleItem(
              productId: 'p1',
              productName: 'Sugar',
              unitPrice: 100,
              unitCost: 80,
              quantity: 2.5,
              unit: ProductUnit.kg,
            ),
          ],
          subtotal: 250,
          discountAmount: 0,
          total: 250,
          paymentMethod: PaymentMethod.credit,
          isPaid: false,
        );

    test('partial payments accumulate and settle the sale', () {
      final s = credit();
      expect(s.amountPaid, 0);
      expect(s.amountDue, 250);

      final partly = s.withPayment(100);
      expect(partly.amountPaid, 100);
      expect(partly.amountDue, 150);
      expect(partly.isPaid, isFalse);
      expect(partly.isPartiallyPaid, isTrue);

      final settled = partly.withPayment(150);
      expect(settled.isPaid, isTrue);
      expect(settled.amountDue, 0);
    });

    test('decimal quantities drive totals and profit', () {
      final s = credit();
      expect(s.totalItemsCount, 2.5);
      expect(s.items.first.lineTotal, 250);
      expect(s.profit, closeTo(50, 0.0001));
    });

    test('round-trips through toMap/fromMap', () {
      final s = credit().withPayment(60, note: 'cash');
      final copy = Sale.fromMap(s.toMap());
      expect(copy.payments.length, 1);
      expect(copy.amountPaid, 60);
      expect(copy.items.first.unit, ProductUnit.kg);
      expect(copy.paymentMethod, PaymentMethod.credit);
    });
  });

  group('Product units', () {
    test('only weight/volume/length units allow decimals', () {
      expect(ProductUnit.kg.allowsDecimals, isTrue);
      expect(ProductUnit.l.allowsDecimals, isTrue);
      expect(ProductUnit.piece.allowsDecimals, isFalse);
      expect(ProductUnit.box.allowsDecimals, isFalse);
    });

    test('low stock respects trackStock and threshold', () {
      const p = Product(
        id: 'p',
        name: 'Milk',
        barcode: '123',
        price: 90,
        stock: 3,
        lowStockThreshold: 5,
      );
      expect(p.isLowStock, isTrue);
      expect(p.copyWith(trackStock: false).isLowStock, isFalse);
      expect(p.copyWith(stock: 10).isLowStock, isFalse);
    });
  });
}
