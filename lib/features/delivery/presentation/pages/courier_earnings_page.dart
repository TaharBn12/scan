import 'package:flutter/material.dart';

import '../../../../core/cloud/cloud_auth_controller.dart';
import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../data/delivery_repository.dart';
import '../../data/delivery_stats.dart';
import '../widgets/delivery_style.dart';

/// Full-screen earnings for the courier: hero balance, last-7-days chart,
/// day-by-day breakdown and payout history — all from live RTDB rows.
class CourierEarningsPage extends StatefulWidget {
  const CourierEarningsPage({super.key});

  @override
  State<CourierEarningsPage> createState() => _CourierEarningsPageState();
}

class _CourierEarningsPageState extends State<CourierEarningsPage> {
  final _listenables = _EarnListenables();

  String get _uid => cloudAuth.profile?.uid ?? '';

  @override
  void dispose() {
    _listenables.dispose();
    super.dispose();
  }

  String _dayLabel(BuildContext context, DateTime d) {
    final l10n = context.l10n;
    final today = DeliveryStats.startOfToday();
    if (d == today) return l10n.t('earnings_today');
    if (d == today.subtract(const Duration(days: 1))) {
      return l10n.t('yesterday');
    }
    // weekday names are in the base tables
    const keys = [
      'weekday_mon', 'weekday_tue', 'weekday_wed', 'weekday_thu',
      'weekday_fri', 'weekday_sat', 'weekday_sun',
    ];
    return l10n.t(keys[d.weekday - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: ListenableBuilder(
        listenable: _listenables,
        builder: (context, _) {
          final balance = DeliveryRepository.balanceOf(_uid);
          final series =
              DeliveryStats.dailySeries(days: 7, delivererId: _uid);
          final weekTotal =
              series.fold<double>(0, (s, e) => s + e.fees);
          final weekCount = series.fold<int>(0, (s, e) => s + e.count);
          final payouts = DeliveryRepository.payoutsFor(_uid);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    DeliveryHeroHeader(
                      title: l10n.t('courier_earnings'),
                      subtitle: l10n.t('earnings_hint'),
                      icon: Icons.payments_rounded,
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(l10n.t('earnings_balance'),
                              style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.85),
                                  fontSize: 11)),
                          Text(Money.format(balance),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: IconButton(
                          icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 19,
                              color: Colors.white),
                          onPressed: () =>
                              Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Week summary row
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: Icons.date_range_rounded,
                            label: l10n.t('earnings_week'),
                            value: Money.format(weekTotal),
                            color: DeliveryPalette.teal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            icon: Icons.motorcycle_rounded,
                            label: l10n.t('delivery_status_delivered'),
                            value: '$weekCount',
                            color: context.scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${l10n.t('earnings_week')} · ${l10n.t('delivery_fee')}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          MiniBarChart(
                            values: [for (final s in series) s.fees],
                            labels: [
                              for (final s in series) _dayLabel(context, s.day)
                            ],
                            color: DeliveryPalette.teal,
                            height: 120,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionHeader(title: l10n.t('per_day')),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Column(
                        children: [
                          for (var i = series.length - 1; i >= 0; i--)
                            _dayRow(context, series[i]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionHeader(title: l10n.t('payout_history')),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: payouts.isEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: Text(l10n.t('no_payouts_yet'),
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: context.mutedColor)),
                            )
                          : Column(
                              children: [
                                for (final p in payouts.take(12))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.handshake_outlined,
                                            size: 17,
                                            color: AppTheme.info),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  '${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}',
                                                  style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              if (p.createdByName
                                                  .isNotEmpty)
                                                Text(p.createdByName,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: context
                                                            .mutedColor)),
                                            ],
                                          ),
                                        ),
                                        Text(Money.format(p.amount),
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w800)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dayRow(
      BuildContext context, ({DateTime day, double fees, int count}) s) {
    final l10n = context.l10n;
    final isToday = s.day == DeliveryStats.startOfToday();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isToday ? DeliveryPalette.teal : context.mutedColor)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
                isToday
                    ? Icons.today_rounded
                    : Icons.calendar_today_outlined,
                size: 17,
                color: isToday
                    ? DeliveryPalette.teal
                    : context.mutedColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dayLabel(context, s.day),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Text(
                    '${l10n.t('delivery_status_delivered')}: ${s.count}',
                    style: TextStyle(
                        fontSize: 11, color: context.mutedColor)),
              ],
            ),
          ),
          Text(Money.format(s.fees),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: s.fees > 0 ? null : context.mutedColor)),
        ],
      ),
    );
  }
}

class _EarnListenables extends ChangeNotifier {
  _EarnListenables() {
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
