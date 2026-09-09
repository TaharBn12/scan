import 'package:flutter/material.dart';

import '../../../../core/cloud/cloud_auth_controller.dart';
import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/cloud/firebase_layer.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../data/delivery_repository.dart';
import '../../data/delivery_stats.dart';
import '../widgets/courier_earnings_sheet.dart';
import '../widgets/delivery_style.dart';

/// The admin's courier roster: who's on duty *right now*, how much each one
/// delivered and earned, block/unblock, duty override, settle payouts —
/// every number written & read live from Realtime Database.
class DeliverersPage extends StatefulWidget {
  const DeliverersPage({super.key});

  @override
  State<DeliverersPage> createState() => _DeliverersPageState();
}

class _DeliverersPageState extends State<DeliverersPage> {
  final _listenables = _RosterListenables();

  String get _shopId => cloudAuth.shopId ?? '';

  @override
  void dispose() {
    _listenables.dispose();
    super.dispose();
  }

  List<MapEntry<String, Map<String, dynamic>>> _couriers() {
    final box = CloudDatabase.usersBox;
    final list = <MapEntry<String, Map<String, dynamic>>>[];
    for (final uid in box.keys) {
      final m = Map<String, dynamic>.from(box.get(uid) ?? const {});
      if (m['role'] != 'deliverer') continue;
      list.add(MapEntry(uid, m));
    }
    list.sort((a, b) {
      final da = a.value['onDuty'] == true ? 0 : 1;
      final db = b.value['onDuty'] == true ? 0 : 1;
      if (da != db) return da - db;
      return (a.value['name'] as String? ?? '')
          .compareTo(b.value['name'] as String? ?? '');
    });
    return list;
  }

