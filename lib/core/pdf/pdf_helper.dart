import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../utils/money.dart';
import '../../features/billing/domain/entities/payment_method.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/sales/domain/entities/sale.dart';
import '../../features/shop/domain/entities/shop.dart';

/// Builds PDFs (invoices, barcode label sheets, report summaries) with a
/// bundled font that covers Arabic + Latin, and shares them through the
/// system share sheet (WhatsApp, e-mail, Drive, print services...).
class PdfHelper {
  PdfHelper._();

  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _loadFonts() async {
    if (_regular != null && _bold != null) return;
    final regularData =
        await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf');
    final boldData =
        await rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf');
    _regular = pw.Font.ttf(regularData);
    _bold = pw.Font.ttf(boldData);
  }

  static pw.ThemeData _theme() => pw.ThemeData.withFont(
        base: _regular!,
        bold: _bold!,
        italic: _regular!,
        boldItalic: _bold!,
      );

  static pw.TextDirection _dir(AppLocalizations l10n) =>
      l10n.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  // ---------------------------------------------------------------- share

  static Future<File> _writeTemp(String name, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> shareBytes(Uint8List bytes, String fileName,
      {String? subject}) async {
    final file = await _writeTemp(fileName, bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
      text: subject,
    ));
    return file;
  }

  // -------------------------------------------------------------- invoice

