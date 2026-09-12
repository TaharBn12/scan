import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/mono_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../store/domain/entities/store_review.dart';
import '../../../store/presentation/bloc/store_admin_bloc.dart';
import '../../../store/presentation/widgets/mono_ui.dart';

/// Registered shoppers and what they are worth.
class EcomCustomersPage extends StatelessWidget {
  const EcomCustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('ecom_shoppers'))),
      body: BlocBuilder<StoreAdminBloc, StoreAdminState>(
        buildWhen: (a, b) => a.customers != b.customers,
        builder: (context, state) {
          if (state.customers.isEmpty) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.people_alt_outlined,
                  title: l10n.t('ecom_no_shoppers'),
                  subtitle: l10n.t('ecom_no_shoppers_body'),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: state.customers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final customer = state.customers[i];
              return MonoCard(
                radius: Mono.radiusSm,
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.monoInk,
                        borderRadius: BorderRadius.circular(Mono.radiusSm),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        customer.initials,
                        style: context.theme.textTheme.titleSmall
                            ?.copyWith(color: context.monoScheme.onPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.theme.textTheme.titleSmall),
                          Text(
                            customer.phone.isNotEmpty
                                ? customer.phone
                                : customer.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Money.format(customer.lifetimeValue),
                          style: context.theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${customer.ordersCount} ${l10n.t('store_orders_word')}',
                          style: context.theme.textTheme.labelSmall
                              ?.copyWith(fontSize: 9),
                        ),
                      ],
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
}

/// Review moderation: approve or drop before a shopper sees it.
class EcomReviewsPage extends StatelessWidget {
  const EcomReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('store_reviews'))),
      body: BlocBuilder<StoreAdminBloc, StoreAdminState>(
        buildWhen: (a, b) => a.reviews != b.reviews,
        builder: (context, state) {
          if (state.reviews.isEmpty) {
            return ListView(
              children: [
                MonoEmpty(
                  icon: Icons.rate_review_outlined,
                  title: l10n.t('ecom_no_reviews'),
                  subtitle: l10n.t('ecom_no_reviews_body'),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: state.reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _ReviewCard(review: state.reviews[i]),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final StoreReview review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<StoreAdminBloc>();
    return MonoCard(
      radius: Mono.radiusSm,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.productName.isEmpty
                      ? review.productId
                      : review.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleSmall,
                ),
              ),
              MonoTag(
                text: review.approved
                    ? l10n.t('store_approved')
                    : l10n.t('store_pending_review'),
                inverted: review.approved,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              MonoRating(rating: review.rating.toDouble()),
              const SizedBox(width: 10),
              Expanded(
                child: Text(review.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment, style: context.theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MonoButton(
                  label: review.approved
                      ? l10n.t('store_hide_review')
                      : l10n.t('store_approve_review'),
                  small: true,
                  outlined: review.approved,
                  onPressed: () => bloc
                      .add(ModerateAdminReview(review.id, !review.approved)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => bloc.add(DeleteAdminReview(review.id)),
                icon: Icon(Icons.delete_outline_rounded,
                    size: 19, color: context.monoMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
