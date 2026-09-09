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
import '../../data/delivery_stats.dart';
import '../../data/location_reporter.dart';
import '../../domain/entities/delivery.dart';
import '../widgets/delivery_style.dart';

/// The courier's world-class home: gradient hero with greeting, floating
/// duty switch, live stats, his assigned orders and entries to earnings &
/// history. Everything is a live mirror of Realtime Database.
class CourierHomePage extends StatefulWidget {
  const CourierHomePage({super.key});

  @override
  State<CourierHomePage> createState() => _CourierHomePageState();
}

class _CourierHomePageState extends State<CourierHomePage> {
  final _listenables = _CourierListenables();
  bool _switching = false;
  bool _dutySyncGuard = false;

  String get _uid => cloudAuth.profile?.uid ?? '';
  String get _shopId => cloudAuth.shopId ?? '';

  Map<String, dynamic> get _me =>
      Map<String, dynamic>.from(CloudDatabase.usersBox.get(_uid) ?? const {});

  bool get _onDuty => _me['onDuty'] == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_onDuty && _uid.isNotEmpty && _shopId.isNotEmpty) {
        LocationReporter.start(_shopId, _uid);
      }
    });
  }

  @override
  void dispose() {
    _listenables.dispose();
    super.dispose();
  }

  /// If an admin flips the duty flag off remotely, the reporting loop on
  /// this device must stop too (and vice-versa).
  void _syncReporterWithDuty() {
    if (_dutySyncGuard) return;
    _dutySyncGuard = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dutySyncGuard = false;
      if (!mounted) return;
      if (_onDuty && !LocationReporter.running && _uid.isNotEmpty) {
        LocationReporter.start(_shopId, _uid);
      } else if (!_onDuty && LocationReporter.running) {
        LocationReporter.stop();
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
    _syncReporterWithDuty();

    return Scaffold(
      body: ListenableBuilder(
        listenable: _listenables,
        builder: (context, _) {
          final mine = DeliveryRepository.forDeliverer(_uid);
          final todayFees = DeliveryStats.dailySeries(days: 1, delivererId: _uid)
              .fold<double>(0, (s, e) => s + e.fees);
          final balance = DeliveryRepository.balanceOf(_uid);
          final name = (cloudAuth.profile?.name ?? '').trim();

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── hero: greeting + duty switch floating card ──────────
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DeliveryHeroHeader(
                        title: name.isEmpty
                            ? l10n.t('courier_home')
                            : l10n.t('hello_name', {'name': name}),
                        subtitle: l10n.t('duty_hint'),
                        icon: Icons.delivery_dining_rounded,
                        trailing: IconButton(
                          tooltip: l10n.t('history_title'),
                          onPressed: () => context.push('/courier/map'),
                          icon: const Icon(Icons.map_outlined,
                              color: Colors.white),
                        ),
                      ),
                      Positioned.directional(
                        textDirection: Directionality.of(context),
                        start: 16,
                        end: 16,
                        bottom: 2,
                        child: _dutySwitchCard(),
                      ),
                    ],
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── live stats ────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              icon: Icons.motorcycle_rounded,
                              label: l10n.t('tasks_open'),
                              value: '${mine.length}',
                              color: context.scheme.primary,
                              onTap: mine.isEmpty
                                  ? null
                                  : () => context.push('/courier/map'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: StatTile(
                              icon: Icons.payments_rounded,
                              label: l10n.t('fees_today'),
                              value: Money.format(todayFees),
                              color: DeliveryPalette.teal,
                              onTap: () => context.push('/courier/earnings'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: StatTile(
                              icon: Icons.account_balance_wallet_outlined,
                              label: l10n.t('earnings_balance'),
                              value: Money.format(balance),
                              color: AppTheme.success,
                              onTap: () => context.push('/courier/earnings'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _entryCard(
                              icon: Icons.bar_chart_rounded,
                              label: l10n.t('courier_earnings'),
                              color: DeliveryPalette.teal,
                              onTap: () =>
                                  context.push('/courier/earnings'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _entryCard(
                              icon: Icons.history_rounded,
                              label: l10n.t('history_title'),
                              color: const Color(0xFF64748B),
                              onTap: () =>
                                  context.push('/courier/history'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── tasks ─────────────────────────────────────────
                      SectionHeader(
                          title:
                              '${l10n.t('your_tasks_today')} · ${mine.length}'),
                      if (mine.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: EmptyState(
                            icon: Icons.delivery_dining_outlined,
                            title: l10n.t('no_courier_tasks'),
                            message: _onDuty
                                ? l10n.t('menu_deliveries_subtitle')
                                : l10n.t('duty_hint'),
                          ),
                        )
                      else
                        for (final d in mine) _taskCard(d),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- cards

  Widget _dutySwitchCard() {
    final l10n = context.l10n;
    final on = _onDuty;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: context.scheme.surface,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (on ? AppTheme.success : context.mutedColor)
                  .withValues(alpha: 0.15),
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
                        fontSize: 15.5, fontWeight: FontWeight.w800)),
                Text(
                    on
                        ? l10n.t('member_duty_on')
                        : l10n.t('duty_error_location'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.mutedColor)),
              ],
            ),
          ),
          Switch(
            value: on,
            onChanged: _switching ? null : _toggleDuty,
            activeThumbColor: AppTheme.success,
          ),
        ],
      ),
    );
  }

  Widget _entryCard(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _taskCard(Delivery d) {
    final l10n = context.l10n;
    final delayed = DeliveryStats.isDelayed(d);
    final color = DeliveryPalette.statusStyle(d.status, context.scheme);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: delayed
          ? AppTheme.danger.withValues(alpha: 0.5)
          : null,
      onTap: () => context.push('/courier/detail', extra: d.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(DeliveryPalette.statusIcon(d.status),
                    size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${d.number}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: context.mutedColor)),
                    AppBadge(
                      text: l10n.t(d.status.labelKey),
                      color: color,
                    ),
                  ],
                ),
              ),
              if (delayed)
                AppBadge(
                    text: l10n.t('delivery_delayed'),
                    color: AppTheme.danger,
                    icon: Icons.schedule_rounded),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(d.customerName.isEmpty ? '—' : d.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
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
            ],
          ),
          if (d.itemsSummary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(d.itemsSummary,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${l10n.t('delivery_fee')}: ${Money.format(d.fee)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DeliveryPalette.teal)),
              if (d.paymentOnDelivery) ...[
                const SizedBox(width: 8),
                AppBadge(
                    text: Money.format(d.saleTotal),
                    color: AppTheme.warning,
                    icon: Icons.payments_outlined),
              ],
              const Spacer(),
              Icon(Icons.chevron_left_rounded, color: context.mutedColor),
            ],
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
