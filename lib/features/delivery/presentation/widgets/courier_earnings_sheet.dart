import 'package:flutter/material.dart';

import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../data/delivery_repository.dart';
import '../../data/delivery_stats.dart';
import 'delivery_style.dart';

/// Admin-facing courier earnings sheet: totals, last-7-days chart, settle
/// payout. Shared by the team page and the deliverers board.
Future<void> showCourierEarningsSheet(
  BuildContext context, {
  required String uid,
  required String name,
  required String settledBy,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => _CourierEarningsSheet(
        uid: uid, name: name, settledBy: settledBy),
  );
}

class _CourierEarningsSheet extends StatefulWidget {
  final String uid;
  final String name;
  final String settledBy;

  const _CourierEarningsSheet(
      {required this.uid, required this.name, required this.settledBy});

  @override
  State<_CourierEarningsSheet> createState() =>
      _CourierEarningsSheetState();
}

class _CourierEarningsSheetState extends State<_CourierEarningsSheet> {
  final _amountCtrl = TextEditingController();
  final _listenables = _SheetListenables();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _listenables.dispose();
    super.dispose();
  }

  String _dayName(BuildContext context, DateTime d) {
    final l10n = context.l10n;
    final today = DeliveryStats.startOfToday();
    if (d == today) return l10n.t('earnings_today');
    if (d == today.subtract(const Duration(days: 1))) {
      return l10n.t('yesterday');
    }
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _listenables,
      builder: (context, _) {
        final earned = DeliveryRepository.earnedBy(widget.uid);
        final paid = DeliveryRepository.paidOutTo(widget.uid);
        final balance = DeliveryRepository.balanceOf(widget.uid);
        final count = DeliveryRepository.deliveredCountOf(widget.uid);
        final series = DeliveryStats.dailySeries(days: 7, delivererId: widget.uid);

        return Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.name} — ${l10n.t('courier_earnings')}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.motorcycle_rounded,
                        label: l10n.t('delivery_status_delivered'),
                        value: '$count',
                        color: context.scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        icon: Icons.payments_rounded,
                        label: l10n.t('courier_earnings'),
                        value: Money.format(earned),
                        color: AppTheme.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: l10n.t('earnings_balance'),
                        value: Money.format(balance),
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l10n.t('earnings_week')} — ${l10n.t('delivery_fee')}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      MiniBarChart(
                        values: [for (final s in series) s.fees],
                        labels: [
                          for (final s in series)
                            _dayName(context, s.day)
                        ],
                        color: DeliveryPalette.teal,
                        height: 110,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (balance > 0) ...[
                  Text(l10n.t('settle_payout'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.t('payout_amount'),
                            hintText: Money.plain(balance),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () async {
                          final amount = double.tryParse(_amountCtrl.text
                                  .trim()
                                  .replaceAll(',', '.')) ??
                              0;
                          if (amount <= 0) return;
                          await DeliveryRepository.settle(
                              widget.uid, widget.name, amount,
                              widget.settledBy);
                          if (!context.mounted) return;
                          showAppSnack(context, l10n.t('payout_recorded'),
                              icon: Icons.check_circle_outline_rounded,
                              color: AppTheme.success);
                          Navigator.of(context).pop();
                        },
                        child: Text(l10n.t('settle_payout')),
                      ),
                    ],
                  ),
                ] else
                  Text(l10n.t('no_payouts_yet'),
                      style:
                          TextStyle(fontSize: 12.5, color: context.mutedColor)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SheetListenables extends ChangeNotifier {
  _SheetListenables() {
    CloudDatabase.deliveriesBox.addListener(_ping);
    CloudDatabase.deliveryPayoutsBox.addListener(_ping);
  }

  void _ping() => notifyListeners();

  @override
  void dispose() {
    CloudDatabase.deliveriesBox.removeListener(_ping);
    CloudDatabase.deliveryPayoutsBox.removeListener(_ping);
    super.dispose();
  }
}
