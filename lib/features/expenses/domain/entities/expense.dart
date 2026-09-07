import 'package:equatable/equatable.dart';

enum ExpenseCategory {
  rent,
  utilities,
  salaries,
  supplies,
  transport,
  purchase,
  other,
}

extension ExpenseCategoryX on ExpenseCategory {
  String get labelKey => 'expense_cat_$name';

  static ExpenseCategory fromName(String? name) {
    if (name == null) return ExpenseCategory.other;
    return ExpenseCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class Expense extends Equatable {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime dateTime;
  final String note;
  /// Set when this expense was created automatically from a stock purchase.
  final String? purchaseId;
  final DateTime? updatedAt;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    this.category = ExpenseCategory.other,
    required this.dateTime,
    this.note = '',
    this.purchaseId,
    this.updatedAt,
  });

  Expense copyWith({
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? dateTime,
    String? note,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
      purchaseId: purchaseId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category.name,
        'dateTime': dateTime.toIso8601String(),
        'note': note,
        'purchaseId': purchaseId,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Expense.fromMap(Map map) => Expense(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        category: ExpenseCategoryX.fromName(map['category'] as String?),
        dateTime: DateTime.tryParse(map['dateTime'] as String? ?? '') ??
            DateTime.now(),
        note: map['note'] as String? ?? '',
        purchaseId: map['purchaseId'] as String?,
        updatedAt: map['updatedAt'] != null
            ? DateTime.tryParse(map['updatedAt'] as String)
            : null,
      );

  @override
  List<Object?> get props =>
      [id, title, amount, category, dateTime, note, purchaseId, updatedAt];
}
