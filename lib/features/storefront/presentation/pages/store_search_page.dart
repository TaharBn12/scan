import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../store/presentation/bloc/store_catalog_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';
import '../../../store/presentation/widgets/product_card.dart';

/// Full-catalogue search with instant results.
class StoreSearchPage extends StatefulWidget {
  const StoreSearchPage({super.key});

  @override
  State<StoreSearchPage> createState() => _StoreSearchPageState();
}

class _StoreSearchPageState extends State<StoreSearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.t('store_search_hint'),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) =>
              context.read<StoreCatalogBloc>().add(SearchStore(value)),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _controller.clear();
                context.read<StoreCatalogBloc>().add(const SearchStore(''));
              },
              icon: const Icon(Icons.close_rounded, size: 19),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<StoreCatalogBloc, StoreCatalogState>(
        buildWhen: (a, b) => a.products != b.products || a.status != b.status,
        builder: (context, state) {
          if (state.status == StoreCatalogStatus.loading) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (state.products.isEmpty) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.search_off_rounded,
                  title: l10n.t('store_no_results'),
                  subtitle: l10n.t('store_no_results_body'),
                ),
              ],
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: state.products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.66,
            ),
            itemBuilder: (context, i) => ProductCard(
              product: state.products[i],
              showRating: true,
              onTap: () => context.push('/store/product/${state.products[i].id}'),
            ),
          );
        },
      ),
    );
  }
}
