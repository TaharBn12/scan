import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/cloud/cloud_auth_controller.dart';
import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/cloud/firebase_layer.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../data/delivery_repository.dart';
import '../../data/location_reporter.dart';
import '../../domain/entities/delivery.dart';

/// The deliverer's home: duty switch, the orders assigned to him (live),
/// and his earnings. Everything reads/writes Realtime Database — status
/// changes appear on the admin's board the same second.
class CourierHomePage extends StatefulWidget {
  const CourierHomePage({super.key});

  @override
  State<CourierHomePage> createState() => _CourierHomePageState();
}

class _CourierHomePageState extends State<CourierHomePage> {
  final _listenables = _CourierListenables();
  bool _switching = false;

  @override
  void dispose() {
    _listenables.dispose();
    super.dispose();
  }

  String get _uid => cloudAuth.profile?.uid ?? '';
  String get _shopId => cloudAuth.shopId ?? '';

  Map<String, dynamic> get _me =>
      Map<String, dynamic>.from(CloudDatabase.usersBox.get(_uid) ?? const {});

  bool get _onDuty => _me['onDuty'] == true;

  @override
  void initState() {
    super.initState();
    // If the courier was on duty, keep reporting his position after a
    // cold start of the app too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_onDuty && _uid.isNotEmpty && _shopId.isNotEmpty) {
        LocationReporter.start(_shopId, _uid);
      }
    });
  }

  Future<void> _toggleDuty(bool wantOn) async {
    if (_switching || _uid.isEmpty) return;
    setState(() => _switching = true);
    final l10n = context.l10n;
    if (wantOn) {
      final problem = await LocationReporter.ensureUsable();
      if (problem != null) {
        setState(() => _switching = false);
        if (mounted) {
          showAppSnack(context, l10n.t(problem),
              icon: Icons.location_off_rounded, color: AppTheme.warning);
        }
        return;
      }
      await LocationReporter.start(_shopId, _uid);
      await FirebaseLayer.setDuty(_shopId, _uid, true);
    } else {
      LocationReporter.stop();
      await FirebaseLayer.setDuty(_shopId, _uid, false);
    }
    if (mounted) setState(() => _switching = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('courier_home')),
        actions: [
          IconButton(
            tooltip: l10n.t('delivery_map_title'),
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push('/courier/map'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _listenables,
        builder: (context, _) {
          final mine = DeliveryRepository.forDeliverer(_uid);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _dutyCard(),
              const SizedBox(height: 14),
              _earningsCard(),
              const SizedBox(height: 18),
              SectionHeader(
                  title: '${l10n.t('my_deliveries')} · ${mine.length}'),
              if (mine.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: EmptyState(
                    icon: Icons.delivery_dining_outlined,
                    title: l10n.t('no_courier_tasks'),
                    message: l10n.t('duty_hint'),
                  ),
                )
              else
                for (final d in mine) _taskCard(d),
              const SizedBox(height: 18),
              _payoutsCard(),
            ],
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------- cards

  Widget _dutyCard() {
    final l10n = context.l10n;
    final on = _onDuty;
    return AppCard(
      color: on
          ? AppTheme.success.withValues(alpha: 0.12)
          : context.scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (on ? AppTheme.success : context.mutedColor)
                  .withValues(alpha: 0.18),
            ),
            child: Icon(
              on ? Icons.online_prediction_rounded : Icons.bedtime_outlined,
              color: on ? AppTheme.success : context.mutedColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(on ? l10n.t('on_duty') : l10n.t('off_duty'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                Text(l10n.t('duty_hint'),
                    style: TextStyle(fontSize: 11.5, color: context.mutedColor),
                    maxLines: 2),
              ],
            ),
          ),
          Switch(
            value: on,
            onChanged: _switching ? null : _toggleDuty,
          ),
        ],
      ),
    );
  }

  Widget _earningsCard() {
    final l10n = context.l10n;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final weekStart = dayStart.subtract(Duration(days: now.weekday - 1));
    final today = DeliveryRepository.earnedBetween(_uid, dayStart,
        dayStart.add(const Duration(days: 1)));
    final week = DeliveryRepository.earnedBetween(
        _uid, weekStart, dayStart.add(const Duration(days: 1)));
    final balance = DeliveryRepository.balanceOf(_uid);
    final count = DeliveryRepository.deliveredCountOf(_uid);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, color: context.scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.t('courier_earnings'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              AppBadge(
                text: '${l10n.t('delivery_status_delivered')}: $count',
                color: AppTheme.info,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _earningTile(l10n.t('earnings_today'), today),
              _earningTile(l10n.t('earnings_week'), week),
              _earningTile(l10n.t('earnings_balance'), balance,
                  highlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _earningTile(String label, double value, {bool highlight = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: context.mutedColor),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            Money.format(value),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: highlight ? AppTheme.success : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _taskCard(Delivery d) {
    final l10n = context.l10n;
    final color = d.status == DeliveryStatus.pickedUp
        ? AppTheme.info
        : context.scheme.primary;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/courier/detail', extra: d.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${d.number}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: context.mutedColor)),
              const SizedBox(width: 8),
              AppBadge(
                text: l10n.t(d.status.labelKey),
                color: color,
                icon: d.status == DeliveryStatus.pickedUp
                    ? Icons.delivery_dining_rounded
                    : Icons.assignment_ind_outlined,
              ),
              const Spacer(),
              if (d.paymentOnDelivery)
                AppBadge(
                  text:
                      '${l10n.t('courier_cod_collect')} ${Money.format(d.saleTotal)}',
                  color: AppTheme.warning,
                  icon: Icons.payments_outlined,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(d.customerName.isEmpty ? '—' : d.customerName,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_outlined, size: 15, color: context.mutedColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(d.address,
                    style: TextStyle(fontSize: 12.5, color: context.mutedColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              if (d.customerPhone.isNotEmpty)
                IconButton(
                  tooltip: l10n.t('call_customer'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      launchUrl(Uri(scheme: 'tel', path: d.customerPhone)),
                  icon: Icon(Icons.call_rounded,
                      size: 20, color: context.scheme.primary),
                ),
            ],
          ),
          if (d.itemsSummary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(d.itemsSummary,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${l10n.t('delivery_fee')}: ${Money.format(d.fee)}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success)),
              const Spacer(),
              Icon(Icons.chevron_left_rounded, color: context.mutedColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _payoutsCard() {
    final l10n = context.l10n;
    final payouts = DeliveryRepository.payoutsFor(_uid);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: context.scheme.primary),
              const SizedBox(width: 8),
              Text(l10n.t('payout_history'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          if (payouts.isEmpty)
            Text(l10n.t('no_payouts_yet'),
                style: TextStyle(fontSize: 12, color: context.mutedColor))
          else
            for (final p in payouts.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}'
                          '${p.createdByName.isEmpty ? '' : ' · ${p.createdByName}'}',
                          style: TextStyle(
                              fontSize: 12, color: context.mutedColor)),
                    ),
                    Text(Money.format(p.amount),
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Rebuilds the courier home when orders *or* his own member row change.
class _CourierListenables extends ChangeNotifier {
  _CourierListenables() {
    CloudDatabase.deliveriesBox.addListener(_ping);
    CloudDatabase.deliveryPayoutsBox.addListener(_ping);
    CloudDatabase.usersBox.addListener(_ping);
  }

  void _ping() => notifyListeners();

  @override
  void dispose() {
    CloudDatabase.deliveriesBox.removeListener(_ping);
    CloudDatabase.deliveryPayoutsBox.removeListener(_ping);
    CloudDatabase.usersBox.removeListener(_ping);
    super.dispose();
  }
}
