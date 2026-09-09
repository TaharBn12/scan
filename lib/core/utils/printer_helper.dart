import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';

import '../cloud/cloud_database.dart';
import 'money.dart';

class EscPos {
  static const List<int> init = [0x1B, 0x40];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignRight = [0x1B, 0x61, 0x02];
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  static const List<int> textNormal = [0x1D, 0x21, 0x00];
  static const List<int> textLarge = [0x1D, 0x21, 0x11];
  static const List<int> textDoubleHeight = [0x1D, 0x21, 0x01];
  static const List<int> lineFeed = [0x0A];
  static const List<int> cut = [0x1D, 0x56, 0x00];

  /// Print a CODE128 barcode (GS k m n d1..dn with m = 73).
  static List<int> barcodeCode128(String data, {int height = 60}) {
    final bytes = <int>[];
    bytes.addAll([0x1D, 0x68, height]); // height
    bytes.addAll([0x1D, 0x77, 0x02]); // module width
    bytes.addAll([0x1D, 0x48, 0x02]); // HRI below
    bytes.addAll([0x1D, 0x66, 0x00]); // HRI font
    final payload = [0x7B, 0x42, ...data.codeUnits]; // {B = code set B
    bytes.addAll([0x1D, 0x6B, 73, payload.length, ...payload]);
    return bytes;
  }
}

class PrinterHelper {
  // Singleton
  static final PrinterHelper _instance = PrinterHelper._internal();
  factory PrinterHelper() => _instance;
  PrinterHelper._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Characters per line: 32 for 58mm paper, 48 for 80mm. Follows the
  /// "paper_width" setting (58/80) chosen in Settings.
  int get charsPerLine {
    try {
      final width = CloudDatabase.settingsBox.get('paper_width') as int? ?? 58;
      return width >= 80 ? 48 : 32;
    } catch (_) {
      return 32;
    }
  }

