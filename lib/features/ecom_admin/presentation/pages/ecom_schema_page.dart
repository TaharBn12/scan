import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/supabase/schema_probe.dart';
import '../../../../core/supabase/store_connection.dart';
import '../../../../core/supabase/store_schema.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../store/presentation/bloc/store_admin_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// Reads the website's real database and binds the app to it.
///
/// PostgREST cannot list `information_schema`, so this asks every candidate
/// table for one row and takes the column names from the keys that come back.
/// The result is both applied at runtime and exportable as text, which is how
/// the app finishes connecting to a storefront whose source nobody opened.
class EcomSchemaPage extends StatefulWidget {
  const EcomSchemaPage({super.key});

  @override
  State<EcomSchemaPage> createState() => _EcomSchemaPageState();
}

class _EcomSchemaPageState extends State<EcomSchemaPage> {
  DiscoveredSchema? _schema;
  Map<String, Map<String, String>> _mapping = const {};
  bool _busy = false;
  String? _error;

  Future<void> _extract() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if (!storeConnection.isOnline) {
      final link = await storeConnection.connect(force: true);
      if (!link.isLive) {
        setState(() {
          _busy = false;
          _error = storeConnection.lastError ?? link.labelKey;
        });
        return;
      }
    }
    final schema = await SchemaProbe.discover();
    if (!mounted) return;
    setState(() {
      _schema = schema;
      _mapping = SchemaProbe.proposeMapping(schema);
      _busy = false;
      _error = schema.found.isEmpty ? 'store_schema_nothing_found' : null;
    });
  }

  Future<void> _apply() async {
    final names = _schema == null ? const {} : SchemaProbe.proposedTableNames(_schema!);
    if (names.isEmpty) return;
    await SchemaBinder.apply(names);
    if (!mounted) return;
    setState(() {});
    context.read<StoreAdminBloc>().add(const LoadStoreAdmin());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.l10n.t('store_schema_applied', {'n': names.length})),
      ));
  }

  Future<void> _copyReport() async {
    final schema = _schema;
    if (schema == null) return;
    await Clipboard.setData(ClipboardData(text: schema.report()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(context.l10n.t('store_schema_copied'))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final schema = _schema;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('store_schema_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          MonoCard(
            radius: Mono.radiusSm,
            filled: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('store_schema_what'),
                    style: context.theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(l10n.t('store_schema_body'),
                    style: context.theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MonoButton(
                  label: l10n.t('store_schema_extract'),
                  icon: Icons.download_rounded,
                  busy: _busy,
                  onPressed: _busy ? null : _extract,
                ),
              ),
              if (schema != null) ...[
                const SizedBox(width: 10),
                MonoButton(
                  label: l10n.t('copy'),
                  outlined: true,
                  expanded: false,
                  onPressed: _copyReport,
                ),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            MonoCard(
              radius: Mono.radiusSm,
              child: Text(
                l10n.t(_error!.startsWith('store_') || _error!.startsWith('ecom_')
                    ? _error!
                    : 'store_error_unknown'),
                style: context.theme.textTheme.bodyMedium
                    ?.copyWith(color: Mono.danger),
              ),
            ),
          ],
          if (StoreSchema.currentOverrides.isNotEmpty) ...[
            const SizedBox(height: 20),
            MonoSectionTitle(title: l10n.t('store_schema_active_map')),
            _OverridesCard(overrides: StoreSchema.currentOverrides),
            const SizedBox(height: 8),
            MonoButton(
              label: l10n.t('store_schema_reset'),
              outlined: true,
              onPressed: () async {
                await SchemaBinder.clear();
                if (mounted) setState(() {});
              },
            ),
          ],
          if (schema != null) ...[
            const SizedBox(height: 24),
            MonoSectionTitle(
              title: l10n.t('store_schema_found', {'n': schema.found.length}),
            ),
            if (schema.found.isEmpty)
              MonoCard(
                radius: Mono.radiusSm,
                child: Text(l10n.t('store_schema_nothing_found'),
                    style: context.theme.textTheme.bodyMedium),
              )
            else ...[
              for (final table in schema.found)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TableCard(
                    table: table,
                    mapping: _mapping[SchemaProbe.proposedTableNames(schema)[
                        _logicalFor(table.name)] ?? ''],
                  ),
                ),
              const SizedBox(height: 14),
              MonoButton(
                label: l10n.t('store_schema_apply',
                    {'n': SchemaProbe.proposedTableNames(schema).length}),
                onPressed: _apply,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Which logical table a discovered name maps to, via the proposal itself.
  String? _logicalFor(String found) {
    final proposal = SchemaProbe.proposedTableNames(_schema!);
    for (final entry in proposal.entries) {
      if (entry.value == found) return entry.key;
    }
    return null;
  }
}

class _TableCard extends StatelessWidget {
  final DiscoveredTable table;
  final Map<String, String>? mapping;
  const _TableCard({required this.table, this.mapping});

  @override
  Widget build(BuildContext context) {
    final mapped = mapping ?? const {};
    final inverse = {for (final e in mapped.entries) e.value: e.key};
    return MonoCard(
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(table.name,
                    style: context.theme.textTheme.titleMedium),
              ),
              if (table.columns.isEmpty)
                MonoTag(text: 'empty')
              else
                Text('${table.rowCount}',
                    style: context.theme.textTheme.labelSmall
                        ?.copyWith(fontSize: 9.5)),
            ],
          ),
          const SizedBox(height: 10),
          if (table.columns.isEmpty)
            Text(
              // A table with no rows cannot report its columns over PostgREST.
              '—',
              style: context.theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final column in table.columns)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Mono.radiusXs),
                      color: inverse.containsKey(column.name)
                          ? context.monoInk
                          : Colors.transparent,
                      border: Border.all(
                        color: inverse.containsKey(column.name)
                            ? context.monoInk
                            : context.monoBorder,
                      ),
                    ),
                    child: Text(
                      inverse.containsKey(column.name)
                          ? '${column.name} → ${inverse[column.name]}'
                          : column.name,
                      style: context.theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: inverse.containsKey(column.name)
                            ? context.monoScheme.onPrimary
                            : context.monoMuted,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OverridesCard extends StatelessWidget {
  final Map<String, String> overrides;
  const _OverridesCard({required this.overrides});

  @override
  Widget build(BuildContext context) {
    return MonoCard(
      radius: Mono.radiusSm,
      filled: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          for (final entry in overrides.entries)
            MonoRow(label: entry.key, value: entry.value),
        ],
      ),
    );
  }
}