  /// A5-ish invoice (fits phones' PDF viewers nicely and prints on A4 too).
  static Future<Uint8List> buildInvoice({
    required Sale sale,
    required Shop shop,
    required AppLocalizations l10n,
  }) async {
    await _loadFonts();
    final doc = pw.Document(theme: _theme());
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final dir = _dir(l10n);

    pw.Widget kv(String k, String v,
        {bool bold = false, double size = 10, PdfColor? color}) {
      final style = pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color);
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(k, style: style), pw.Text(v, style: style)],
      );
    }

    String status() {
      if (sale.isRefunded) return l10n.t('refunded');
      if (sale.isCredit) {
        if (sale.isPaid) return l10n.t('paid');
        return sale.amountPaid > 0 ? l10n.t('partially_paid') : l10n.t('unpaid');
      }
      return l10n.t('paid');
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Directionality(
          textDirection: dir,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(shop.name,
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              if (shop.addressLine1.isNotEmpty)
                pw.Center(
                    child: pw.Text(shop.addressLine1,
                        style: const pw.TextStyle(fontSize: 9))),
              if (shop.addressLine2.isNotEmpty)
                pw.Center(
                    child: pw.Text(shop.addressLine2,
                        style: const pw.TextStyle(fontSize: 9))),
              if (shop.phoneNumber.isNotEmpty)
                pw.Center(
                    child: pw.Text(shop.phoneNumber,
                        style: const pw.TextStyle(fontSize: 9))),
              if (shop.taxId.isNotEmpty)
                pw.Center(
                    child: pw.Text(shop.taxId,
                        style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      sale.number > 0
                          ? l10n.t('invoice_number', {'number': sale.number})
                          : l10n.t('invoice'),
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateFmt.format(sale.dateTime),
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if ((sale.customerName ?? '').isNotEmpty)
                pw.Text(
                    '${l10n.t('customer_label', {'name': sale.customerName})}'
                    '${(sale.customerPhone ?? '').isNotEmpty ? ' - ${sale.customerPhone}' : ''}',
                    style: const pw.TextStyle(fontSize: 9)),
              if ((sale.cashierName ?? '').isNotEmpty)
                pw.Text(l10n.t('served_by', {'name': sale.cashierName}),
                    style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                cellAlignments: {
                  0: dir == pw.TextDirection.rtl
                      ? pw.Alignment.centerRight
                      : pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                },
                headers: [
                  l10n.t('product_name'),
                  l10n.quantity,
                  l10n.price,
                  l10n.total,
                ],
                data: sale.items
                    .map((i) => [
                          i.productName,
                          '${formatQty(i.quantity)} ${l10n.t(i.unit.shortKey)}',
                          Money.format(i.unitPrice),
                          Money.format(i.lineTotal),
                        ])
                    .toList(),
              ),
              pw.SizedBox(height: 8),
              if (sale.discountAmount > 0 || sale.promoDiscount > 0) ...[
                kv(l10n.subtotal, Money.format(sale.subtotal)),
                if (sale.discountAmount > 0)
                  kv(l10n.discount, '-${Money.format(sale.discountAmount)}'),
                if (sale.promoDiscount > 0)
                  kv(l10n.t('offers_discount'),
                      '-${Money.format(sale.promoDiscount)}'),
              ],
              kv(l10n.total, Money.format(sale.total), bold: true, size: 13),
              if (sale.hasReturns)
                kv(l10n.t('effective_total'),
                    Money.format(sale.effectiveTotal),
                    bold: true),
              kv(l10n.t('payment_method'), l10n.t(sale.paymentMethod.labelKey)),
              if (sale.isCredit) ...[
                kv(l10n.t('paid_amount'), Money.format(sale.amountPaid)),
                kv(l10n.t('remaining'), Money.format(sale.amountDue),
                    bold: true,
                    color: sale.amountDue > 0 ? PdfColors.red : null),
              ],
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(status(),
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
              ),
              if ((sale.note ?? '').isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(l10n.t('note_label', {'note': sale.note}),
                    style: const pw.TextStyle(fontSize: 9)),
              ],
              pw.Spacer(),
              pw.Divider(),
              if (sale.number > 0) ...[
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: sale.qrPayload,
                    width: 58,
                    height: 58,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(l10n.t('scan_to_return'),
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.grey700)),
                ),
                pw.SizedBox(height: 6),
              ],
              pw.Center(
                child: pw.Text(
                    shop.footerText.isNotEmpty
                        ? shop.footerText
                        : l10n.t('thank_you'),
                    style: const pw.TextStyle(fontSize: 9)),
              ),
              if (shop.upiId.isNotEmpty)
                pw.Center(
                    child: pw.Text(shop.upiId,
                        style: const pw.TextStyle(fontSize: 8))),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  static Future<File> shareInvoice({
    required Sale sale,
    required Shop shop,
    required AppLocalizations l10n,
  }) async {
    final bytes = await buildInvoice(sale: sale, shop: shop, l10n: l10n);
    final name = sale.number > 0
        ? 'invoice_${sale.number}.pdf'
        : 'invoice_${sale.id.substring(0, 8)}.pdf';
    return shareBytes(bytes, name,
        subject:
            '${l10n.t('invoice')} ${sale.number > 0 ? '#${sale.number}' : ''} - ${shop.name}');
  }

  /// Plain-text version of the receipt for sharing in a chat message.
  static String invoiceText({
    required Sale sale,
    required Shop shop,
    required AppLocalizations l10n,
  }) {
    final b = StringBuffer();
    b.writeln(shop.name);
    if (shop.phoneNumber.isNotEmpty) b.writeln(shop.phoneNumber);
    b.writeln(sale.number > 0
        ? l10n.t('invoice_number', {'number': sale.number})
        : l10n.t('invoice'));
    b.writeln(DateFormat('dd/MM/yyyy HH:mm').format(sale.dateTime));
    if ((sale.customerName ?? '').isNotEmpty) {
      b.writeln(l10n.t('customer_label', {'name': sale.customerName}));
    }
    b.writeln('------------------------');
    for (final i in sale.items) {
      b.writeln(
          '${i.productName}  ${formatQty(i.quantity)} ${l10n.t(i.unit.shortKey)} x ${Money.format(i.unitPrice)} = ${Money.format(i.lineTotal)}');
    }
    b.writeln('------------------------');
    if (sale.discountAmount > 0 || sale.promoDiscount > 0) {
      b.writeln('${l10n.subtotal}: ${Money.format(sale.subtotal)}');
      if (sale.discountAmount > 0) {
        b.writeln('${l10n.discount}: -${Money.format(sale.discountAmount)}');
      }
      if (sale.promoDiscount > 0) {
        b.writeln(
            '${l10n.t('offers_discount')}: -${Money.format(sale.promoDiscount)}');
      }
    }
    b.writeln('${l10n.total}: ${Money.format(sale.total)}');
    if (sale.hasReturns) {
      b.writeln(
          '${l10n.t('returns_section')}: -${Money.format(sale.returnedAmount)}');
      b.writeln(
          '${l10n.t('effective_total')}: ${Money.format(sale.effectiveTotal)}');
    }
    b.writeln(
        '${l10n.t('payment_method')}: ${l10n.t(sale.paymentMethod.labelKey)}');
    if (sale.isCredit) {
      b.writeln('${l10n.t('paid_amount')}: ${Money.format(sale.amountPaid)}');
      b.writeln('${l10n.t('remaining')}: ${Money.format(sale.amountDue)}');
    }
    b.writeln();
    b.writeln(shop.footerText.isNotEmpty ? shop.footerText : l10n.t('thank_you'));
    return b.toString();
  }

  // --------------------------------------------------------------- labels

  /// A4 sheet of barcode stickers. [perRow] columns; each product repeated
  /// [copies] times.
  static Future<Uint8List> buildLabelSheet({
    required List<Product> products,
    required AppLocalizations l10n,
    int perRow = 3,
    int copies = 1,
    bool showName = true,
    bool showPrice = true,
    String? shopName,
  }) async {
    await _loadFonts();
    final doc = pw.Document(theme: _theme());
    final cells = <Product>[];
    for (final p in products) {
      for (int i = 0; i < copies; i++) {
        cells.add(p);
      }
    }
    final columns = perRow.clamp(1, 5);
    final labelHeight = columns >= 4 ? 70.0 : 90.0;

    pw.Widget label(Product p) {
      final code = p.barcode.trim();
      final type = barcodeTypeFor(code);
      return pw.Container(
        height: labelHeight,
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if (showName)
              pw.Text(p.name,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Expanded(
              child: pw.BarcodeWidget(
                barcode: type,
                data: code,
                drawText: true,
                textStyle: const pw.TextStyle(fontSize: 7),
              ),
            ),
            if (showPrice)
              pw.Text(Money.format(p.price),
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
    }

    // Rows of Expanded cells paginate predictably inside MultiPage.
    final rows = <pw.Widget>[];
    for (int i = 0; i < cells.length; i += columns) {
      final chunk = cells.sublist(
          i, i + columns > cells.length ? cells.length : i + columns);
      rows.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          children: [
            for (int c = 0; c < columns; c++)
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                  child: c < chunk.length
                      ? label(chunk[c])
                      : pw.SizedBox(height: labelHeight),
                ),
              ),
          ],
        ),
      ));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (ctx) => rows,
      ),
    );
    return doc.save();
  }

  /// Picks the symbology that can actually encode [code]: EAN-13/EAN-8 only
  /// when the check digit is valid (the barcode package throws otherwise),
  /// Code 128 for anything else.
  static pw.Barcode barcodeTypeFor(String code) {
    if (RegExp(r'^\d{13}$').hasMatch(code) && _gtinCheckDigitValid(code)) {
      return pw.Barcode.ean13();
    }
    if (RegExp(r'^\d{8}$').hasMatch(code) && _gtinCheckDigitValid(code)) {
      return pw.Barcode.ean8();
    }
    return pw.Barcode.code128();
  }

  static bool _gtinCheckDigitValid(String digits) {
    int sum = 0;
    final body = digits.substring(0, digits.length - 1);
    for (int i = 0; i < body.length; i++) {
      final d = int.parse(body[body.length - 1 - i]);
      sum += i.isEven ? d * 3 : d;
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(digits[digits.length - 1]);
  }

  // -------------------------------------------------------------- reports

  /// Simple key/value summary PDF (daily close / period report).
  static Future<Uint8List> buildSummary({
    required String title,
    required String subtitle,
    required List<MapEntry<String, String>> lines,
    required AppLocalizations l10n,
    List<List<String>>? table,
    List<String>? tableHeaders,
    String? shopName,
  }) async {
    await _loadFonts();
    final doc = pw.Document(theme: _theme());
    final dir = _dir(l10n);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Directionality(
            textDirection: dir,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (shopName != null && shopName.isNotEmpty)
                  pw.Text(shopName,
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(subtitle,
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: lines
                      .map((e) => pw.TableRow(children: [
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(e.key,
                                    style: const pw.TextStyle(fontSize: 10))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(e.value,
                                    textAlign: pw.TextAlign.end,
                                    style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold))),
                          ]))
                      .toList(),
                ),
                if (table != null && table.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.TableHelper.fromTextArray(
                    headers: tableHeaders,
                    data: table,
                    headerStyle: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    headerDecoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