  Future<bool> checkPermission() async {
    // Android 12+ needs BLUETOOTH_SCAN, BLUETOOTH_CONNECT
    // Older Android needs BLUETOOTH, BLUETOOTH_ADMIN, ACCESS_FINE_LOCATION
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<List<BluetoothInfo>> getBondedDevices() async {
    try {
      final List<BluetoothInfo> list =
          await PrintBluetoothThermal.pairedBluetooths;
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    try {
      final bool result =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      _isConnected = result;
      return result;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _isConnected = !result;
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<void> printText(String text) async {
    if (!_isConnected) return;
    final bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      await PrintBluetoothThermal.writeBytes(
          [...EscPos.init, ..._textToBytes(text), ...EscPos.lineFeed]);
    }
  }

  Future<void> printBytes(List<int> bytes) async {
    if (!_isConnected) return;
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  String get _divider => ''.padRight(charsPerLine, '-');

  Future<void> printReceipt({
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required List<Map<String, dynamic>> items, // name, qty, price, total
    required double total,
    required String footer,
    double subtotal = 0,
    double discount = 0,
    String? paymentMethod,
    int? invoiceNumber,
    DateTime? dateTime,
    String? customerName,
    double? paidAmount,
    double? dueAmount,
    String? cashierName,
  }) async {
    if (!_isConnected) return;

    List<int> bytes = [];
    bytes += EscPos.init;

    // Shop Name (Center, Bold, Large)
    bytes += EscPos.alignCenter;
    bytes += EscPos.boldOn;
    bytes += EscPos.textLarge;
    bytes += _textToBytes(shopName);
    bytes += EscPos.lineFeed;

    // Address & Phone (Normal, Center)
    bytes += EscPos.textNormal;
    bytes += EscPos.boldOff;
    if (address1.isNotEmpty) {
      bytes += _textToBytes(address1);
      bytes += EscPos.lineFeed;
    }
    if (address2.isNotEmpty) {
      bytes += _textToBytes(address2);
      bytes += EscPos.lineFeed;
    }
    if (phone.isNotEmpty) {
      bytes += _textToBytes(phone);
      bytes += EscPos.lineFeed;
    }

    // Date and Time / invoice number
    final formattedDate =
        DateFormat('dd-MM-yyyy HH:mm').format(dateTime ?? DateTime.now());
    bytes += _textToBytes(formattedDate);
    bytes += EscPos.lineFeed;
    if (invoiceNumber != null && invoiceNumber > 0) {
      bytes += _textToBytes('No: $invoiceNumber');
      bytes += EscPos.lineFeed;
    }
    if (customerName != null && customerName.trim().isNotEmpty) {
      bytes += _textToBytes('Client: ${_ascii(customerName)}');
      bytes += EscPos.lineFeed;
    }
    if (cashierName != null && cashierName.trim().isNotEmpty) {
      bytes += _textToBytes('Caissier: ${_ascii(cashierName)}');
      bytes += EscPos.lineFeed;
    }

    bytes += _textToBytes(_divider);
    bytes += EscPos.lineFeed;

    // Header (Align Left)
    bytes += EscPos.alignLeft;
    bytes += _textToBytes(_row('Article', 'Prix', 'Total'));
    bytes += EscPos.lineFeed;
    bytes += _textToBytes(_divider);
    bytes += EscPos.lineFeed;

    // Items
    for (var item in items) {
      final name = _ascii(item['name'].toString());
      final qty = formatQty((item['qty'] as num?) ?? 1);
      final unit = _unitSuffix(item['unit']?.toString());
      final price = Money.plain((item['price'] as num?) ?? 0);
      final totalItem = Money.plain((item['total'] as num?) ?? 0);

      // Line 1: product name (wrapped to paper width)
      bytes += _textToBytes(_clip(name, charsPerLine));
      bytes += EscPos.lineFeed;
      // Line 2: "  2 x 150.00" ... "300.00"
      bytes += _textToBytes(_row('  $qty$unit x $price', '', totalItem));
      bytes += EscPos.lineFeed;
    }

    bytes += _textToBytes(_divider);
    bytes += EscPos.lineFeed;

    bytes += EscPos.alignRight;
    if (discount > 0) {
      bytes += _textToBytes('Sous-total: ${Money.plain(subtotal)}');
      bytes += EscPos.lineFeed;
      bytes += _textToBytes('Remise: -${Money.plain(discount)}');
      bytes += EscPos.lineFeed;
    }

    // Total (Align Right, big)
    bytes += EscPos.boldOn;
    bytes += EscPos.textDoubleHeight;
    bytes += _textToBytes('TOTAL: ${Money.plain(total)} ${_ascii(Money.symbol)}');
    bytes += EscPos.lineFeed;
    bytes += EscPos.textNormal;
    bytes += EscPos.boldOff;

    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      bytes += _textToBytes('Paiement: $paymentMethod');
      bytes += EscPos.lineFeed;
    }
    if (paidAmount != null && dueAmount != null && dueAmount > 0.005) {
      bytes += _textToBytes('Paye: ${Money.plain(paidAmount)}');
      bytes += EscPos.lineFeed;
      bytes += EscPos.boldOn;
      bytes += _textToBytes('Reste: ${Money.plain(dueAmount)}');
      bytes += EscPos.boldOff;
      bytes += EscPos.lineFeed;
    }
    bytes += EscPos.lineFeed;

    // Footer (Center)
    bytes += EscPos.alignCenter;
    if (footer.isNotEmpty) {
      bytes += _textToBytes(_ascii(footer));
      bytes += EscPos.lineFeed;
    }
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  /// Prints one sticker: product name, barcode (CODE128) and price.
  Future<void> printLabel({
    required String name,
    required String barcode,
    String? price,
    int copies = 1,
  }) async {
    if (!_isConnected) return;
    for (int i = 0; i < copies; i++) {
      List<int> bytes = [];
      bytes += EscPos.init;
      bytes += EscPos.alignCenter;
      bytes += EscPos.boldOn;
      bytes += _textToBytes(_clip(_ascii(name), charsPerLine));
      bytes += EscPos.boldOff;
      bytes += EscPos.lineFeed;
      if (barcode.isNotEmpty) {
        bytes += EscPos.barcodeCode128(barcode);
        bytes += EscPos.lineFeed;
      }
      if (price != null && price.isNotEmpty) {
        bytes += EscPos.textDoubleHeight;
        bytes += _textToBytes(_ascii(price));
        bytes += EscPos.textNormal;
        bytes += EscPos.lineFeed;
      }
      bytes += EscPos.lineFeed;
      bytes += EscPos.lineFeed;
      await PrintBluetoothThermal.writeBytes(bytes);
    }
  }

  /// Prints a simple key/value summary (daily close / Z report).
  Future<void> printSummary({
    required String title,
    required List<MapEntry<String, String>> lines,
    String? shopName,
  }) async {
    if (!_isConnected) return;
    List<int> bytes = [];
    bytes += EscPos.init;
    bytes += EscPos.alignCenter;
    if (shopName != null && shopName.isNotEmpty) {
      bytes += EscPos.boldOn;
      bytes += _textToBytes(_ascii(shopName));
      bytes += EscPos.boldOff;
      bytes += EscPos.lineFeed;
    }
    bytes += EscPos.textDoubleHeight;
    bytes += _textToBytes(_ascii(title));
    bytes += EscPos.textNormal;
    bytes += EscPos.lineFeed;
    bytes += _textToBytes(DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()));
    bytes += EscPos.lineFeed;
    bytes += _textToBytes(_divider);
    bytes += EscPos.lineFeed;
    bytes += EscPos.alignLeft;
    for (final line in lines) {
      bytes += _textToBytes(_row(_ascii(line.key), '', _ascii(line.value)));
      bytes += EscPos.lineFeed;
    }
    bytes += _textToBytes(_divider);
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  // ------------------------------------------------------------ helpers

  String _unitSuffix(String? unit) {
    const suffixes = {'kg': 'kg', 'g': 'g', 'l': 'L', 'ml': 'ml', 'm': 'm'};
    return suffixes[unit] ?? '';
  }

  /// Left text, optional middle text, right-aligned text, on one line.
  String _row(String left, String middle, String right) {
    final rightW = right.length;
    final midW = middle.isEmpty ? 0 : middle.length + 1;
    final leftW = charsPerLine - rightW - midW - 1;
    final l = _clip(left, leftW < 4 ? 4 : leftW).padRight(leftW < 4 ? 4 : leftW);
    final m = middle.isEmpty ? '' : ' $middle';
    final line = '$l$m';
    final pad = charsPerLine - line.length - rightW;
    return line + ''.padRight(pad < 1 ? 1 : pad) + right;
  }

  String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);

  /// Cheap thermal printers only understand single-byte code pages, so
  /// Arabic/accented text is transliterated to plain ASCII where possible.
  String _ascii(String input) {
    const map = {
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'à': 'a', 'â': 'a', 'ä': 'a',
      'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'É': 'E', 'È': 'E', 'Ê': 'E', 'À': 'A', 'Â': 'A', 'Ç': 'C',
      'Ô': 'O', 'Û': 'U', 'Ù': 'U', 'Î': 'I', 'Ï': 'I', 'Ë': 'E', 'Ä': 'A',
      'Ö': 'O', 'Ü': 'U', 'œ': 'oe', 'Œ': 'OE', '€': 'EUR', '—': '-',
      '–': '-', '’': "'", '“': '"', '”': '"', '«': '"', '»': '"',
      // Arabic letters -> Latin approximation
      'ا': 'a', 'أ': 'a', 'إ': 'i', 'آ': 'a', 'ب': 'b', 'ت': 't', 'ث': 'th',
      'ج': 'j', 'ح': 'h', 'خ': 'kh', 'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z',
      'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': '3',
      'غ': 'gh', 'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n',
      'ه': 'h', 'و': 'w', 'ي': 'y', 'ى': 'a', 'ة': 'a', 'ء': "'", 'ؤ': 'w',
      'ئ': 'y', '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9', '،': ',', '؛': ';',
      '؟': '?', 'ـ': '',
      // Arabic diacritics dropped
      'َ': '', 'ُ': '', 'ِ': '', 'ّ': '', 'ْ': '', 'ً': '', 'ٌ': '', 'ٍ': '',
    };
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      if (rune < 128) {
        buffer.write(ch);
      } else if (map.containsKey(ch)) {
        buffer.write(map[ch]);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }

  List<int> _textToBytes(String text) {
    // Everything goes through the ASCII fallback so we never send multi-byte
    // UTF-16 code units that garble the print-out.
    return List.from(_ascii(text).codeUnits);
  }
}
