import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../billing/data/promotion_repository.dart';
import '../../../billing/domain/entities/promotion.dart';
import '../../../product/presentation/bloc/product_bloc.dart';

/// The shop's automatic offers. They price themselves at the till — the
/// cashier never types anything.
class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final _repo = PromotionRepository();
  List<Promotion> _promos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _promos = _repo.getAll();
      _loading = false;
    });
  }

  Future<void> _openForm([Promotion? existing]) async {
    final changed = await context
        .push<bool>('/promotions/form', extra: existing);
    if (changed == true) _reload();
  }

  Future<void> _delete(Promotion promo) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.t('delete_promo')),
        content: Text(l10n.t('delete_promo_body', {'name': promo.name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l10n.delete,
                  style: const TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.delete(promo.id);
    _reload();
  }

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
        title: Text(l10n.t('promotions')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('new_promo')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _promos.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.local_offer_outlined,
                    title: l10n.t('no_promotions'),
                    message: l10n.t('no_promotions_hint'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    itemCount: _promos.length,
                    itemBuilder: (context, index) =>
                        _buildCard(_promos[index]),
                  ),
                ),
    );
  }

  Widget _buildCard(Promotion promo) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final running = promo.isValidOn(now);
    final color = !promo.active
        ? Colors.grey
        : running
            ? AppTheme.success
            : AppTheme.warning;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              promo.type == PromoType.buyXPayY
                  ? Icons.shopping_basket_outlined
                  : Icons.percent_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.name.isNotEmpty ? promo.name : _ruleText(promo),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    _ruleText(promo),
                    _targetText(promo),
                    if (promo.startAt != null || promo.endAt != null)
                      _windowText(promo),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.mutedColor),
                ),
                const SizedBox(height: 6),
                AppBadge(
                  text: !promo.active
                      ? l10n.t('promo_off')
                      : running
                          ? l10n.t('promo_running')
                          : l10n.t('promo_scheduled'),
                  color: color,
                ),
              ],
            ),
          ),
          Switch(
            value: promo.active,
            onChanged: (v) async {
              await _repo.save(promo.copyWith(active: v));
              _reload();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _openForm(promo);
              if (value == 'delete') _delete(promo);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
              PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
            ],
          ),
        ],
      ),
    );
  }

  String _ruleText(Promotion promo) {
    final l10n = context.l10n;
    if (promo.type == PromoType.buyXPayY) {
      return l10n.t('promo_rule_bxpy',
          {'pay': promo.payQty, 'get': promo.getQty});
    }
    return l10n.t('promo_rule_percent',
        {'percent': promo.percent.toStringAsFixed(0)});
  }

  String _targetText(Promotion promo) {
    final l10n = context.l10n;
    if (promo.targetsProduct) {
      for (final p in context.read<ProductBloc>().state.products) {
        if (p.id == promo.productId) return p.name;
      }
      return l10n.t('promo_deleted_product');
    }
    if (promo.targetsCategory) {
      return '${l10n.category}: ${promo.category}';
    }
    return l10n.t('promo_whole_shop');
  }

  String _windowText(Promotion promo) {
    final fmt = DateFormat('dd/MM');
    final start = promo.startAt == null ? '' : fmt.format(promo.startAt!);
    final end = promo.endAt == null ? '' : fmt.format(promo.endAt!);
    if (start.isEmpty) return '→ $end';
    if (end.isEmpty) return '$start →';
    return '$start → $end';
  }
}
