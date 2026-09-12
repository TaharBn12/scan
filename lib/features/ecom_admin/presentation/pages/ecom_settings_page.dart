import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/supabase/store_connection.dart';
import '../../../../core/supabase/store_schema.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/algeria.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_settings.dart';
import '../../../store/presentation/bloc/store_admin_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// Everything that binds the app to the website: the Supabase project, the
/// table names, the payment methods and the delivery fees.
class EcomSettingsPage extends StatefulWidget {
  const EcomSettingsPage({super.key});

  @override
  State<EcomSettingsPage> createState() => _EcomSettingsPageState();
}

class _EcomSettingsPageState extends State<EcomSettingsPage> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final resolved = SupabaseConfig.resolve();
    _url.text = resolved.url;
    _key.text = resolved.anonKey;
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _saveConnection() async {
    setState(() => _saving = true);
    await SupabaseConfig.save(url: _url.text, anonKey: _key.text);
    final state = await storeConnection.connect(force: true);
    if (!mounted) return;
    setState(() => _saving = false);
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            state.isLive
                ? l10n.t('store_link_ok')
                : '${l10n.t('store_link_offline')}: '
                    '${storeConnection.lastError ?? ''}',
          ),
        ),
      );
    if (state.isLive && mounted) {
      context.read<StoreAdminBloc>().add(RecheckStoreLink());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('ecom_store_settings'))),
      body: BlocBuilder<StoreAdminBloc, StoreAdminState>(
        buildWhen: (a, b) =>
            a.settings != b.settings ||
            a.schemaHealth != b.schemaHealth ||
            a.shippingZones != b.shippingZones,
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              MonoSectionTitle(title: l10n.t('ecom_connection')),
              _ConnectionCard(
                url: _url,
                key: _key,
                saving: _saving,
                onSave: _saveConnection,
              ),
              const SizedBox(height: 10),
              _HealthCard(health: state.schemaHealth),
              const SizedBox(height: 24),
              MonoSectionTitle(title: l10n.t('ecom_storefront')),
              _StorefrontCard(
                settings: state.settings,
                onChanged: (s) =>
                    context.read<StoreAdminBloc>().add(SaveAdminSettings(s)),
              ),
              const SizedBox(height: 24),
              MonoSectionTitle(title: l10n.t('store_shipping')),
              _ShippingCard(
                settings: state.settings,
                onChanged: (s) =>
                    context.read<StoreAdminBloc>().add(SaveAdminSettings(s)),
              ),
              const SizedBox(height: 12),
              _WilayaFeePreview(),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final TextEditingController url;
  final TextEditingController key;
  final bool saving;
  final VoidCallback onSave;

  const _ConnectionCard({
    required this.url,
    required this.key,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: storeConnection,
      builder: (context, _) {
        final online = storeConnection.isOnline;
        return MonoCard(
          radius: Mono.radiusSm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? Mono.inStock : Mono.danger,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      l10n.t(storeConnection.state.labelKey),
                      style: context.theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.t('ecom_supabase_url'),
                  hintText: 'https://xxxx.supabase.co',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: key,
                autocorrect: false,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.t('ecom_anon_key'),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MonoButton(
                      label: l10n.t('store_connect'),
                      busy: saving,
                      onPressed: onSave,
                    ),
                  ),
                  const SizedBox(width: 10),
                  MonoButton(
                    label: l10n.t('ecom_test'),
                    outlined: true,
                    expanded: false,
                    onPressed: () =>
                        context.read<StoreAdminBloc>().add(RecheckStoreLink()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.t('ecom_connection_body'),
                  style: context.theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

/// Which tables exist in the project. A red row is not fatal — it only means
/// that part of the site (reviews, coupons…) is not switched on yet.
class _HealthCard extends StatelessWidget {
  final Map<String, bool> health;
  const _HealthCard({required this.health});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (health.isEmpty) return const SizedBox.shrink();
    final missing = health.entries.where((e) => !e.value).length;
    return MonoCard(
      radius: Mono.radiusSm,
      filled: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('ecom_schema_health',
                {'ok': health.length - missing, 'missing': missing}),
            style: context.theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in health.entries)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Mono.radiusXs),
                    border: Border.all(
                      color: entry.value ? context.monoInk : Mono.danger,
                    ),
                  ),
                  child: Text(
                    entry.key,
                    style: context.theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: entry.value ? context.monoInk : Mono.danger,
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

class _StorefrontCard extends StatelessWidget {
  final StoreSettings settings;
  final ValueChanged<StoreSettings> onChanged;
  const _StorefrontCard({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      radius: Mono.radiusSm,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.open,
            title: Text(l10n.t('ecom_store_open'),
                style: context.theme.textTheme.titleSmall),
            subtitle: Text(l10n.t('ecom_store_open_body'),
                style: context.theme.textTheme.bodySmall),
            onChanged: (v) => onChanged(_copySettings(settings, open: v)),
          ),
          const MonoDivider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.codEnabled,
            title: Text(l10n.t('store_pay_cod'),
                style: context.theme.textTheme.titleSmall),
            onChanged: (v) => onChanged(_copySettings(settings, cod: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.cardEnabled,
            title: Text(l10n.t('store_pay_card'),
                style: context.theme.textTheme.titleSmall),
            onChanged: (v) => onChanged(_copySettings(settings, card: v)),
          ),
          const MonoDivider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.t('store_min_order'),
                style: context.theme.textTheme.titleSmall),
            trailing: Text(Money.format(settings.minOrder),
                style: context.theme.textTheme.titleSmall),
            onTap: () => _editAmount(
              context,
              label: l10n.t('store_min_order'),
              value: settings.minOrder,
              onSaved: (v) => onChanged(_copySettings(settings, minOrder: v)),
            ),
          ),
        ],
      ),
    );
  }

}

class _ShippingCard extends StatelessWidget {
  final StoreSettings settings;
  final ValueChanged<StoreSettings> onChanged;
  const _ShippingCard({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      radius: Mono.radiusSm,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.t('ecom_default_fee'),
                style: context.theme.textTheme.titleSmall),
            subtitle: Text(l10n.t('ecom_default_fee_body'),
                style: context.theme.textTheme.bodySmall),
            trailing: Text(Money.format(settings.defaultShippingFee),
                style: context.theme.textTheme.titleSmall),
            onTap: () => _editAmount(
              context,
              label: l10n.t('ecom_default_fee'),
              value: settings.defaultShippingFee,
              onSaved: (v) => onChanged(_copySettings(settings, defaultFee: v)),
            ),
          ),
          const MonoDivider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.t('ecom_free_shipping_above'),
                style: context.theme.textTheme.titleSmall),
            trailing: Text(
              settings.freeShippingAbove == 0
                  ? l10n.t('none')
                  : Money.format(settings.freeShippingAbove),
              style: context.theme.textTheme.titleSmall,
            ),
            onTap: () => _editAmount(
              context,
              label: l10n.t('ecom_free_shipping_above'),
              value: settings.freeShippingAbove,
              onSaved: (v) => onChanged(_copySettings(settings, freeAbove: v)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The built-in wilaya price list, read-only: it is what the checkout uses
/// when the customer picks a wilaya, and the merchant edits the exceptions on
/// the website's own shipping table.
class _WilayaFeePreview extends StatelessWidget {
  const _WilayaFeePreview();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = l10n.locale.languageCode;
    return MonoCard(
      radius: Mono.radiusSm,
      filled: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('ecom_wilaya_fees'),
              style: context.theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.t('ecom_wilaya_fees_body'),
              style: context.theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          for (final w in Algeria.wilayas.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text('${w.code}',
                        style: context.theme.textTheme.labelSmall
                            ?.copyWith(fontSize: 9.5)),
                  ),
                  Expanded(
                    child: Text(w.name(languageCode),
                        style: context.theme.textTheme.bodySmall
                            ?.copyWith(color: context.monoInk)),
                  ),
                  Text(
                    '${Money.format(w.homeFee)} / ${Money.format(w.stopDeskFee)}',
                    style: context.theme.textTheme.labelSmall
                        ?.copyWith(fontSize: 9.5),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '+ ${Algeria.wilayas.length - 8} ${l10n.t('store_more_wilayas')}',
              style: context.theme.textTheme.labelSmall?.copyWith(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Immutable update of the store settings; kept as a top-level helper because
/// three cards on this screen edit different slices of the same row.
StoreSettings _copySettings(
  StoreSettings s, {
  bool? open,
  bool? cod,
  bool? card,
  double? minOrder,
  double? defaultFee,
  double? freeAbove,
}) =>
    StoreSettings(
      open: open ?? s.open,
      minOrder: minOrder ?? s.minOrder,
      freeShippingAbove: freeAbove ?? s.freeShippingAbove,
      defaultShippingFee: defaultFee ?? s.defaultShippingFee,
      codEnabled: cod ?? s.codEnabled,
      cardEnabled: card ?? s.cardEnabled,
      transferEnabled: s.transferEnabled,
      currency: s.currency,
      supportPhone: s.supportPhone,
      supportEmail: s.supportEmail,
      announcement: s.announcement,
      facebookUrl: s.facebookUrl,
      instagramUrl: s.instagramUrl,
    );

Future<void> _editAmount(
  BuildContext context, {
  required String label,
  required double value,
  required ValueChanged<double> onSaved,
}) async {
  final l10n = context.l10n;
  final controller = TextEditingController(text: Money.plain(value));
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.t('cancel')),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(l10n.t('save')),
        ),
      ],
    ),
  );
  final parsed = double.tryParse((result ?? '').replaceAll(',', '.'));
  if (parsed != null) onSaved(parsed);
}
