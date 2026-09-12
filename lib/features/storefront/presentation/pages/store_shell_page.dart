import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../store/presentation/bloc/store_account_bloc.dart';
import '../../../store/presentation/bloc/store_cart_bloc.dart';
import '../../../store/presentation/bloc/store_catalog_bloc.dart';
import '../../../store/presentation/widgets/store_status_bar.dart';
import 'store_account_page.dart';
import 'store_browse_page.dart';
import 'store_cart_page.dart';
import 'store_home_page.dart';

/// Lets any storefront screen jump to another tab (the cart badge in the
/// app bar, "continue shopping" after checkout, …).
final ValueNotifier<int> storeTabs = ValueNotifier<int>(0);

/// The customer-facing shop, hosted inside the POS.
///
/// It carries its own blocs and its own theme: whatever accent the merchant
/// picked for the till, the storefront is always the monochrome system, so a
/// shopper never sees the shop's internal colour choices.
class StoreShellPage extends StatefulWidget {
  final int initialTab;
  const StoreShellPage({super.key, this.initialTab = 0});

  @override
  State<StoreShellPage> createState() => _StoreShellPageState();
}

class _StoreShellPageState extends State<StoreShellPage> {
  late int _index = widget.initialTab.clamp(0, 3);

  @override
  void initState() {
    super.initState();
    storeTabs.value = _index;
    storeTabs.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    storeTabs.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    if (!mounted || storeTabs.value == _index) return;
    setState(() => _index = storeTabs.value.clamp(0, 3));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => StoreCatalogBloc()..add(LoadStorefront()),
        ),
        BlocProvider(create: (_) => StoreCartBloc()..add(RestoreCart())),
        BlocProvider(create: (_) => StoreAccountBloc()..add(LoadStoreAccount())),
      ],
      child: ValueListenableBuilder<ThemeSettings>(
        valueListenable: themeController,
        builder: (context, settings, _) {
          final density = settings.compact
              ? VisualDensity.compact
              : VisualDensity.standard;
          final dark = Theme.of(context).brightness == Brightness.dark;
          return Theme(
            data: dark
                ? MonoTheme.dark(density: density)
                : MonoTheme.light(density: density),
            child: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const StoreStatusBar(),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: [
                          const StoreHomePage(),
                          const StoreBrowsePage(),
                          const StoreCartPage(),
                          const StoreAccountPage(),
                        ],
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: _StoreNavBar(
                  index: _index,
                  onChanged: (i) {
                    storeTabs.value = i;
                    setState(() => _index = i);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoreNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _StoreNavBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.monoSurface,
        border: Border(top: BorderSide(color: context.monoInk, width: Mono.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront_rounded,
                label: l10n.t('store_tab_home'),
                selected: index == 0,
                onTap: () => onChanged(0),
              ),
              _NavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: l10n.t('store_tab_browse'),
                selected: index == 1,
                onTap: () => onChanged(1),
              ),
              _NavItem(
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag_rounded,
                label: l10n.t('store_tab_cart'),
                selected: index == 2,
                badge: context.select<StoreCartBloc, int>((b) => b.state.count),
                onTap: () => onChanged(2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: l10n.t('store_tab_account'),
                selected: index == 3,
                onTap: () => onChanged(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 21,
                  color: selected ? context.monoInk : context.monoMuted,
                ),
                if (badge > 0)
                  PositionedDirectional(
                    top: -5,
                    end: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 15),
                      decoration: BoxDecoration(
                        color: context.monoInk,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        textAlign: TextAlign.center,
                        style: context.theme.textTheme.labelSmall?.copyWith(
                          fontSize: 8.5,
                          color: context.monoScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.theme.textTheme.labelSmall?.copyWith(
                fontSize: 9.5,
                letterSpacing: 0.2,
                color: selected ? context.monoInk : context.monoMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
