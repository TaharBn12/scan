import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/hive_database.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/shop/domain/entities/shop.dart';

/// Exports/imports everything stored locally as a single JSON document.
///
/// Backups can be written to a file (in the app's documents folder) and
/// shared through any app (Drive, WhatsApp, e-mail...), or copied as text.
/// Import accepts a file picked by the user or pasted text.
class BackupHelper {
  static const int backupVersion = 2;
  static const _lastBackupKey = 'last_backup_at';
  static const _autoBackupKey = 'auto_backup_enabled';
  static const _keepBackups = 7;

  static String exportAsJson({bool pretty = true}) {
    final products =
        HiveDatabase.productBox.values.map((p) => p.toMap()).toList();

    List<Map<String, dynamic>> dump(dynamic box) => (box.values as Iterable)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();

    final shop = HiveDatabase.shopBox.get('shop_details')?.toMap();

    // Settings worth carrying to a new phone (never the PIN hashes).
    final settingsBox = HiveDatabase.settingsBox;
    const settingKeys = [
      'app_locale',
      'currency_symbol',
      'currency_symbol_before',
      'currency_decimals',
      'decimal_quantities',
      'sale_counter',
      'printer_mac',
      'printer_name',
      'paper_width',
      'auto_print',
      'theme_mode',
      'theme_accent',
      'compact_mode',
      'quick_sale_favorites',
    ];
    final settings = <String, dynamic>{
      for (final k in settingKeys)
        if (settingsBox.containsKey(k)) k: settingsBox.get(k),
    };

    final backup = {
      'version': backupVersion,
      'app': 'billing_app',
      'exportedAt': DateTime.now().toIso8601String(),
      'products': products,
      'sales': dump(HiveDatabase.salesBox),
      'customers': dump(HiveDatabase.customersBox),
      'expenses': dump(HiveDatabase.expensesBox),
      'purchases': dump(HiveDatabase.purchasesBox),
      'stockMovements': dump(HiveDatabase.stockMovementsBox),
      'users': dump(HiveDatabase.usersBox),
      'shop': shop,
      'settings': settings,
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(backup)
        : jsonEncode(backup);
  }

  // ------------------------------------------------------------- files

  static Future<Directory> backupDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _fileName([DateTime? at]) {
    final d = at ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'billing_backup_${d.year}-${two(d.month)}-${two(d.day)}_${two(d.hour)}${two(d.minute)}.json';
  }

  /// Writes a backup file to the app's documents folder and returns it.
  static Future<File> exportToFile() async {
    final dir = await backupDirectory();
    final file = File('${dir.path}/${_fileName()}');
    await file.writeAsString(exportAsJson(pretty: false), flush: true);
    await HiveDatabase.settingsBox
        .put(_lastBackupKey, DateTime.now().toIso8601String());
    await _pruneOldBackups(dir);
    return file;
  }

  /// Writes the backup file, then opens the system share sheet so the
  /// merchant can send it to Drive / WhatsApp / e-mail.
  static Future<File> exportAndShare({String? subject}) async {
    final file = await exportToFile();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: subject ?? 'Billing backup',
      text: subject ?? 'Billing backup',
    ));
    return file;
  }

  static Future<List<File>> listBackups() async {
    final dir = await backupDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  static Future<void> _pruneOldBackups(Directory dir) async {
    final files = await listBackups();
    for (final f in files.skip(_keepBackups)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  static DateTime? lastBackupAt() {
    final raw = HiveDatabase.settingsBox.get(_lastBackupKey) as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static bool isAutoBackupEnabled() =>
      HiveDatabase.settingsBox.get(_autoBackupKey) as bool? ?? true;

  static Future<void> setAutoBackupEnabled(bool value) async {
    await HiveDatabase.settingsBox.put(_autoBackupKey, value);
  }

  /// Called at app start: writes a backup at most once per day. Never
  /// throws.
  static Future<void> autoBackupIfDue() async {
    try {
      if (!isAutoBackupEnabled()) return;
      final last = lastBackupAt();
      if (last != null && DateTime.now().difference(last).inHours < 20) return;
      if (HiveDatabase.salesBox.isEmpty && HiveDatabase.productBox.isEmpty) {
        return;
      }
      await exportToFile();
    } catch (_) {}
  }

  // ------------------------------------------------------------- import

  static Future<BackupImportSummary> importFromFile(File file) async {
    return importFromJson(await file.readAsString());
  }

  /// Merges a previously exported backup into local storage. Existing
  /// records with a matching id are overwritten; anything already on the
  /// device that isn't in the backup is left untouched (nothing is deleted).
  /// Throws a [FormatException] if [jsonString] isn't a backup produced by
  /// [exportAsJson].
  static Future<BackupImportSummary> importFromJson(String jsonString) async {
    final decoded = jsonDecode(jsonString.trim());
    if (decoded is! Map || decoded['products'] is! List) {
      throw const FormatException('This does not look like a backup file.');
    }

    int productsImported = 0;
    int salesImported = 0;
    int customersImported = 0;
    int expensesImported = 0;
    bool shopImported = false;

    for (final raw in decoded['products'] as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      if ((map['id'] as String?)?.isEmpty ?? true) continue;
      final product = Product.fromMap(map);
      await HiveDatabase.productBox.put(product.id, product);
      productsImported++;
    }

    Future<int> restore(dynamic list, dynamic box) async {
      if (list is! List) return 0;
      int n = 0;
      for (final raw in list) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id'] as String?;
        if (id == null || id.isEmpty) continue;
        await box.put(id, map);
        n++;
      }
      return n;
    }

    salesImported = await restore(decoded['sales'], HiveDatabase.salesBox);
    customersImported =
        await restore(decoded['customers'], HiveDatabase.customersBox);
    expensesImported =
        await restore(decoded['expenses'], HiveDatabase.expensesBox);
    await restore(decoded['purchases'], HiveDatabase.purchasesBox);
    await restore(decoded['stockMovements'], HiveDatabase.stockMovementsBox);
    await restore(decoded['users'], HiveDatabase.usersBox);

    final shop = decoded['shop'];
    if (shop is Map) {
      await HiveDatabase.shopBox.put('shop_details', Shop.fromMap(shop));
      shopImported = true;
    }

    final settings = decoded['settings'];
    if (settings is Map) {
      for (final entry in settings.entries) {
        if (entry.key is String && entry.value != null) {
          await HiveDatabase.settingsBox.put(entry.key, entry.value);
        }
      }
    }

    // Keep invoice numbering monotonic after a restore.
    int maxNumber = HiveDatabase.settingsBox.get('sale_counter') as int? ?? 0;
    for (final raw in HiveDatabase.salesBox.values) {
      final n = ((raw as Map)['number'] as num?)?.toInt() ?? 0;
      if (n > maxNumber) maxNumber = n;
    }
    await HiveDatabase.settingsBox.put('sale_counter', maxNumber);

    return BackupImportSummary(
      productsImported: productsImported,
      salesImported: salesImported,
      customersImported: customersImported,
      expensesImported: expensesImported,
      shopImported: shopImported,
    );
  }
}

class BackupImportSummary {
  final int productsImported;
  final int salesImported;
  final int customersImported;
  final int expensesImported;
  final bool shopImported;

  const BackupImportSummary({
    required this.productsImported,
    required this.salesImported,
    required this.customersImported,
    this.expensesImported = 0,
    required this.shopImported,
  });
}
