import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_cart.dart';
import '../../../store/presentation/bloc/store_cart_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// The basket, with the coupon box and the price breakdown.
class StoreCartPage extends StatelessWidget {
  const StoreCartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<StoreCartBloc, StoreCartState>(
      listenWhen: (a, b) => a.message != b.message && b.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.t(state.message!))));
      },
      builder: (context, state) {
        if (state.cart.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.t('store_cart'))),
            body: MonoEmpty(
              icon: Icons.shopping_bag_outlined,
              title: l10n.t('store_cart_empty_title'),
              subtitle: l10n.t('store_cart_empty_body'),
              actionLabel: l10n.t('store_start_shopping'),
              onAction: () => context.push('/store/browse'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${l10n.t('store_cart')} (${state.cart.lineCount})'),
            actions: [
              TextButton(
                onPressed: () => context.read<StoreCartBloc>().add(ClearCart()),
                child: Text(l10n.t('clear').toUpperCase(),
                    style: context.theme.textTheme.labelSmall),
              ),
            ],
          ),
          body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: state.cart.lines.length + 2,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i < state.cart.lines.length) {
                return _CartRow(line: state.cart.lines[i]);
              }
              if (i == state.cart.lines.length) return const _CouponBox();
              return _Summary(cart: state.cart);
            },
          ),
          bottomNavigationBar: MonoBottomBar(
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.t('total').toUpperCase(),
                        style: context.theme.textTheme.labelSmall
                            ?.copyWith(fontSize: 9)),
                    Text(
                      Money.format(state.cart.total),
                      style: context.theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MonoButton(
                    label: l10n.t('store_checkout'),
                    icon: Icons.arrow_forward_rounded,
                    onPressed: state.cart.belowMinimum
                        ? null
                        : () => context.push('/store/checkout'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartLine line;
  const _CartRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/store/product/${line.product.id}'),
            child: MonoImage(
              url: line.product.cover,
              width: 74,
              height: 74,
              radius: BorderRadius.circular(Mono.radiusXs),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.localizedName(l10n.locale.languageCode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                MonoPrice(
                  price: line.unitPrice,
                  compareAt: line.product.compareAtPrice,
                  format: Money.format,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    MonoStepper(
                      value: line.quantity,
                      max: line.maxQuantity,
                      compact: true,
                      onChanged: (v) => context.read<StoreCartBloc>().add(
                            ChangeQuantity(line.id, v),
                          ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () =>
                          context.read<StoreCartBloc>().add(RemoveFromCart(line.id)),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(Icons.close_rounded,
                            size: 17, color: context.monoMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Money.format(line.lineTotal),
            style: context.theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CouponBox extends StatefulWidget {
  const _CouponBox();

  @override
  State<_CouponBox> createState() => _CouponBoxState();
}

class _CouponBoxState extends State<_CouponBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final coupon = context
        .select<StoreCartBloc, StoreCartState>((b) => b.state)
        .cart
        .coupon;
    final applying = context.select<StoreCartBloc, bool>(
        (b) => b.state.status == StoreCartStatus.applyingCoupon);
    return MonoCard(
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('store_coupon').toUpperCase(),
              style: context.theme.textTheme.labelSmall?.copyWith(fontSize: 9.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: coupon == null,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: l10n.t('store_coupon_hint'),
                    isDense: true,
                  ),
                  onSubmitted: (v) =>
                      context.read<StoreCartBloc>().add(ApplyCoupon(v)),
                ),
              ),
              const SizedBox(width: 10),
              if (coupon == null)
                MonoButton(
                  label: l10n.t('apply'),
                  small: true,
                  expanded: false,
                  busy: applying,
                  onPressed: () => context
                      .read<StoreCartBloc>()
                      .add(ApplyCoupon(_controller.text)),
                )
              else
                MonoButton(
                  label: l10n.t('remove'),
                  small: true,
                  expanded: false,
                  outlined: true,
                  onPressed: () {
                    _controller.clear();
                    context.read<StoreCartBloc>().add(ClearCoupon());
                  },
                ),
            ],
          ),
          if (coupon != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 15, color: context.monoInk),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    l10n.t('store_coupon_active', {'code': coupon.code}),
                    style: context.theme.textTheme.bodySmall
                        ?.copyWith(color: context.monoInk),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final StoreCart cart;
  const _Summary({required this.cart});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MonoCard(
      radius: Mono.radiusSm,
      filled: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          MonoRow(
            label: l10n.t('subtotal'),
            value: Money.format(cart.subtotal),
          ),
          if (cart.discount > 0)
            MonoRow(
              label: l10n.t('discount'),
              value: '-${Money.format(cart.discount)}',
            ),
          MonoRow(
            label: l10n.t('store_shipping'),
            value: cart.shippingFee == 0
                ? l10n.t('store_free')
                : Money.format(cart.shippingFee),
          ),
          const MonoDivider(),
          MonoRow(
            label: l10n.t('total'),
            value: Money.format(cart.total),
            emphasizeValue: true,
          ),
          if (cart.belowMinimum)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                l10n.t('store_min_order', {'amount': Money.format(cart.settings.minOrder)}),
                style: context.theme.textTheme.bodySmall
                    ?.copyWith(color: Mono.danger),
              ),
            ),
        ],
      ),
    );
  }
}
