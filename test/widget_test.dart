import 'package:flutter_test/flutter_test.dart';

import 'package:billing_app/core/l10n/strings_ar.dart';
import 'package:billing_app/core/l10n/strings_en.dart';
import 'package:billing_app/core/l10n/strings_fr.dart';
import 'package:billing_app/core/security/auth_helper.dart';
import 'package:billing_app/core/utils/cash_change.dart';
import 'package:billing_app/core/utils/search_text.dart';
import 'package:billing_app/features/billing/data/held_cart_store.dart';
import 'package:billing_app/features/billing/domain/entities/cart_item.dart';
import 'package:billing_app/features/billing/domain/entities/promotion.dart';
import 'package:billing_app/features/billing/domain/promo_engine.dart';
import 'package:billing_app/features/inventory/domain/entities/purchase.dart';
import 'package:billing_app/features/inventory/domain/expiry_tracker.dart';
import 'package:billing_app/features/product/domain/dead_stock_advisor.dart';
import 'package:billing_app/features/product/domain/reorder_advisor.dart';
import 'package:billing_app/features/shifts/data/shift_store.dart';
import 'package:billing_app/features/users/domain/entities/app_user.dart';
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

  group('Held (parked) invoices', () {
    HeldCart sample() => HeldCart(
          id: 'h1',
          label: 'Ali',
          createdAt: DateTime(2026, 3, 4, 10, 30),
          lines: const [
            HeldCartLine(
                productId: 'p1',
                productName: 'Sugar',
                quantity: 2,
                unitPrice: 120),
            HeldCartLine(
                productId: 'p2',
                productName: 'Tea',
                quantity: 1.5,
                unitPrice: 200),
          ],
          customerName: 'Ali',
        );

    test('totals add up across lines', () {
      final cart = sample();
      expect(cart.total, closeTo(540, 0.0001));
      expect(cart.itemCount, closeTo(3.5, 0.0001));
    });

    test('round-trips through toMap/fromMap', () {
      final copy = HeldCart.fromMap(sample().toMap());
      expect(copy.id, 'h1');
      expect(copy.label, 'Ali');
      expect(copy.lines.length, 2);
      expect(copy.lines.first.total, 240);
      expect(copy.createdAt, DateTime(2026, 3, 4, 10, 30));
    });
  });

  group('Smart cross-script search', () {
    test('finds Arabic products typed in Latin letters', () {
      expect(SearchText.matches('حليب رائب', 'hlib'), isTrue);
      expect(SearchText.matches('حليب رائب', 'halib'), isTrue);
      expect(SearchText.matches('سكر', 'sukkar'), isTrue);
      expect(SearchText.matches('قهوة', 'kahwa'), isTrue);
      expect(SearchText.matches('شوكولاطة', 'chocolat'), isTrue);
      expect(SearchText.matches('دانون', 'danone'), isTrue);
    });

    test('understands Arabizi digits', () {
      expect(SearchText.matches('قهوة', '9ahwa'), isTrue);
      expect(SearchText.matches('حليب', '7lib'), isTrue);
      expect(SearchText.matches('خبز', '5obz'), isTrue);
    });

    test('still does plain and accent-insensitive matching', () {
      expect(SearchText.matches('Café Noir', 'cafe'), isTrue);
      expect(SearchText.matches('حليب', 'حلي'), isTrue);
      expect(SearchText.matches('6133456789012', '61334'), isTrue);
    });

    test('does not match unrelated words', () {
      expect(SearchText.matches('حليب', 'zit'), isFalse);
      expect(SearchText.matches('سكر', 'farine'), isFalse);
    });

    test('an empty query matches everything', () {
      expect(SearchText.matches('أي منتج', '  '), isTrue);
      expect(SearchText.matchesAny(['a', null], ''), isTrue);
    });
  });

  group('Cash change breakdown', () {
    test('uses the largest Algerian notes first', () {
      final parts = CashChange.breakdown(3750, denominations: CashChange.dzd);
      expect(parts.first, const CashPart(2000, 1));
      expect(parts, contains(const CashPart(1000, 1)));
      expect(parts, contains(const CashPart(500, 1)));
      expect(parts, contains(const CashPart(200, 1)));
      expect(parts, contains(const CashPart(50, 1)));
      expect(parts.fold<int>(0, (sum, p) => sum + p.total), 3750);
    });

    test('reports what no coin can cover', () {
      expect(CashChange.remainder(1003, denominations: CashChange.dzd), 3);
      expect(CashChange.remainder(1000, denominations: CashChange.dzd), 0);
    });

    test('nothing to give back for zero change', () {
      expect(CashChange.breakdown(0, denominations: CashChange.dzd), isEmpty);
      expect(CashChange.pieceCount(
          CashChange.breakdown(300, denominations: CashChange.dzd)), 2);
    });
  });

  group('Reorder advisor', () {
    Sale saleOf(String productId, double qty, DateTime when) => Sale(
          id: 's-${when.millisecondsSinceEpoch}',
          dateTime: when,
          items: [
            SaleItem(
                productId: productId,
                productName: 'X',
                unitPrice: 100,
                quantity: qty),
          ],
          subtotal: 100 * qty,
          discountAmount: 0,
          total: 100 * qty,
          paymentMethod: PaymentMethod.cash,
        );

    test('computes the daily pace, days of cover and order size', () {
      final now = DateTime(2026, 6, 30);
      const product = Product(
          id: 'p1', name: 'Milk', barcode: '1', price: 100, stock: 6);
      final sales = [
        for (int i = 0; i < 10; i++)
          saleOf('p1', 2, now.subtract(Duration(days: i))),
      ];
      final advice = ReorderAdvisor.advise(product, sales, now: now);
      expect(advice.dailyRate, closeTo(2, 0.35));
      expect(advice.daysOfCover, isNotNull);
      expect(advice.daysOfCover!, closeTo(3, 0.6));
      expect(advice.isUrgent, isFalse);
      // ~2/day * 14 days of cover - 6 in stock
      expect(advice.suggestedQuantity, greaterThan(18));
    });

    test('flags a product about to run out', () {
      final now = DateTime(2026, 6, 30);
      const product = Product(
          id: 'p2', name: 'Bread', barcode: '2', price: 20, stock: 4);
      final sales = [
        for (int i = 0; i < 7; i++)
          saleOf('p2', 5, now.subtract(Duration(days: i))),
      ];
      final advice = ReorderAdvisor.advise(product, sales, now: now);
      expect(advice.isUrgent, isTrue);
    });

    test('falls back to the threshold when nothing ever sold', () {
      final now = DateTime(2026, 6, 30);
      const product = Product(
          id: 'p3',
          name: 'Dust',
          barcode: '3',
          price: 10,
          stock: 1,
          lowStockThreshold: 5);
      final advice = ReorderAdvisor.advise(product, const [], now: now);
      expect(advice.sellsRegularly, isFalse);
      expect(advice.daysOfCover, isNull);
      expect(advice.suggestedQuantity, 9); // 5*2 - 1
    });
  });

  group('Cash drawer shift', () {
    Shift openShift() => Shift(
          id: 'sh1',
          openedAt: DateTime(2026, 5, 2, 8),
          openedBy: 'Amine',
          openingFloat: 2000,
        );

    test('expected cash = float + cash in - cash out', () {
      final closed = openShift().copyWith(
        cashSales: 18500,
        creditCollected: 3000,
        paidOut: 1500,
        countedCash: 22000,
        closedAt: DateTime(2026, 5, 2, 20),
      );
      expect(closed.expectedCash, 22000);
      expect(closed.difference, 0);
      expect(closed.isOpen, isFalse);
    });

    test('reports a shortage and a surplus', () {
      final base = openShift().copyWith(
        cashSales: 10000,
        closedAt: DateTime(2026, 5, 2, 20),
      );
      expect(base.copyWith(countedCash: 11500).difference, -500);
      expect(base.copyWith(countedCash: 12300).difference, 300);
    });

    test('an open shift stays open and round-trips', () {
      final open = openShift();
      expect(open.isOpen, isTrue);
      final copy = Shift.fromMap(open.toMap());
      expect(copy.isOpen, isTrue);
      expect(copy.openedBy, 'Amine');
      expect(copy.openingFloat, 2000);
      expect(copy.expectedCash, 2000);
    });
  });

  group('Account passwords', () {
    test('the same password + salt always gives the same hash', () {
      const salt = 'fixed-salt';
      final a = AuthHelper.hashPassword('Bechar2026', salt);
      final b = AuthHelper.hashPassword('Bechar2026', salt);
      expect(a, b);
      expect(a.isNotEmpty, isTrue);
    });

    test('a different salt gives a different hash (no rainbow tables)', () {
      final a = AuthHelper.hashPassword('same', AuthHelper.newSalt());
      final b = AuthHelper.hashPassword('same', AuthHelper.newSalt());
      expect(a == b, isFalse);
    });

    test('verification accepts the right password and rejects others', () {
      final salt = AuthHelper.newSalt();
      final hash = AuthHelper.hashPassword('caisse123', salt);
      expect(AuthHelper.verifyPassword('caisse123', salt, hash), isTrue);
      expect(AuthHelper.verifyPassword('caisse124', salt, hash), isFalse);
      expect(AuthHelper.verifyPassword('caisse123', salt, ''), isFalse);
    });

    test('identifier validation accepts e-mails and plain usernames', () {
      expect(AuthHelper.isValidEmail('karim@shop.dz'), isTrue);
      expect(AuthHelper.isValidEmail('Karim'), isTrue);
      expect(AuthHelper.isValidEmail('karim ben'), isFalse);
      expect(AuthHelper.isValidEmail('karim@'), isFalse);
      expect(AuthHelper.normalizeEmail('  Karim@Shop.DZ '), 'karim@shop.dz');
    });

    test('password rules and strength meter', () {
      expect(AuthHelper.isValidPassword('12345'), isFalse);
      expect(AuthHelper.isValidPassword('123456'), isTrue);
      expect(AuthHelper.strength('123'), 0);
      expect(AuthHelper.strength('abcdef'), 1);
      expect(AuthHelper.strength('abc12345!@'), 3);
    });
  });

  group('Role permissions', () {
    test('admin can do everything', () {
      const role = UserRole.admin;
      expect(role.canViewReports, isTrue);
      expect(role.canChangeSettings, isTrue);
      expect(role.canManageUsers, isTrue);
      expect(role.canManageInventory, isTrue);
    });

    test('accountant sees money but not settings', () {
      const role = UserRole.accountant;
      expect(role.canViewReports, isTrue);
      expect(role.canManageExpenses, isTrue);
      expect(role.canChangeSettings, isFalse);
      expect(role.canManageUsers, isFalse);
      expect(role.canManageInventory, isFalse);
    });

    test('stock keeper handles goods, not profits', () {
      const role = UserRole.stockkeeper;
      expect(role.canManageProducts, isTrue);
      expect(role.canManageInventory, isTrue);
      expect(role.canViewReports, isFalse);
      expect(role.canManageCustomers, isFalse);
    });

    test('cashier can only sell', () {
      const role = UserRole.cashier;
      expect(role.canSell, isTrue);
      expect(role.canManageCustomers, isTrue);
      expect(role.canViewReports, isFalse);
      expect(role.canManageProducts, isFalse);
      expect(role.canChangeSettings, isFalse);
    });

  });

  group('Wholesale pricing', () {
    const product = Product(
      id: 'w1',
      name: 'Oil 5L',
      barcode: '55',
      price: 1500,
      wholesalePrice: 1350,
      wholesaleMinQty: 4,
    );

    test('retail below the tier, wholesale at and above it', () {
      expect(product.hasWholesale, isTrue);
      expect(product.priceFor(1), 1500);
      expect(product.priceFor(3.99), 1500);
      expect(product.priceFor(4), 1350);
      expect(product.priceFor(40), 1350);
    });

    test('no tier configured always charges retail', () {
      const plain = Product(id: 'w2', name: 'Tea', barcode: '56', price: 200);
      expect(plain.hasWholesale, isFalse);
      expect(plain.priceFor(99), 200);
    });

    test('cart item follows the auto price unless the cashier typed one', () {
      final auto = CartItem(product: product, quantity: 5);
      expect(auto.unitPrice, 1350);
      expect(auto.priceOverridden, isFalse);
      expect(auto.isWholesalePriced, isTrue);

      final haggled = CartItem(product: product, quantity: 5, unitPrice: 1400);
      expect(haggled.priceOverridden, isTrue);
      expect(haggled.isWholesalePriced, isFalse);
    });
  });

  group('Promo engine', () {
    const oil = Product(
        id: 'p1', name: 'Oil', barcode: '1', price: 100, category: 'Food');
    const milk = Product(
        id: 'p2', name: 'Milk', barcode: '2', price: 60, unit: ProductUnit.l);
    CartItem line(Product p, double qty) => CartItem(product: p, quantity: qty);

    test('pay X take Y discounts full groups only', () {
      const promo = Promotion(
          id: 'pr1',
          name: '2+1',
          productId: 'p1',
          type: PromoType.buyXPayY,
          payQty: 2,
          getQty: 3);
      final result =
          PromoEngine.compute([line(oil, 7)], [promo], now: DateTime(2026, 9, 9));
      // 2 full groups of 3 → 2 free units × 100
      expect(result.total, 200);
      expect(result.lines.single.promotionId, 'pr1');
    });

    test('buyXPayY never applies to weighed units', () {
      const promo = Promotion(
          id: 'pr2',
          name: 'milk deal',
          productId: 'p2',
          type: PromoType.buyXPayY,
          payQty: 2,
          getQty: 3);
      final result =
          PromoEngine.compute([line(milk, 6)], [promo], now: DateTime(2026, 9, 9));
      expect(result.total, 0);
      expect(result.lines, isEmpty);
    });

    test('percent off a category hits every line in it', () {
      const promo = Promotion(
          id: 'pr3',
          name: 'food -10%',
          category: 'Food',
          type: PromoType.percentOff,
          percent: 10);
      final result = PromoEngine.compute(
          [line(oil, 2), line(milk, 1)], [promo],
          now: DateTime(2026, 9, 9));
      expect(result.total, closeTo(20, 0.0001)); // 10% of 200; milk is not Food
    });

    test('a product offer beats the category one for the same line', () {
      const byProduct = Promotion(
          id: 'pr4',
          name: 'oil -20%',
          productId: 'p1',
          type: PromoType.percentOff,
          percent: 20);
      const byCategory = Promotion(
          id: 'pr5',
          name: 'food -10%',
          category: 'Food',
          type: PromoType.percentOff,
          percent: 10);
      final result = PromoEngine.compute(
          [line(oil, 1)], [byCategory, byProduct],
          now: DateTime(2026, 9, 9));
      expect(result.lines.single.promotionId, 'pr4');
      expect(result.total, closeTo(20, 0.0001));
    });

    test('inactive or out-of-window offers stay silent', () {
      final inactive = const Promotion(
          id: 'pr6',
          name: 'off',
          productId: 'p1',
          type: PromoType.percentOff,
          percent: 50,
          active: false);
      final future = Promotion(
          id: 'pr7',
          name: 'later',
          productId: 'p1',
          type: PromoType.percentOff,
          percent: 50,
          startAt: DateTime(2027, 1, 1));
      expect(
          PromoEngine.compute([line(oil, 1)], [inactive, future],
              now: DateTime(2026, 9, 9))
              .total,
          0);
      expect(Promotion.fromMap(future.toMap()).startAt, DateTime(2027, 1, 1));
    });
  });

  group('Goods returns on invoices', () {
    Sale sample() => Sale(
          id: 's-ret',
          number: 42,
          dateTime: DateTime(2026, 9, 1, 10),
          items: const [
            SaleItem(
                productId: 'a', productName: 'A', unitPrice: 100, unitCost: 80, quantity: 4),
            SaleItem(
                productId: 'b', productName: 'B', unitPrice: 50, unitCost: 40, quantity: 2),
          ],
          subtotal: 500,
          discountAmount: 50,
          total: 450,
          paymentMethod: PaymentMethod.cash,
        );

    SaleReturn ret(String productId, String name, double qty, double price,
            double cost) =>
        SaleReturn(
          id: 'r-$qty',
          dateTime: DateTime(2026, 9, 5, 12),
          lines: [
            SaleReturnLine(
                productId: productId,
                productName: name,
                unitPrice: price,
                unitCost: cost,
                quantity: qty)
          ],
          processedByName: 'Sara',
        );

    test('the refund is discount-allocated, not the sticker price', () {
      final updated = sample().withReturn(ret('a', 'A', 2, 100, 80));
      // factor = 450/500 = 0.9 → refund = 2 × 100 × 0.9
      expect(updated.returnedAmount, closeTo(180, 0.0001));
      expect(updated.effectiveTotal, closeTo(270, 0.0001));
      expect(updated.returnedProfit, closeTo(36, 0.0001));
      expect(updated.effectiveProfit, closeTo(84, 0.0001));
    });

    test('stacked returns shrink the returnable quantity', () {
      var sale = sample().withReturn(ret('a', 'A', 1, 100, 80));
      sale = sale.withReturn(ret('a', 'A', 2, 100, 80));
      expect(sale.returnedQuantityOf('a'), 3);
      expect(sale.returnableQuantity(sale.items.first), 1);
      expect(sale.isFullyReturned, isFalse);
    });

    test('returning everything marks the invoice fully returned', () {
      var sale = sample().withReturn(ret('a', 'A', 4, 100, 80));
      sale = sale.withReturn(ret('b', 'B', 2, 50, 40));
      expect(sale.effectiveTotal, closeTo(0, 0.0001));
      expect(sale.isFullyReturned, isTrue);
    });

    test('returns lower what a credit customer still owes', () {
      final creditSale = Sale(
        id: 's-cred',
        dateTime: DateTime(2026, 9, 1),
        items: const [
          SaleItem(
              productId: 'a', productName: 'A', unitPrice: 100, quantity: 3)
        ],
        subtotal: 300,
        discountAmount: 0,
        total: 300,
        paymentMethod: PaymentMethod.credit,
        isPaid: false,
        payments: [
          SalePayment(amount: 100, dateTime: DateTime(2026, 9, 2)),
        ],
      );
      expect(creditSale.amountDue, 200);
      final updated = creditSale.withReturn(ret('a', 'A', 1, 100, 90));
      expect(updated.amountDue, closeTo(200 - 100, 0.0001));
    });

    test('returns round-trip through toMap/fromMap', () {
      final sale = sample().withReturn(ret('a', 'A', 1.5, 100, 80));
      final copy = Sale.fromMap(sale.toMap());
      expect(copy.returns.length, 1);
      expect(copy.returns.first.lines.single.quantity, 1.5);
      expect(copy.returnedAmount, closeTo(sale.returnedAmount, 0.0001));
      expect(copy.returns.first.processedByName, 'Sara');
    });

    test('the QR payload round-trips to the sale id', () {
      final sale = sample();
      expect(Sale.saleIdFromScan(sale.qrPayload), sale.id);
      expect(Sale.saleIdFromScan('6191234567890'), isNull);
    });
  });

  group('Expiry tracker (FEFO)', () {
    Purchase lot(String product, double qty, DateTime expiry, String id,
            {double cost = 50}) =>
        Purchase(
          id: id,
          dateTime: DateTime(2026, 8, 1),
          items: [
            PurchaseItem(
                productId: product,
                productName: product,
                quantity: qty,
                unitCost: cost,
                expiryDate: expiry)
          ],
        );

    test('the shelves keep the latest-expiry batches', () {
      const yogurt = Product(
          id: 'y', name: 'Yogurt', barcode: '9', price: 60, stock: 7);
      final soon = lot('y', 5, DateTime(2026, 9, 10), 'lot-old');
      final later = lot('y', 5, DateTime(2026, 9, 25), 'lot-new');
      final batches = ExpiryTracker.analyze(
          [yogurt], [soon, later]);
      expect(batches.length, 2);
      // 7 in stock: the 5 of the newest lot + 2 of the expiring one.
      final expiring = batches.firstWhere((b) => b.purchaseId == 'lot-old');
      expect(expiring.quantityOnHand, 2);
      final fresh = batches.firstWhere((b) => b.purchaseId == 'lot-new');
      expect(fresh.quantityOnHand, 5);
      expect(expiring.daysLeft(DateTime(2026, 9, 9)), 1);
      expect(expiring.valueAtRisk(0), closeTo(100, 0.0001));
    });

    test('stock fully consumed leaves nothing at risk', () {
      const gone = Product(
          id: 'g', name: 'Gone', barcode: '8', price: 30, stock: 0);
      final batches = ExpiryTracker.analyze(
          [gone], [lot('g', 10, DateTime(2026, 9, 15), 'lot-g')]);
      expect(batches, isEmpty);
    });
  });

  group('Dead stock advisor', () {
    test('flags silent sellers by frozen capital, never-sold included', () {
      final now = DateTime(2026, 9, 9);
      const stale = Product(
          id: 'd1',
          name: 'Old tea',
          barcode: '1',
          price: 300,
          costPrice: 200,
          stock: 10);
      const fresh = Product(
          id: 'd2', name: 'Hot cake', barcode: '2', price: 50, stock: 5);
      const ghost = Product(
          id: 'd3', name: 'Mystery', barcode: '3', price: 100, stock: 2);
      final sales = [
        Sale(
          id: 'sold',
          dateTime: now.subtract(const Duration(days: 3)),
          items: const [
            SaleItem(productId: 'd2', productName: 'Hot cake', unitPrice: 50, quantity: 1)
          ],
          subtotal: 50,
          discountAmount: 0,
          total: 50,
          paymentMethod: PaymentMethod.cash,
        ),
        Sale(
          id: 'old-sold',
          dateTime: now.subtract(const Duration(days: 45)),
          items: const [
            SaleItem(productId: 'd1', productName: 'Old tea', unitPrice: 300, quantity: 1)
          ],
          subtotal: 300,
          discountAmount: 0,
          total: 300,
          paymentMethod: PaymentMethod.cash,
        ),
      ];
      final dead = DeadStockAdvisor.analyze([stale, fresh, ghost], sales,
          now: now, minDays: 30);
      expect(dead.map((d) => d.product.id).toSet(), {'d1', 'd3'});
      final tea = dead.firstWhere((d) => d.product.id == 'd1');
      expect(tea.daysSinceSale, 45);
      expect(tea.frozenCapital, 2000); // 10 × 200 (at cost)
      expect(tea.clearancePrice, closeTo(210, 0.0001));
      expect(dead.firstWhere((d) => d.product.id == 'd3').daysSinceSale,
          isNull);
    });
  });

  group('user maps', () {
    test('user maps keep the account fields', () {
      final user = AppUser(
        id: 'u1',
        name: 'Karim Ben',
        email: 'karim@shop.dz',
        role: UserRole.accountant,
        pinHash: '',
        salt: '',
        passwordHash: 'hash',
        passwordSalt: 'salt',
        createdAt: DateTime(2026, 1, 1),
      );
      final copy = AppUser.fromMap(user.toMap());
      expect(copy.email, 'karim@shop.dz');
      expect(copy.role, UserRole.accountant);
      expect(copy.hasPassword, isTrue);
      expect(copy.hasPin, isFalse);
      expect(copy.initials, 'KB');
      expect(copy.active, isTrue);
    });
  });
}
