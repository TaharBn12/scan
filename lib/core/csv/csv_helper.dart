import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_localizations.dart';
import '../../features/billing/domain/entities/payment_method.dart';
import '../../features/expenses/domain/entities/expense.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/sales/domain/entities/sale.dart';

/// Minimal CSV writer/reader (RFC 4180 quoting) - enough for Excel / Google
/// Sheets round-trips without pulling in another package.
class CsvHelper {
  CsvHelper._();

  // ---------------------------------------------------------------- encode

  static String encodeRow(List<Object?> cells) {
    return cells.map(_escape).join(',');
  }

  static String _escape(Object? cell) {
    final s = cell == null ? '' : cell.toString();
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r') ||
        s.contains(';')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String encode(List<List<Object?>> rows) =>
      rows.map(encodeRow).join('\r\n');

  /// Writes [rows] as UTF-8 CSV with a BOM (so Excel opens Arabic text
  /// correctly) and returns the temp file.
  static Future<File> writeCsv(String fileName, List<List<Object?>> rows) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(encode(rows))];
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareFile(File file, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: subject,
      text: subject,
    ));
  }

  // -------------------------------------------------------------- products

  static const productHeader = [
    'name',
    'barcode',
    'price',
    'cost',
    'stock',
    'category',
    'unit',
    'low_stock_threshold',
    'id',
  ];

  static Future<File> productsToFile(List<Product> products) {
    final rows = <List<Object?>>[
      productHeader,
      for (final p in products)
        [
          p.name,
          p.hasBarcode ? p.barcode : '',
          _n(p.price),
          _n(p.costPrice),
          p.trackStock ? _n(p.stock) : '',
          p.category,
          p.unit.name,
          p.lowStockThreshold,
          p.id,
        ],
    ];
    return writeCsv('products_${_stamp()}.csv', rows);
  }

  static Future<void> shareProducts(
      List<Product> products, AppLocalizations l10n) async {
    final file = await productsToFile(products);
    await shareFile(file, subject: l10n.products);
  }

  /// Opens the file picker and parses a products CSV. Rows whose barcode or
  /// id matches an existing product update it (keeping the id); others are
  /// created. Returns null if the user cancelled.
  static Future<List<Product>?> pickAndParseProducts(
      List<Product> existing) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.first;
    List<int>? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      bytes = await File(picked.path!).readAsBytes();
    }
    if (bytes == null) return null;
    final text = utf8.decode(bytes, allowMalformed: true);
    return parseProducts(text, existing);
  }

  static List<Product> parseProducts(String text, List<Product> existing) {
    final rows = parse(text);
    if (rows.isEmpty) return [];

    // Header detection: match known column names in any order/language.
    final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
    int col(List<String> names) {
      for (final n in names) {
        final i = header.indexOf(n);
        if (i >= 0) return i;
      }
      return -1;
    }

    final iName = col(['name', 'nom', 'الاسم', 'product', 'produit']);
    final hasHeader = iName >= 0;
    final iBarcode = hasHeader ? col(['barcode', 'code', 'code-barres', 'الباركود']) : 1;
    final iPrice = hasHeader ? col(['price', 'prix', 'السعر']) : 2;
    final iCost = hasHeader ? col(['cost', 'cost_price', 'coût', 'cout', 'التكلفة']) : 3;
    final iStock = hasHeader ? col(['stock', 'qty', 'quantité', 'المخزون']) : 4;
    final iCategory = hasHeader ? col(['category', 'catégorie', 'categorie', 'الفئة']) : 5;
    final iUnit = hasHeader ? col(['unit', 'unité', 'unite', 'الوحدة']) : 6;
    final iThreshold = hasHeader ? col(['low_stock_threshold', 'threshold', 'seuil']) : 7;
    final iId = hasHeader ? col(['id']) : 8;
    final nameIndex = hasHeader ? iName : 0;

    String cell(List<String> row, int i) =>
        i >= 0 && i < row.length ? row[i].trim() : '';
    double num(String s) =>
        double.tryParse(s.replaceAll(',', '.').replaceAll(' ', '')) ?? 0;

    final byBarcode = {
      for (final p in existing)
        if (p.hasBarcode && p.barcode.isNotEmpty) p.barcode: p
    };
    final byId = {for (final p in existing) p.id: p};
    final byName = {for (final p in existing) p.name.toLowerCase(): p};

    final out = <Product>[];
    for (final row in rows.skip(hasHeader ? 1 : 0)) {
      final name = cell(row, nameIndex);
      if (name.isEmpty) continue;
      final barcode = cell(row, iBarcode);
      final id = cell(row, iId);
      final match = (id.isNotEmpty ? byId[id] : null) ??
          (barcode.isNotEmpty ? byBarcode[barcode] : null) ??
          byName[name.toLowerCase()];
      final stockText = cell(row, iStock);
      final unitText = cell(row, iUnit).toLowerCase();
      final unit = unitText.isEmpty
          ? (match?.unit ?? ProductUnit.piece)
          : ProductUnitX.fromName(unitText == 'pc' || unitText == 'pcs'
              ? 'piece'
              : unitText);
      out.add(Product(
        id: match?.id ?? (id.isNotEmpty ? id : const Uuid().v4()),
        name: name,
        barcode: barcode,
        price: iPrice >= 0 ? num(cell(row, iPrice)) : (match?.price ?? 0),
        stock: stockText.isEmpty ? (match?.stock ?? 0) : num(stockText),
        hasBarcode: barcode.isNotEmpty,
        costPrice: iCost >= 0 && cell(row, iCost).isNotEmpty
            ? num(cell(row, iCost))
            : (match?.costPrice ?? 0),
        category: cell(row, iCategory).isNotEmpty
            ? cell(row, iCategory)
            : (match?.category ?? ''),
        lowStockThreshold: int.tryParse(cell(row, iThreshold)) ??
            (match?.lowStockThreshold ?? 5),
        unit: unit,
        trackStock: stockText.isNotEmpty || (match?.trackStock ?? true),
        updatedAt: DateTime.now(),
      ));
    }
    return out;
  }

  // ----------------------------------------------------------------- sales

  static Future<File> salesToFile(List<Sale> sales, AppLocalizations l10n) {
    final rows = <List<Object?>>[
      [
        l10n.t('invoice'),
        l10n.date,
        l10n.t('customer'),
        l10n.t('payment_method'),
        l10n.subtotal,
        l10n.discount,
        l10n.total,
        l10n.t('paid_amount'),
        l10n.t('remaining'),
        l10n.t('profit_label'),
        l10n.t('items_sold'),
        l10n.t('filter_by_cashier'),
        l10n.t('refunded'),
      ],
      for (final s in sales)
        [
          s.number > 0 ? s.number : s.id.substring(0, 8),
          s.dateTime.toIso8601String().substring(0, 19).replaceAll('T', ' '),
          s.customerName ?? '',
          l10n.t(s.paymentMethod.labelKey),
          _n(s.subtotal),
          _n(s.discountAmount),
          _n(s.total),
          _n(s.amountPaid),
          _n(s.amountDue),
          _n(s.profit),
          _n(s.totalItemsCount),
          s.cashierName ?? '',
          s.isRefunded ? 'yes' : '',
        ],
    ];
    return writeCsv('sales_${_stamp()}.csv', rows);
  }

  /// One row per sold line, for product-level analysis in a spreadsheet.
  static Future<File> saleItemsToFile(List<Sale> sales, AppLocalizations l10n) {
    final rows = <List<Object?>>[
      [
        'invoice',
        l10n.date,
        l10n.t('product_name'),
        l10n.quantity,
        l10n.t('unit'),
        l10n.price,
        l10n.t('cost'),
        l10n.total,
        l10n.t('profit_label'),
      ],
      for (final s in sales)
        if (!s.isRefunded)
          for (final i in s.items)
            [
              s.number > 0 ? s.number : s.id.substring(0, 8),
              s.dateTime.toIso8601String().substring(0, 19).replaceAll('T', ' '),
              i.productName,
              _n(i.quantity),
              i.unit.name,
              _n(i.unitPrice),
              _n(i.unitCost),
              _n(i.lineTotal),
              _n(i.lineProfit),
            ],
    ];
    return writeCsv('sale_items_${_stamp()}.csv', rows);
  }

  static Future<File> expensesToFile(
      List<Expense> expenses, AppLocalizations l10n) {
    final rows = <List<Object?>>[
      [l10n.date, l10n.t('expense_title'), l10n.category, l10n.amount, l10n.notes],
      for (final e in expenses)
        [
          e.dateTime.toIso8601String().substring(0, 19).replaceAll('T', ' '),
          e.title,
          l10n.t(e.category.labelKey),
          _n(e.amount),
          e.note,
        ],
    ];
    return writeCsv('expenses_${_stamp()}.csv', rows);
  }

  // ----------------------------------------------------------------- parse

  /// Parses CSV text (comma or semicolon separated, quoted fields, CRLF).
  static List<List<String>> parse(String text) {
    var input = text;
    if (input.startsWith('\uFEFF')) input = input.substring(1);
    // Detect separator from the first line.
    final firstLine = input.split('\n').first;
    final sep = firstLine.split(';').length > firstLine.split(',').length
        ? ';'
        : ',';

    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == sep) {
        row.add(field.toString());
        field.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(ch);
      }
    }
    row.add(field.toString());
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    return rows;
  }

  // --------------------------------------------------------------- helpers

  static String _n(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static String _stamp() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}';
  }
}
