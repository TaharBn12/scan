import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../store/domain/entities/store_customer.dart';
import '../../../store/presentation/bloc/store_account_bloc.dart';
import '../../../store/presentation/bloc/store_catalog_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// Saved delivery addresses.
class StoreAddressesPage extends StatelessWidget {
  const StoreAddressesPage({super.key});

  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('store_addresses')),
        actions: [
          IconButton(
            onPressed: () => _edit(context, null, ''),
            icon: const Icon(Icons.add_rounded, size: 22),
            tooltip: l10n.t('add'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<StoreAccountBloc, StoreAccountState>(
        buildWhen: (a, b) => a.addresses != b.addresses || a.session != b.session,
        builder: (context, state) {
          final customerId = state.session?.id ?? '';
          if (customerId.isEmpty) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.lock_outline_rounded,
                  title: l10n.t('store_sign_in'),
                  subtitle: l10n.t('store_auth_body'),
                ),
              ],
            );
          }
          if (state.addresses.isEmpty) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.location_on_outlined,
                  title: l10n.t('store_no_addresses'),
                  actionLabel: l10n.t('add'),
                  onAction: () => _edit(context, null, customerId),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: state.addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final address = state.addresses[i];
              return MonoCard(
                onTap: () => _edit(context, address, customerId),
                radius: Mono.radiusSm,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      address.isDefault
                          ? Icons.home_rounded
                          : Icons.location_on_outlined,
                      size: 19,
                      color: context.monoInk,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address.label.isEmpty
                                ? address.fullName
                                : address.label,
                            style: context.theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 3),
                          Text(address.oneLine,
                              style: context.theme.textTheme.bodySmall),
                          if (address.phone.isNotEmpty)
                            Text(address.phone,
                                style: context.theme.textTheme.labelSmall
                                    ?.copyWith(fontSize: 9.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context
                          .read<StoreAccountBloc>()
                          .add(DeleteStoreAddress(address.id)),
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 18, color: context.monoMuted),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    StoreAddress? existing,
    String customerId,
  ) async {
    final l10n = context.l10n;
    final label = TextEditingController(text: existing?.label ?? '');
    final name = TextEditingController(text: existing?.fullName ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final street = TextEditingController(text: existing?.address ?? '');
    final commune = TextEditingController(text: existing?.city ?? '');
    final wilaya = TextEditingController(text: existing?.wilaya ?? '');
    var isDefault = existing?.isDefault ?? false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? l10n.t('add') : l10n.t('edit')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: label,
                    decoration: InputDecoration(labelText: l10n.t('store_address_label'))),
                const SizedBox(height: 10),
                TextField(
                    controller: name,
                    decoration: InputDecoration(labelText: l10n.t('store_full_name'))),
                const SizedBox(height: 10),
                TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: l10n.t('phone'))),
                const SizedBox(height: 10),
                TextField(
                    controller: wilaya,
                    decoration: InputDecoration(labelText: l10n.t('store_wilaya'))),
                const SizedBox(height: 10),
                TextField(
                    controller: commune,
                    decoration: InputDecoration(labelText: l10n.t('store_commune'))),
                const SizedBox(height: 10),
                TextField(
                    controller: street,
                    decoration: InputDecoration(labelText: l10n.t('store_street'))),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isDefault,
                  title: Text(l10n.t('store_default_address'),
                      style: context.theme.textTheme.bodyMedium),
                  onChanged: (v) => setDialogState(() => isDefault = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('save')),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    context.read<StoreAccountBloc>().add(SaveStoreAddress(StoreAddress(
          id: existing?.id ?? _uuid.v4(),
          customerId: customerId,
          label: label.text.trim(),
          fullName: name.text.trim(),
          phone: phone.text.trim(),
          address: street.text.trim(),
          city: commune.text.trim(),
          wilaya: wilaya.text.trim(),
          isDefault: isDefault,
        )));
  }
}

/// How to reach the shop: phone, e-mail and the store's own socials.
class StoreSupportPage extends StatelessWidget {
  const StoreSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings =
        context.select<StoreCatalogBloc, StoreCatalogState>((b) => b.state).settings;
    final rows = <(IconData, String, String, String?)>[
      (Icons.phone_outlined, l10n.t('phone'), settings.supportPhone,
          settings.supportPhone.isEmpty ? null : 'tel:${settings.supportPhone}'),
      (Icons.mail_outline_rounded, l10n.t('store_email'), settings.supportEmail,
          settings.supportEmail.isEmpty ? null : 'mailto:${settings.supportEmail}'),
      if (settings.facebookUrl.isNotEmpty)
        (Icons.public_rounded, 'Facebook', settings.facebookUrl, settings.facebookUrl),
      if (settings.instagramUrl.isNotEmpty)
        (Icons.camera_alt_outlined, 'Instagram', settings.instagramUrl, settings.instagramUrl),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('store_support'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (rows.isEmpty)
            MonoEmpty(
              icon: Icons.headset_mic_outlined,
              title: l10n.t('store_no_support'),
              subtitle: l10n.t('store_no_support_body'),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MonoCard(
                  onTap: row.$4 == null
                      ? null
                      : () => launchUrl(Uri.parse(row.$4!),
                          mode: LaunchMode.externalApplication),
                  radius: Mono.radiusSm,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Icon(row.$1, size: 18, color: context.monoInk),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.$2, style: context.theme.textTheme.titleSmall),
                            Text(row.$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Icon(Icons.adaptive.arrow_forward,
                          size: 15, color: context.monoMuted),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