  String _nameOf(MapEntry<String, Map<String, dynamic>> e) =>
      (e.value['name'] as String?)?.isNotEmpty == true
          ? e.value['name'] as String
          : (e.value['email'] as String? ?? e.key);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: ListenableBuilder(
        listenable: _listenables,
        builder: (context, _) {
          final couriers = _couriers();
          final onDuty =
              couriers.where((c) => c.value['onDuty'] == true).length;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    DeliveryHeroHeader(
                      title: l10n.t('couriers'),
                      subtitle: l10n.t('couriers_subtitle'),
                      icon: Icons.groups_2_rounded,
                      trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text('$onDuty/${couriers.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        Text(l10n.t('member_duty_on'),
                            style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.85),
                                fontSize: 10.5)),
                      ],
                    ),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: couriers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: EmptyState(
                            icon: Icons.delivery_dining_outlined,
                            title: l10n.t('no_deliverers_yet'),
                            message: l10n.t('no_deliverers_hint'),
                          ),
                        )
                      : Column(
                          children: [
                            for (final c in couriers) _courierCard(c),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _courierCard(MapEntry<String, Map<String, dynamic>> entry) {
    final l10n = context.l10n;
    final m = entry.value;
    final uid = entry.key;
    final name = _nameOf(entry);
    final blocked = m['blocked'] == true;
    final inactive = m['active'] == false && !blocked;
    final onDuty = m['onDuty'] == true;
    final isMe = cloudAuth.profile?.uid == uid;

    final tasks = DeliveryRepository.all()
        .where((d) => d.delivererId == uid && d.status.isOpen)
        .length;
    final delivered = DeliveryRepository.deliveredCountOf(uid);
    final balance = DeliveryRepository.balanceOf(uid);

    // last position age
    String lastSeen = '—';
    final loc = m['location'];
    if (loc is Map) {
      final at = (loc['at'] as num?)?.toInt();
      if (at != null) {
        final mins = DateTime.now()
            .difference(
                DateTime.fromMillisecondsSinceEpoch(at))
            .inMinutes;
        lastSeen = mins < 60
            ? l10n.t('delivery_age_m', {'n': '$mins'})
            : l10n.t('delivery_age_h', {'n': '${mins ~/ 60}'});
      }
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: (onDuty ? AppTheme.success : context.mutedColor)
                    .withValues(alpha: 0.15),
                child: Icon(Icons.delivery_dining_rounded,
                    color: onDuty ? AppTheme.success : context.mutedColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.t('deliverer_last_seen')}: $lastSeen',
                      style:
                          TextStyle(fontSize: 11.5, color: context.mutedColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppBadge(
                    text: blocked
                        ? l10n.t('member_blocked')
                        : onDuty
                            ? l10n.t('member_duty_on')
                            : l10n.t('off_duty'),
                    color: blocked
                        ? AppTheme.danger
                        : onDuty
                            ? AppTheme.success
                            : context.mutedColor,
                  ),
                  if (inactive)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: AppBadge(
                          text: l10n.t('delivery_status_pending'),
                          color: AppTheme.warning),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: context.scheme.surfaceContainerHighest
                  .withValues(alpha: 0.45),
              borderRadius: AppTheme.brMd,
            ),
            child: Row(
              children: [
                _miniStat(
                    Icons.motorcycle_rounded,
                    l10n.t('tasks_open'),
                    '$tasks',
                    context.scheme.primary),
                _miniStat(
                    Icons.check_circle_outline_rounded,
                    l10n.t('delivery_status_delivered'),
                    '$delivered',
                    DeliveryPalette.teal),
                _miniStat(
                    Icons.account_balance_wallet_outlined,
                    l10n.t('earnings_balance'),
                    Money.format(balance),
                    AppTheme.success),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => showCourierEarningsSheet(context,
                    uid: uid,
                    name: name,
                    settledBy: cloudAuth.profile?.name ?? ''),
                icon: Icon(Icons.payments_outlined,
                    size: 17, color: AppTheme.success),
                label: Text(l10n.t('courier_earnings'),
                    style:
                        TextStyle(color: AppTheme.success, fontSize: 12.5)),
              ),
              const Spacer(),
              if (!blocked) ...[
                FilterChip(
                  selected: onDuty,
                  showCheckmark: false,
                  avatar: Icon(Icons.circle,
                      size: 9,
                      color: onDuty
                          ? AppTheme.success
                          : context.mutedColor),
                  label: Text(l10n.t('member_duty_on'),
                      style: const TextStyle(fontSize: 12)),
                  onSelected: isMe
                      ? null
                      : (v) => FirebaseLayer.setDuty(_shopId, uid, v),
                ),
                const SizedBox(width: 6),
              ],
              if (!isMe)
                IconButton(
                  tooltip: blocked
                      ? l10n.t('unblock_member')
                      : l10n.t('block_member'),
                  onPressed: () async {
                    await FirebaseLayer.setMemberBlocked(
                        _shopId, uid, !blocked);
                    if (!mounted) return;
                    showAppSnack(
                      context,
                      blocked
                          ? l10n.t('unblocked_toast')
                          : l10n.t('blocked_toast'),
                      icon: blocked
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                      color: blocked ? AppTheme.success : AppTheme.warning,
                    );
                  },
                  icon: Icon(
                      blocked
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                      size: 19,
                      color: blocked ? AppTheme.success : null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13.5)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: context.mutedColor)),
        ],
      ),
    );
  }
}

class _RosterListenables extends ChangeNotifier {
  _RosterListenables() {
    CloudDatabase.usersBox.addListener(_ping);
    CloudDatabase.deliveriesBox.addListener(_ping);
    CloudDatabase.deliveryPayoutsBox.addListener(_ping);
  }

  void _ping() => notifyListeners();

  @override
  void dispose() {
    CloudDatabase.usersBox.removeListener(_ping);
    CloudDatabase.deliveriesBox.removeListener(_ping);
    CloudDatabase.deliveryPayoutsBox.removeListener(_ping);
    super.dispose();
  }
}
