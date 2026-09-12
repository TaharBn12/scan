import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_order.dart';
import '../../../store/presentation/bloc/store_account_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// The shopper's space: sign in, order history, saved addresses, favourites.
class StoreAccountPage extends StatelessWidget {
  const StoreAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<StoreAccountBloc, StoreAccountState>(
      listenWhen: (a, b) => a.message != b.message && b.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.t(state.message!))));
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.t('store_tab_account')),
            actions: [
              if (state.signedIn)
                IconButton(
                  onPressed: () =>
                      context.read<StoreAccountBloc>().add(StoreSignOut()),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  tooltip: l10n.t('logout'),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: RefreshIndicator(
            color: context.monoInk,
            onRefresh: () async {
              context.read<StoreAccountBloc>().add(LoadStoreAccount());
              await Future<void>.delayed(const Duration(milliseconds: 500));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                if (state.signedIn) ...[
                  _ProfileHeader(state: state),
                  const SizedBox(height: 16),
                ] else ...[
                  const _AuthCard(),
                  const SizedBox(height: 16),
                ],
                MonoSectionTitle(title: l10n.t('store_my_account')),
                _MenuTile(
                  icon: Icons.receipt_long_outlined,
                  label: l10n.t('store_my_orders'),
                  trailing: state.orders.isEmpty
                      ? null
                      : '${state.orders.length}',
                  onTap: () => context.push('/store/orders'),
                ),
                _MenuTile(
                  icon: Icons.favorite_border_rounded,
                  label: l10n.t('store_wishlist'),
                  trailing:
                      state.wishlist.isEmpty ? null : '${state.wishlist.length}',
                  onTap: () => context.push('/store/wishlist'),
                ),
                _MenuTile(
                  icon: Icons.location_on_outlined,
                  label: l10n.t('store_addresses'),
                  trailing:
                      state.addresses.isEmpty ? null : '${state.addresses.length}',
                  onTap: () => context.push('/store/addresses'),
                ),
                _MenuTile(
                  icon: Icons.headset_mic_outlined,
                  label: l10n.t('store_support'),
                  onTap: () => context.push('/store/support'),
                ),
                if (state.orders.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  MonoSectionTitle(
                    title: l10n.t('store_recent_orders'),
                    action: l10n.t('see_all'),
                    onAction: () => context.push('/store/orders'),
                  ),
                  for (final order in state.orders.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OrderTile(order: order),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final StoreAccountState state;
  const _ProfileHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = state.session!.name.isNotEmpty
        ? state.session!.name
        : state.session!.email;
    final initials = name.isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();
    return MonoCard(
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.monoInk,
              borderRadius: BorderRadius.circular(Mono.radiusSm),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: context.theme.textTheme.titleLarge
                  ?.copyWith(color: context.monoScheme.onPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.titleMedium),
                Text(state.session!.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(
                  '${state.orders.length} ${l10n.t('store_orders_word')} · '
                  '${Money.format(state.lifetimeValue)}',
                  style: context.theme.textTheme.labelSmall
                      ?.copyWith(color: context.monoInk, fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatefulWidget {
  const _AuthCard();

  @override
  State<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<_AuthCard> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _signingUp = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = context.select<StoreAccountBloc, bool>(
        (b) => b.state.status == StoreAccountStatus.busy);
    return MonoCard(
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (_signingUp ? l10n.t('store_create_account') : l10n.t('store_sign_in'))
                  .toUpperCase(),
              style: context.theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('store_auth_body'),
              style: context.theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (_signingUp) ...[
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                    labelText: l10n.t('store_full_name'), isDense: true),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration:
                    InputDecoration(labelText: l10n.t('phone'), isDense: true),
              ),
              const SizedBox(height: 10),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  InputDecoration(labelText: l10n.t('store_email'), isDense: true),
              validator: (v) => (v == null || !v.contains('@'))
                  ? l10n.t('store_bad_email')
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: l10n.t('store_password'), isDense: true),
              validator: (v) =>
                  (v == null || v.length < 6) ? l10n.t('store_auth_weak_password') : null,
            ),
            const SizedBox(height: 16),
            MonoButton(
              label: _signingUp ? l10n.t('store_sign_up') : l10n.t('store_sign_in'),
              busy: busy,
              onPressed: busy
                  ? null
                  : () {
                      if (!(_formKey.currentState?.validate() ?? false)) return;
                      final bloc = context.read<StoreAccountBloc>();
                      if (_signingUp) {
                        bloc.add(StoreSignUp(
                          name: _name.text.trim(),
                          email: _email.text.trim(),
                          password: _password.text,
                          phone: _phone.text.trim(),
                        ));
                      } else {
                        bloc.add(StoreSignIn(_email.text.trim(), _password.text));
                      }
                    },
            ),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _signingUp = !_signingUp),
                child: Text(
                  _signingUp
                      ? l10n.t('store_have_account')
                      : l10n.t('store_no_account'),
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.monoInk,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t('store_guest_note'),
              style: context.theme.textTheme.labelSmall?.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MonoCard(
        onTap: onTap,
        radius: Mono.radiusSm,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.monoInk),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: context.theme.textTheme.titleSmall),
            ),
            if (trailing != null)
              Text(trailing!,
                  style: context.theme.textTheme.bodySmall
                      ?.copyWith(color: context.monoInk)),
            const SizedBox(width: 8),
            Icon(Icons.adaptive.arrow_forward,
                size: 15, color: context.monoMuted),
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final StoreOrder order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      onTap: () => context.push('/store/order/${order.id}', extra: order),
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.number.isEmpty ? order.id.substring(0, 8) : order.number,
                  style: context.theme.textTheme.titleSmall
                      ?.copyWith(letterSpacing: 0.4),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.itemCount.toInt()} ${l10n.t('store_items_word')} · '
                  '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                  style: context.theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.format(order.total),
                style: context.theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              MonoStatusPill(
                label: l10n.t(order.status.labelKey),
                danger: order.status.isFinal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
