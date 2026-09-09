import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/cash_change.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../shop/data/repositories/shop_repository_impl.dart';
import '../../data/shift_store.dart';

/// The cash drawer session: open with a float, watch the expected cash grow
/// live, close with a physical count and get the shortage/surplus recorded.
class ShiftPage extends StatelessWidget {
  const ShiftPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/menu'),
        ),
        title: Text(l10n.t('shift')),
      ),
      body: ValueListenableBuilder<Shift?>(
        valueListenable: shiftStore.current,
        builder: (context, open, _) {
          return BlocBuilder<SaleBloc, SaleState>(
            builder: (context, saleState) {
              return BlocBuilder<ExpenseBloc, ExpenseState>(
                builder: (context, expenseState) {
                  final totals = open == null
                      ? null
                      : ShiftTotals.compute(open, saleState, expenseState);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    children: [
                      if (open == null)
                        _ClosedState(onOpen: () => _openShift(context))
                      else
                        _OpenState(
                          shift: open,
                          totals: totals!,
                          onClose: () => _closeShift(context, open, totals),
                        ),
                      const SizedBox(height: 24),
                      SectionHeader(title: l10n.t('shift_history')),
                      const _History(),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- opening

  Future<void> _openShift(BuildContext context) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('open_shift')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('opening_float_hint'),
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.t('opening_float'),
                prefixText: '${Money.symbol} ',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, parseAmount(v)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseAmount(controller.text)),
            child: Text(l10n.t('open_shift')),
          ),
        ],
      ),
    );
    if (amount == null) return;
    await shiftStore.open(
      openingFloat: amount,
      openedBy: sessionController.currentUser?.name ?? '',
    );
    if (context.mounted) {
      showAppSnack(context, l10n.t('shift_opened'),
          icon: Icons.lock_open_rounded);
    }
  }

  // ------------------------------------------------------------- closing

  Future<void> _closeShift(
      BuildContext context, Shift shift, ShiftTotals totals) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final counted = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final typed = parseAmount(controller.text);
          final diff = typed - totals.expectedCash;
          return AlertDialog(
            title: Text(l10n.t('close_shift')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${l10n.t('expected_cash')}: ${Money.format(totals.expectedCash)}',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.t('counted_cash'),
                    prefixText: '${Money.symbol} ',
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
                if (controller.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DiffChip(diff: diff),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, parseAmount(controller.text)),
                child: Text(l10n.t('close_shift')),
              ),
            ],
          );
        },
      ),
    );
    if (counted == null) return;
    final closed = await shiftStore.close(
      countedCash: counted,
      cashSales: totals.cashSales,
      creditCollected: totals.creditCollected,
      returnsPaidOut: totals.returnsPaidOut,
      paidOut: totals.paidOut,
      invoiceCount: totals.invoiceCount,
      closedBy: sessionController.currentUser?.name,
    );
    await shiftStore.prune();
    if (closed == null || !context.mounted) return;
    showAppSnack(context, l10n.t('shift_closed'), icon: Icons.lock_rounded);
    await _showReport(context, closed);
  }

  /// Post-close summary with share + thermal print.
  Future<void> _showReport(BuildContext context, Shift shift) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.t('shift_report'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _ReportRow(l10n.t('opening_float'),
                  Money.format(shift.openingFloat)),
              _ReportRow(l10n.t('cash_sales'), Money.format(shift.cashSales)),
              _ReportRow(l10n.t('credit_collected'),
                  Money.format(shift.creditCollected)),
              if (shift.returnsPaidOut > 0)
                _ReportRow(l10n.t('returns_paid_out'),
                    '- ${Money.format(shift.returnsPaidOut)}'),
              _ReportRow(l10n.t('paid_out'), '- ${Money.format(shift.paidOut)}'),
              const Divider(height: 22),
              _ReportRow(l10n.t('expected_cash'),
                  Money.format(shift.expectedCash), bold: true),
              _ReportRow(l10n.t('counted_cash'),
                  Money.format(shift.countedCash ?? 0), bold: true),
              const SizedBox(height: 10),
              _DiffChip(diff: shift.difference),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _share(context, shift),
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: Text(l10n.t('share_text')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _print(context, shift),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(l10n.print),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _text(BuildContext context, Shift shift) {
    final l10n = context.l10n;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final shop = ShopRepositoryImpl.current();
    return [
      '${l10n.t('shift_report')} · ${shop.name}',
      '${fmt.format(shift.openedAt)} → ${fmt.format(shift.closedAt ?? DateTime.now())}',
      if (shift.openedBy.isNotEmpty) '${l10n.t('cashier')}: ${shift.openedBy}',
      '-' * 24,
      '${l10n.t('opening_float')}: ${Money.format(shift.openingFloat)}',
      '${l10n.t('cash_sales')}: ${Money.format(shift.cashSales)}',
      '${l10n.t('credit_collected')}: ${Money.format(shift.creditCollected)}',
      if (shift.returnsPaidOut > 0)
        '${l10n.t('returns_paid_out')}: -${Money.format(shift.returnsPaidOut)}',
      '${l10n.t('paid_out')}: -${Money.format(shift.paidOut)}',
      '${l10n.t('expected_cash')}: ${Money.format(shift.expectedCash)}',
      '${l10n.t('counted_cash')}: ${Money.format(shift.countedCash ?? 0)}',
      '${shift.difference < 0 ? l10n.t('shortage') : l10n.t('surplus')}: '
          '${Money.format(shift.difference.abs())}',
      '${l10n.t('invoices')}: ${shift.invoiceCount}',
    ].join('\n');
  }

  Future<void> _share(BuildContext context, Shift shift) async {
    final text = _text(context, shift);
    final subject = context.l10n.t('shift_report');
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  Future<void> _print(BuildContext context, Shift shift) async {
    final l10n = context.l10n;
    final printer = PrinterHelper();
    if (!printer.isConnected) {
      final mac = HiveDatabase.settingsBox.get('printer_mac') as String?;
      if (mac == null || mac.isEmpty || !await printer.connect(mac)) {
        if (context.mounted) {
          showAppSnack(context, l10n.t('no_printer'),
              icon: Icons.print_disabled_outlined);
        }
        return;
      }
    }
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    // Thermal printers are Latin-only: keep the labels ASCII.
    await printer.printSummary(
      title: 'SHIFT REPORT',
      shopName: ShopRepositoryImpl.current().name,
      lines: [
        MapEntry('Opened', fmt.format(shift.openedAt)),
        MapEntry('Closed', fmt.format(shift.closedAt ?? DateTime.now())),
        MapEntry('Cashier', shift.openedBy),
        MapEntry('Opening float', Money.plain(shift.openingFloat)),
        MapEntry('Cash sales', Money.plain(shift.cashSales)),
        MapEntry('Credit collected', Money.plain(shift.creditCollected)),
        // Goods handed back: cash that went out of the drawer.
        if (shift.returnsPaidOut > 0)
          MapEntry('Returns (cash out)',
              '-${Money.plain(shift.returnsPaidOut)}'),
        MapEntry('Paid out', Money.plain(shift.paidOut)),
        MapEntry('Expected', Money.plain(shift.expectedCash)),
        MapEntry('Counted', Money.plain(shift.countedCash ?? 0)),
        MapEntry(shift.difference < 0 ? 'SHORTAGE' : 'SURPLUS',
            Money.plain(shift.difference.abs())),
        MapEntry('Invoices', '${shift.invoiceCount}'),
      ],
    );
    if (context.mounted) {
      showAppSnack(context, l10n.t('printed_successfully'),
          icon: Icons.check_circle_outline);
    }
  }
}

/// Live figures for the open shift, recomputed from the blocs.
class ShiftTotals {
  final double cashSales;
  final double creditCollected;
  final double returnsPaidOut;
  final double paidOut;
  final int invoiceCount;
  final double openingFloat;

  const ShiftTotals({
    required this.cashSales,
    required this.creditCollected,
    required this.returnsPaidOut,
    required this.paidOut,
    required this.invoiceCount,
    required this.openingFloat,
  });

  double get expectedCash =>
      openingFloat + cashSales + creditCollected - returnsPaidOut - paidOut;

  static ShiftTotals compute(
      Shift shift, SaleState sales, ExpenseState expenses) {
    final from = shift.openedAt;
    final to = shift.closedAt ?? DateTime.now();
    bool inWindow(DateTime d) => !d.isBefore(from) && !d.isAfter(to);

    double cash = 0;
    double collected = 0;
    double returns = 0;
    int count = 0;
    for (final sale in sales.activeSales) {
      if (inWindow(sale.dateTime)) {
        count++;
        if (!sale.isCredit) cash += sale.effectiveTotal;
      }
      if (sale.isCredit) {
        for (final payment in sale.payments) {
          if (inWindow(payment.dateTime)) collected += payment.amount;
        }
      }
      // Cash handed back for returns *processed* during this shift, even
      // when the original sale happened earlier.
      if (!sale.isCredit) {
        for (final ret in sale.returns) {
          if (inWindow(ret.dateTime) && !inWindow(sale.dateTime)) {
            returns += sale.returnValue(ret);
          }
        }
      }
    }
    final out = expenses.totalBetween(from, to.add(const Duration(seconds: 1)));
    return ShiftTotals(
      cashSales: cash,
      creditCollected: collected,
      returnsPaidOut: returns,
      paidOut: out,
      invoiceCount: count,
      openingFloat: shift.openingFloat,
    );
  }
}

// ------------------------------------------------------------------ pieces

class _ClosedState extends StatelessWidget {
  final VoidCallback onOpen;
  const _ClosedState({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.scheme.primary.withValues(alpha: 0.10),
            ),
            child: Icon(Icons.point_of_sale_rounded,
                size: 30, color: context.scheme.primary),
          ),
          const SizedBox(height: 14),
          Text(l10n.t('no_open_shift'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(l10n.t('shift_hint'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.mutedColor)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(l10n.t('open_shift')),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenState extends StatelessWidget {
  final Shift shift;
  final ShiftTotals totals;
  final VoidCallback onClose;

  const _OpenState({
    required this.shift,
    required this.totals,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = DateFormat('dd/MM HH:mm');
    final parts = CashChange.breakdown(totals.expectedCash);
    return Column(
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      context.scheme.primary,
                      context.scheme.secondary
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusMd)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_open_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          l10n.t('shift_open_since',
                              {'time': fmt.format(shift.openedAt)}),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        if (shift.openedBy.isNotEmpty)
                          Text(shift.openedBy,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(l10n.t('expected_cash'),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        Money.format(totals.expectedCash),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Line(l10n.t('opening_float'),
                        Money.format(shift.openingFloat), Icons.savings_outlined),
                    _Line(l10n.t('cash_sales'), Money.format(totals.cashSales),
                        Icons.payments_outlined,
                        color: AppTheme.success),
                    _Line(l10n.t('credit_collected'),
                        Money.format(totals.creditCollected),
                        Icons.account_balance_wallet_outlined,
                        color: AppTheme.info),
                    if (totals.returnsPaidOut > 0)
                      _Line(l10n.t('returns_paid_out'),
                          '- ${Money.format(totals.returnsPaidOut)}',
                          Icons.assignment_return_outlined,
                          color: AppTheme.warning),
                    _Line(l10n.t('paid_out'),
                        '- ${Money.format(totals.paidOut)}',
                        Icons.receipt_long_outlined,
                        color: AppTheme.danger),
                    _Line(l10n.t('invoices'), '${totals.invoiceCount}',
                        Icons.description_outlined),
                    if (parts.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(l10n.t('drawer_should_hold'),
                            style: TextStyle(
                                fontSize: 11, color: context.mutedColor)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final part in parts)
                            AppBadge(
                                text:
                                    '${part.count} × ${Money.format(part.value.toDouble())}',
                                color: context.scheme.primary),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.danger),
                        onPressed: onClose,
                        icon: const Icon(Icons.lock_rounded, size: 18),
                        label: Text(l10n.t('close_shift')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _Line(this.label, this.value, this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? context.mutedColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: context.mutedColor)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: color ?? Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final double diff;
  const _DiffChip({required this.diff});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final balanced = diff.abs() < 0.005;
    final color = balanced
        ? AppTheme.success
        : (diff < 0 ? AppTheme.danger : AppTheme.warning);
    final label = balanced
        ? l10n.t('drawer_balanced')
        : '${diff < 0 ? l10n.t('shortage') : l10n.t('surplus')}: ${Money.format(diff.abs())}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppTheme.brSm,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
              balanced
                  ? Icons.check_circle_outline
                  : Icons.error_outline_rounded,
              color: color,
              size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _ReportRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: bold ? null : context.mutedColor,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = DateFormat('dd/MM HH:mm');
    return ValueListenableBuilder<List<Shift>>(
      valueListenable: shiftStore.history,
      builder: (context, shifts, _) {
        if (shifts.isEmpty) {
          return AppCard(
            child: Text(l10n.t('no_shift_history'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.mutedColor)),
          );
        }
        return Column(
          children: [
            for (final shift in shifts.take(12))
              AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${fmt.format(shift.openedAt)} → ${fmt.format(shift.closedAt ?? shift.openedAt)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.t('expected_cash')}: ${Money.format(shift.expectedCash)} · ${l10n.t('invoices')}: ${shift.invoiceCount}',
                            style: TextStyle(
                                fontSize: 11, color: context.mutedColor),
                          ),
                        ],
                      ),
                    ),
                    AppBadge(
                      text: shift.difference.abs() < 0.005
                          ? l10n.t('drawer_balanced')
                          : Money.format(shift.difference.abs()),
                      color: shift.difference.abs() < 0.005
                          ? AppTheme.success
                          : (shift.difference < 0
                              ? AppTheme.danger
                              : AppTheme.warning),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
