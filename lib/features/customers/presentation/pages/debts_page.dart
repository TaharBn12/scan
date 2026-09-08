import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../shop/data/repositories/shop_repository_impl.dart';
import '../../domain/entities/customer.dart';
import '../bloc/customer_bloc.dart';

/// Debt follow-up: who owes what, for how long, and a one-tap polite
/// reminder written for you and opened straight in WhatsApp.
///
/// Small shops lose real money because nobody wants to make the awkward
/// call. This turns it into a two-second, ready-worded tap.
class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

enum _DebtSort { oldest, amount, name }

class _DebtsPageState extends State<DebtsPage> {
  _DebtSort _sort = _DebtSort.oldest;

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
        title: Text(l10n.t('debt_followup')),
        actions: [
          PopupMenuButton<_DebtSort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: l10n.t('sort_by'),
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: _DebtSort.oldest,
                  child: Text(l10n.t('sort_oldest_debt'))),
              PopupMenuItem(
                  value: _DebtSort.amount, child: Text(l10n.t('sort_amount'))),
              PopupMenuItem(
                  value: _DebtSort.name, child: Text(l10n.t('sort_name'))),
            ],
          ),
        ],
      ),
      body: BlocBuilder<SaleBloc, SaleState>(
        builder: (context, saleState) {
          return BlocBuilder<CustomerBloc, CustomerState>(
            builder: (context, customerState) {
              final debts = _buildDebts(saleState, customerState.customers);
              if (debts.isEmpty) {
                return EmptyState(
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  title: l10n.t('no_outstanding_credit'),
                  message: l10n.t('debt_followup_hint'),
                );
              }
              final total = debts.fold<double>(0, (sum, d) => sum + d.due);
              final late = debts.where((d) => d.daysLate >= 30).length;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: AppCard(
                      elevated: false,
                      color: AppTheme.warning.withValues(alpha: 0.10),
                      borderColor: AppTheme.warning.withValues(alpha: 0.28),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.t('total_outstanding'),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.mutedColor)),
                                const SizedBox(height: 2),
                                Text(Money.format(total),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            color: AppTheme.warning,
                                            fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(
                                  '${l10n.t('debtors_count', {'count': debts.length})}'
                                  '${late > 0 ? ' · ${l10n.t('late_over_month', {'count': late})}' : ''}',
                                  style: TextStyle(
                                      fontSize: 11, color: context.mutedColor),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _shareAll(context, debts),
                            icon: const Icon(Icons.ios_share, size: 17),
                            label: Text(l10n.t('share_list')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                      itemCount: debts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _DebtTile(
                        debt: debts[index],
                        onRemind: () => _remind(context, debts[index]),
                        onOpen: () {
                          final customer = debts[index].customer;
                          if (customer != null) {
                            context.push('/customers/detail/${customer.id}',
                                extra: customer);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------- data

  List<_Debt> _buildDebts(SaleState state, List<Customer> customers) {
    final byId = {for (final c in customers) c.id: c};
    final map = <String, _Debt>{};
    for (final sale in state.unpaidCreditSales) {
      final key = sale.customerId ?? 'walkin:${sale.customerName ?? ''}';
      final existing = map[key];
      if (existing == null) {
        map[key] = _Debt(
          customer: sale.customerId == null ? null : byId[sale.customerId],
          name: sale.customerName ?? '',
          phone: sale.customerPhone ?? byId[sale.customerId]?.phone ?? '',
          due: sale.amountDue,
          oldest: sale.dateTime,
          latest: sale.dateTime,
          invoices: [sale],
        );
      } else {
        existing.due += sale.amountDue;
        existing.invoices.add(sale);
        if (sale.dateTime.isBefore(existing.oldest)) {
          existing.oldest = sale.dateTime;
        }
        if (sale.dateTime.isAfter(existing.latest)) {
          existing.latest = sale.dateTime;
        }
      }
    }
    final list = map.values.where((d) => d.due > 0.005).toList();
    switch (_sort) {
      case _DebtSort.oldest:
        list.sort((a, b) => a.oldest.compareTo(b.oldest));
        break;
      case _DebtSort.amount:
        list.sort((a, b) => b.due.compareTo(a.due));
        break;
      case _DebtSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
    return list;
  }

  // ------------------------------------------------------------ reminders

  String _reminderText(BuildContext context, _Debt debt) {
    final l10n = context.l10n;
    final shop = ShopRepositoryImpl.current();
    final fmt = DateFormat('dd/MM/yyyy');
    final shopName = shop.name.isEmpty ? l10n.t('your_shop') : shop.name;
    final last = debt.invoices.reduce(
        (a, b) => a.dateTime.isAfter(b.dateTime) ? a : b);
    return [
      l10n.t('reminder_greeting', {'name': debt.name.isEmpty ? '' : debt.name}),
      l10n.t('reminder_body', {
        'shop': shopName,
        'amount': Money.format(debt.due),
      }),
      l10n.t('reminder_last_invoice', {
        'number': '${last.number}',
        'date': fmt.format(last.dateTime),
      }),
      l10n.t('reminder_thanks'),
    ].join('\n');
  }

  Future<void> _remind(BuildContext context, _Debt debt) async {
    final l10n = context.l10n;
    final text = _reminderText(context, debt);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(l10n.t('send_reminder'),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                elevated: false,
                color: context.surfaceAltColor,
                child: Text(text,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
            const SizedBox(height: 8),
            if (debt.phone.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.chat, color: AppTheme.success),
                title: Text(l10n.t('whatsapp')),
                subtitle: Text(debt.phone),
                onTap: () => Navigator.pop(sheet, 'wa'),
              ),
            if (debt.phone.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: Text(l10n.t('sms')),
                onTap: () => Navigator.pop(sheet, 'sms'),
              ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.t('share_text')),
              onTap: () => Navigator.pop(sheet, 'share'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'wa':
        await _launch(context, _whatsappUri(debt.phone, text));
        break;
      case 'sms':
        await _launch(
            context,
            Uri.parse(
                'sms:${debt.phone}?body=${Uri.encodeComponent(text)}'));
        break;
      case 'share':
        await SharePlus.instance
            .share(ShareParams(text: text, subject: l10n.t('send_reminder')));
        break;
    }
  }

  /// Algerian local numbers (0X…) are converted to +213 for wa.me.
  static Uri _whatsappUri(String phone, String text) {
    var digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('00')) digits = '+${digits.substring(2)}';
    if (digits.startsWith('0')) digits = '+213${digits.substring(1)}';
    digits = digits.replaceAll('+', '');
    return Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        showAppSnack(context, context.l10n.error,
            icon: Icons.error_outline);
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, context.l10n.error, icon: Icons.error_outline);
      }
    }
  }

  Future<void> _shareAll(BuildContext context, List<_Debt> debts) async {
    final l10n = context.l10n;
    final fmt = DateFormat('dd/MM/yyyy');
    final shop = ShopRepositoryImpl.current();
    final total = debts.fold<double>(0, (sum, d) => sum + d.due);
    final lines = [
      '${l10n.t('debt_followup')} · ${shop.name.isEmpty ? l10n.t('your_shop') : shop.name}',
      fmt.format(DateTime.now()),
      '-' * 24,
      for (final debt in debts)
        '• ${debt.name.isEmpty ? l10n.t('customer') : debt.name}: '
            '${Money.format(debt.due)} '
            '(${l10n.t('days_late', {'days': debt.daysLate})})',
      '-' * 24,
      '${l10n.t('total_outstanding')}: ${Money.format(total)}',
    ];
    await SharePlus.instance.share(ShareParams(
        text: lines.join('\n'), subject: l10n.t('debt_followup')));
  }
}

class _Debt {
  final Customer? customer;
  final String name;
  final String phone;
  double due;
  DateTime oldest;
  DateTime latest;
  final List<Sale> invoices;

  _Debt({
    required this.customer,
    required this.name,
    required this.phone,
    required this.due,
    required this.oldest,
    required this.latest,
    required this.invoices,
  });

  int get daysLate => DateTime.now().difference(oldest).inDays;
}

class _DebtTile extends StatelessWidget {
  final _Debt debt;
  final VoidCallback onRemind;
  final VoidCallback onOpen;

  const _DebtTile({
    required this.debt,
    required this.onRemind,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = debt.daysLate;
    final color = days >= 60
        ? AppTheme.danger
        : (days >= 30 ? AppTheme.warning : AppTheme.info);

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Text(
                  debt.name.isEmpty ? '?' : debt.name.characters.first,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.name.isEmpty ? l10n.t('customer') : debt.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        AppBadge(
                          text: l10n.t('days_late', {'days': days}),
                          color: color,
                          icon: Icons.schedule_rounded,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.t('invoices_count',
                                {'count': debt.invoices.length}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: context.mutedColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Money.format(debt.due),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w800)),
                  if (debt.phone.isNotEmpty)
                    Text(debt.phone,
                        style: TextStyle(
                            fontSize: 10.5, color: context.mutedColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onRemind,
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: Text(l10n.t('send_reminder')),
            ),
          ),
        ],
      ),
    );
  }
}
