import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/cloud/cloud_auth_controller.dart';
import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../data/delivery_repository.dart';
import '../../data/delivery_stats.dart';
import '../../domain/entities/delivery.dart';
import '../widgets/delivery_style.dart';

/// The courier's finished work, grouped by day: what he delivered, what
/// failed — tap any row to reopen its detail.
class CourierHistoryPage extends StatefulWidget {
  const CourierHistoryPage({super.key});

  @override
  State<CourierHistoryPage> createState() => _CourierHistoryPageState();
}

class _CourierHistoryPageState extends State<CourierHistoryPage> {
  String get _uid => cloudAuth.profile?.uid ?? '';

  String _dayLabel(BuildContext context, DateTime d) {
    final l10n = context.l10n;
    final today = DeliveryStats.startOfToday();
    if (d == today) return l10n.t('today');
    if (d == today.subtract(const Duration(days: 1))) {
      return l10n.t('yesterday');
    }
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('history_title'))),
      body: ListenableBuilder(
        listenable: CloudDatabase.deliveriesBox,
        builder: (context, _) {
          final mine = DeliveryRepository.all()
              .where((d) => d.delivererId == _uid && !d.status.isOpen)
              .toList();
          if (mine.isEmpty) {
            return EmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: l10n.t('no_history_yet'),
              message: l10n.t('duty_hint'),
            );
          }
          // group by day
          final groups = <DateTime, List<Delivery>>{};
          for (final d in mine) {
            final at = d.deliveredAt ?? d.closedAt ?? d.createdAt;
            final day = DateTime(at.year, at.month, at.day);
            groups.putIfAbsent(day, () => []).add(d);
          }
          final days = groups.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final day in days) ...[
                SectionHeader(
                    title:
                        '${_dayLabel(context, day)} · ${groups[day]!.length}'),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: Column(
                    children: [
                      for (final d in groups[day]!) _historyRow(d),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _historyRow(Delivery d) {
    final l10n = context.l10n;
    final color = DeliveryPalette.statusStyle(d.status, context.scheme);
    return InkWell(
      onTap: () => context.push('/courier/detail', extra: d.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(DeliveryPalette.statusIcon(d.status),
                  size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('#${d.number}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12.5)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            d.customerName.isEmpty
                                ? '—'
                                : d.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                  Text(d.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: context.mutedColor)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppBadge(
                  text: l10n.t(d.status.labelKey),
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                    '${l10n.t('delivery_fee')}: ${Money.format(d.fee)}',
                    style: TextStyle(
                        fontSize: 10.5, color: context.mutedColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
