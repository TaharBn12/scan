import 'package:flutter/material.dart';

import '../../domain/entities/delivery.dart';

/// The delivery feature's visual identity — one place for the status
/// colors, gradients and the Glovo-style hero header used by every screen.
class DeliveryPalette {
  DeliveryPalette._();

  static const teal = Color(0xFF0D9488);
  static const deepTeal = Color(0xFF0F766E);
  static const amber = Color(0xFFF59E0B);
  static const sky = Color(0xFF3B82F6);

  static Color statusStyle(DeliveryStatus s, ColorScheme scheme) =>
      switch (s) {
        DeliveryStatus.pending => amber,
        DeliveryStatus.assigned => scheme.primary,
        DeliveryStatus.pickedUp => sky,
        DeliveryStatus.delivered => teal,
        DeliveryStatus.failed => const Color(0xFFEF4444),
        DeliveryStatus.cancelled => const Color(0xFF94A3B8),
      };

  static IconData statusIcon(DeliveryStatus s) => switch (s) {
        DeliveryStatus.pending => Icons.schedule_rounded,
        DeliveryStatus.assigned => Icons.assignment_ind_outlined,
        DeliveryStatus.pickedUp => Icons.delivery_dining_rounded,
        DeliveryStatus.delivered => Icons.check_circle_outline_rounded,
        DeliveryStatus.failed => Icons.error_outline_rounded,
        DeliveryStatus.cancelled => Icons.cancel_outlined,
      };
}

/// Curved gradient hero that crowns the courier/admin delivery screens —
/// title + subtitle over the gradient, slot for a trailing widget, and an
/// optional child that overlaps the bottom edge (stat cards, big switch…).
class DeliveryHeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final Widget? overlap;
  final double overlapOffset;
  final List<Color>? colors;

  const DeliveryHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.delivery_dining_rounded,
    this.trailing,
    this.overlap,
    this.overlapOffset = 34,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = colors ?? [DeliveryPalette.deepTeal, DeliveryPalette.teal];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: overlap != null ? overlapOffset : 0),
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 18, 20,
              overlap != null ? overlapOffset + 18 : 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            height: 1.3)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A strong bottom action strip (fills remaining page bottom gracefully).
class DeliveryBottomBar extends StatelessWidget {
  final Widget child;
  const DeliveryBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: .5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
