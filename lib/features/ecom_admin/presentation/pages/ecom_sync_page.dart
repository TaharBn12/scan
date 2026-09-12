import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/data/store_sync_service.dart';
import '../../../store/presentation/bloc/store_admin_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// Shelf ⇄ website.
///
/// Shows, product by product, why the site differs from the counter (missing,
/// price moved, stock moved, renamed) and pushes the difference in one tap.
/// Nothing about a listing's photos, description or category is ever
/// overwritten — only the fields the till owns.
class EcomSyncPage extends StatefulWidget {
  const EcomSyncPage({super.key});

  @override
  State<EcomSyncPage> createState() => _EcomSyncPageState();
}

class _EcomSyncPageState extends State<EcomSyncPage> {
  @override
  void initState() {
    super.initState();
    // After the first frame: dispatching during build would rebuild mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StoreAdminBloc>().add(PreviewShelfSync());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<StoreAdminBloc, StoreAdminState>(
      listenWhen: (a, b) => a.message != b.message && b.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(
              state.message == 'sync_done'
                  ? l10n.t('sync_done', {'n': state.syncPushed})
                  : l10n.t(state.message!),
            ),
          ));
      },
      builder: (context, state) {
        final bloc = context.read<StoreAdminBloc>();
        final rows = state.syncRows;
        final pending = rows.where((r) => r.reason.needsPush).toList();
        return Scaffold(
          appBar: AppBar(title: Text(l10n.t('ecom_sync'))),
          body: rows.isEmpty
              ? Center(
                  child: state.status == StoreAdminStatus.busy
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : MonoEmpty(
                          icon: Icons.sync_rounded,
                          title: l10n.t('ecom_sync_empty'),
                          subtitle: l10n.t('ecom_sync_empty_body'),
                        ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: MonoCard(
                        radius: Mono.radiusSm,
                        filled: true,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.t('ecom_sync_summary',
                                  {'n': pending.length, 'total': rows.length}),
                              style: context.theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.t('ecom_sync_body'),
                              style: context.theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _SyncRow(row: rows[i]),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: pending.isEmpty
              ? null
              : MonoBottomBar(
                  child: MonoButton(
                    label: l10n.t('ecom_push_to_site', {'n': pending.length}),
                    busy: state.status == StoreAdminStatus.busy,
                    onPressed: () => bloc.add(const RunShelfSync([])),
                  ),
                ),
        );
      },
    );
  }
}

class _SyncRow extends StatelessWidget {
  final SyncRow row;
  const _SyncRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final needs = row.reason.needsPush;
    return MonoCard(
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.pos.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  _detail(context, row),
                  style: context.theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          MonoTag(
            text: l10n.t(row.reason.labelKey),
            inverted: needs,
          ),
        ],
      ),
    );
  }

  String _detail(BuildContext context, SyncRow row) {
    final l10n = context.l10n;
    switch (row.reason) {
      case SyncReason.missing:
        return l10n.t('sync_detail_missing');
      case SyncReason.priceChanged:
        return '${l10n.t('sync_detail_price')}: '
            '${Money.format(row.listing!.price)} → ${Money.format(row.pos.price)}';
      case SyncReason.stockChanged:
        return '${l10n.t('sync_detail_stock')}: '
            '${row.listing!.stock.toInt()} → ${row.pos.stock.toInt()}';
      case SyncReason.renamed:
        return '${l10n.t('sync_detail_renamed')}: '
            '${row.listing!.name} → ${row.pos.name}';
      case SyncReason.identical:
        return l10n.t('sync_detail_identical');
    }
  }
}
