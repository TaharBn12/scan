import 'package:flutter/foundation.dart';

import '../../../core/cloud/cloud_database.dart';

/// One cashier session at the till ("وردية"): opened with a float of change,
/// closed with a physical count of the drawer.
///
/// The point is accountability without paperwork: the app knows exactly how
/// much cash *should* be in the drawer, the cashier types what is actually
/// there, and the difference (عجز / فائض) is recorded forever.
class Shift {
  final String id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String openedBy;
  final String? closedBy;

  /// Change money placed in the drawer at opening.
  final double openingFloat;

  /// Cash physically counted at closing (null while the shift is open).
  final double? countedCash;

  /// Snapshot of the computed figures at closing.
  final double cashSales;
  final double creditCollected;
  /// Cash handed back to customers for returns processed in this shift.
  final double returnsPaidOut;
  final double paidOut;
  final int invoiceCount;
  final String note;

  const Shift({
    required this.id,
    required this.openedAt,
    required this.openedBy,
    this.closedAt,
    this.closedBy,
    this.openingFloat = 0,
    this.countedCash,
    this.cashSales = 0,
    this.creditCollected = 0,
    this.returnsPaidOut = 0,
    this.paidOut = 0,
    this.invoiceCount = 0,
    this.note = '',
  });

  bool get isOpen => closedAt == null;

  /// What the drawer should hold: float + cash in − cash out.
  double get expectedCash =>
      openingFloat + cashSales + creditCollected - returnsPaidOut - paidOut;

  /// Positive = surplus (فائض), negative = shortage (عجز).
  double get difference => (countedCash ?? expectedCash) - expectedCash;

  Duration get duration => (closedAt ?? DateTime.now()).difference(openedAt);

  Shift copyWith({
    DateTime? closedAt,
    String? closedBy,
    double? countedCash,
    double? cashSales,
    double? creditCollected,
    double? returnsPaidOut,
    double? paidOut,
    int? invoiceCount,
    String? note,
  }) =>
      Shift(
        id: id,
        openedAt: openedAt,
        openedBy: openedBy,
        openingFloat: openingFloat,
        closedAt: closedAt ?? this.closedAt,
        closedBy: closedBy ?? this.closedBy,
        countedCash: countedCash ?? this.countedCash,
        cashSales: cashSales ?? this.cashSales,
        creditCollected: creditCollected ?? this.creditCollected,
        returnsPaidOut: returnsPaidOut ?? this.returnsPaidOut,
        paidOut: paidOut ?? this.paidOut,
        invoiceCount: invoiceCount ?? this.invoiceCount,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'openedAt': openedAt.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
        'openedBy': openedBy,
        'closedBy': closedBy,
        'openingFloat': openingFloat,
        'countedCash': countedCash,
        'cashSales': cashSales,
        'creditCollected': creditCollected,
        'returnsPaidOut': returnsPaidOut,
        'paidOut': paidOut,
        'invoiceCount': invoiceCount,
        'note': note,
      };

  factory Shift.fromMap(Map<String, dynamic> map) => Shift(
        id: map['id'] as String? ?? '',
        openedAt: DateTime.tryParse(map['openedAt'] as String? ?? '') ??
            DateTime.now(),
        closedAt: DateTime.tryParse(map['closedAt'] as String? ?? ''),
        openedBy: map['openedBy'] as String? ?? '',
        closedBy: map['closedBy'] as String?,
        openingFloat: (map['openingFloat'] as num?)?.toDouble() ?? 0,
        countedCash: (map['countedCash'] as num?)?.toDouble(),
        cashSales: (map['cashSales'] as num?)?.toDouble() ?? 0,
        creditCollected: (map['creditCollected'] as num?)?.toDouble() ?? 0,
        returnsPaidOut: (map['returnsPaidOut'] as num?)?.toDouble() ?? 0,
        paidOut: (map['paidOut'] as num?)?.toDouble() ?? 0,
        invoiceCount: (map['invoiceCount'] as num?)?.toInt() ?? 0,
        note: map['note'] as String? ?? '',
      );
}

/// Persistent shift log. Only one shift can be open at a time.
class ShiftStore {
  ShiftStore._();

  static final ShiftStore instance = ShiftStore._();

  /// The open shift, or null when the till is closed.
  final ValueNotifier<Shift?> current = ValueNotifier<Shift?>(null);

  /// Closed shifts, newest first.
  final ValueNotifier<List<Shift>> history = ValueNotifier<List<Shift>>(const []);

  void load() {
    final all = CloudDatabase.shiftsBox.values
        .map((raw) => Shift.fromMap(Map<String, dynamic>.from(raw as Map)))
        .where((s) => s.id.isNotEmpty)
        .toList()
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    current.value = all.where((s) => s.isOpen).isEmpty
        ? null
        : all.firstWhere((s) => s.isOpen);
    history.value = all.where((s) => !s.isOpen).take(60).toList();
  }

  Future<Shift> open({
    required double openingFloat,
    required String openedBy,
  }) async {
    final shift = Shift(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      openedAt: DateTime.now(),
      openedBy: openedBy,
      openingFloat: openingFloat,
    );
    await CloudDatabase.shiftsBox.put(shift.id, shift.toMap());
    load();
    return shift;
  }

  Future<Shift?> close({
    required double countedCash,
    required double cashSales,
    required double creditCollected,
    double returnsPaidOut = 0,
    required double paidOut,
    required int invoiceCount,
    String? closedBy,
    String note = '',
  }) async {
    final open = current.value;
    if (open == null) return null;
    final closed = open.copyWith(
      closedAt: DateTime.now(),
      closedBy: closedBy,
      countedCash: countedCash,
      cashSales: cashSales,
      creditCollected: creditCollected,
      returnsPaidOut: returnsPaidOut,
      paidOut: paidOut,
      invoiceCount: invoiceCount,
      note: note,
    );
    await CloudDatabase.shiftsBox.put(closed.id, closed.toMap());
    load();
    return closed;
  }

  /// Keeps the log from growing forever on a busy till.
  Future<void> prune({int keep = 120}) async {
    final box = CloudDatabase.shiftsBox;
    if (box.length <= keep) return;
    final all = box.values
        .map((raw) => Shift.fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList()
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    for (final old in all.skip(keep)) {
      await box.delete(old.id);
    }
    load();
  }
}

final shiftStore = ShiftStore.instance;
