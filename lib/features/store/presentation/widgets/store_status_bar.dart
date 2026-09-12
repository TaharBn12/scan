import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/supabase/store_connection.dart';
import '../../../../core/theme/mono_theme.dart';
import 'mono_ui.dart';

/// Thin strip shown above storefront content when the link to the site is
/// not healthy. Tap to retry — a shopper must never be stuck on a dead page.
class StoreStatusBar extends StatelessWidget {
  final bool compact;
  const StoreStatusBar({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: storeConnection,
      builder: (context, _) {
        final state = storeConnection.state;
        if (state.isLive) return const SizedBox.shrink();
        final (icon, key) = switch (state) {
          StoreLinkState.notConfigured => (Icons.link_off_rounded, 'store_link_not_configured'),
          StoreLinkState.connecting => (Icons.sync_rounded, 'store_link_connecting'),
          StoreLinkState.offline => (Icons.cloud_off_rounded, 'store_link_offline'),
          _ => (Icons.hourglass_empty_rounded, 'store_link_unknown'),
        };
        return Material(
          color: context.monoSurfaceAlt,
          child: InkWell(
            onTap: () => storeConnection.connect(force: true),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: Mono.gutter,
                vertical: compact ? 8 : 11,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.monoBorder)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: context.monoInk),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      context.l10n.t(key),
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: context.monoInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    context.l10n.t('retry').toUpperCase(),
                    style: context.theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Black-on-white badge carrying the cart count, for the app bar.
class CartCountBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const CartCountBadge({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.shopping_bag_outlined, size: 21),
          tooltip: context.l10n.t('store_cart'),
        ),
        if (count > 0)
          PositionedDirectional(
            top: 6,
            end: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: context.monoInk,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: context.theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: context.monoScheme.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
