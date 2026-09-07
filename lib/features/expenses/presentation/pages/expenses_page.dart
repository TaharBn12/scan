import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/expense.dart';
import '../bloc/expense_bloc.dart';

enum _Period { today, week, month, all }

/// Daily expenses (rent, electricity, salaries, transport...). Their total is
/// subtracted from gross profit on the Reports page to show net profit.
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  _Period _period = _Period.month;
  ExpenseCategory? _categoryFilter;

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _Period.today:
        return (today, today.add(const Duration(days: 1)));
      case _Period.week:
        return (
          today.subtract(const Duration(days: 6)),
          today.add(const Duration(days: 1))
        );
      case _Period.month:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 1)
        );
      case _Period.all:
        return (DateTime(2000), DateTime(2100));
    }
  }

  String _periodLabel(AppLocalizations l10n, _Period p) {
    switch (p) {
      case _Period.today:
        return l10n.today;
      case _Period.week:
        return l10n.thisWeek;
      case _Period.month:
        return l10n.thisMonth;
      case _Period.all:
        return l10n.t('all_time');
    }
  }

  Future<void> _openForm({Expense? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: context.read<ExpenseBloc>(),
        child: _ExpenseForm(existing: existing),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.t('expense_saved')),
          backgroundColor: Colors.green));
    }
  }

  Future<void> _confirmDelete(Expense e) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.t('delete_expense')),
        content: Text(l10n.t('delete_expense_confirm', {'title': e.title})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(l10n.delete,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<ExpenseBloc>().add(DeleteExpense(e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (start, end) = _range();
    final dateFmt = DateFormat.yMMMEd(l10n.locale.toString());

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/menu'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('add_expense')),
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, state) {
          final inRange = state.expenses
              .where((e) =>
                  !e.dateTime.isBefore(start) && e.dateTime.isBefore(end))
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
          final visible = _categoryFilter == null
              ? inRange
              : inRange.where((e) => e.category == _categoryFilter).toList();
          final total = inRange.fold(0.0, (s, e) => s + e.amount);
          final breakdown = state.breakdownBetween(start, end);

          // Group by day for section headers.
          final groups = <DateTime, List<Expense>>{};
          for (final e in visible) {
            final day = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
            groups.putIfAbsent(day, () => []).add(e);
          }
          final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

          return Column(
            children: [
              // Period selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    for (final p in _Period.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(_periodLabel(l10n, p)),
                          selected: _period == p,
                          onSelected: (_) => setState(() => _period = p),
                        ),
                      ),
                  ],
                ),
              ),
              // Total card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.t('total_expenses'),
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(Money.format(total),
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(l10n.t('items_count', {'count': inRange.length}),
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer
                                  .withValues(alpha: 0.8),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
              // Category filter chips
              if (breakdown.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: FilterChip(
                          label: Text(l10n.all),
                          selected: _categoryFilter == null,
                          onSelected: (_) =>
                              setState(() => _categoryFilter = null),
                        ),
                      ),
                      for (final entry in breakdown.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value)))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: FilterChip(
                            avatar: Icon(_categoryIcon(entry.key), size: 16),
                            label: Text(
                                '${l10n.t(entry.key.labelKey)} · ${Money.format(entry.value)}'),
                            selected: _categoryFilter == entry.key,
                            onSelected: (_) => setState(() =>
                                _categoryFilter = _categoryFilter == entry.key
                                    ? null
                                    : entry.key),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64,
                                color: theme.disabledColor),
                            const SizedBox(height: 12),
                            Text(l10n.t('no_expenses'),
                                style: TextStyle(color: theme.disabledColor)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: days.length,
                        itemBuilder: (context, index) {
                          final day = days[index];
                          final items = groups[day]!;
                          final dayTotal =
                              items.fold(0.0, (s, e) => s + e.amount);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(4, 12, 4, 6),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(dateFmt.format(day),
                                        style: theme.textTheme.labelLarge),
                                    Text(Money.format(dayTotal),
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                                color: theme.colorScheme.error)),
                                  ],
                                ),
                              ),
                              for (final e in items)
                                Dismissible(
                                  key: ValueKey(e.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: AlignmentDirectional.centerEnd,
                                    padding: const EdgeInsetsDirectional.only(
                                        end: 20),
                                    decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: const Icon(Icons.delete,
                                        color: Colors.white),
                                  ),
                                  confirmDismiss: (_) async {
                                    await _confirmDelete(e);
                                    return false; // bloc reload removes it
                                  },
                                  child: Card(
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: theme
                                            .colorScheme.errorContainer,
                                        child: Icon(_categoryIcon(e.category),
                                            color: theme
                                                .colorScheme.onErrorContainer),
                                      ),
                                      title: Text(e.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      subtitle: Text(
                                        [
                                          l10n.t(e.category.labelKey),
                                          if (e.note.isNotEmpty) e.note,
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(
                                        '- ${Money.format(e.amount)}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.error),
                                      ),
                                      onTap: () => _openForm(existing: e),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

IconData _categoryIcon(ExpenseCategory c) {
  switch (c) {
    case ExpenseCategory.rent:
      return Icons.home_work_outlined;
    case ExpenseCategory.utilities:
      return Icons.bolt_outlined;
    case ExpenseCategory.salaries:
      return Icons.people_outline;
    case ExpenseCategory.supplies:
      return Icons.inventory_2_outlined;
    case ExpenseCategory.transport:
      return Icons.local_shipping_outlined;
    case ExpenseCategory.purchase:
      return Icons.shopping_bag_outlined;
    case ExpenseCategory.other:
      return Icons.more_horiz;
  }
}

// ------------------------------------------------------------------ form

class _ExpenseForm extends StatefulWidget {
  final Expense? existing;
  const _ExpenseForm({this.existing});

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late ExpenseCategory _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _amount =
        TextEditingController(text: e == null ? '' : Money.plain(e.amount));
    _note = TextEditingController(text: e?.note ?? '');
    _category = e?.category ?? ExpenseCategory.other;
    _date = e?.dateTime ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
          picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final e = widget.existing;
    final expense = Expense(
      id: e?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      amount: parseAmount(_amount.text),
      category: _category,
      dateTime: _date,
      note: _note.text.trim(),
      purchaseId: e?.purchaseId,
      updatedAt: DateTime.now(),
    );
    context.read<ExpenseBloc>().add(SaveExpense(expense));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dateFmt = DateFormat.yMMMd(l10n.locale.toString());
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  widget.existing == null
                      ? l10n.t('add_expense')
                      : l10n.t('edit_expense'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.t('expense_title'),
                  hintText: l10n.t('expense_title_hint'),
                  border: const OutlineInputBorder(),
                ),
                validator: AppValidators.required(l10n.t('required_field')),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.t('amount'),
                  suffixText: Money.symbol,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.t('enter_amount');
                  }
                  return AppValidators.positiveAmount(l10n)(v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: l10n.t('category'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final c in ExpenseCategory.values)
                    DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(_categoryIcon(c), size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.t(c.labelKey)),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text('${l10n.date}: ${dateFmt.format(_date)}'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: '${l10n.notes} (${l10n.t('optional')})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.existing != null)
                    TextButton.icon(
                      onPressed: () {
                        context
                            .read<ExpenseBloc>()
                            .add(DeleteExpense(widget.existing!.id));
                        Navigator.pop(context, false);
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: Text(l10n.delete,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
