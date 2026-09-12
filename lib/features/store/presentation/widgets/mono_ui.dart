import 'package:flutter/material.dart';

import '../../../../core/theme/mono_theme.dart';

/// The monochrome UI kit.
///
/// Every storefront and admin screen is assembled from these parts, which is
/// what keeps the black/white share above 53% of the interface: nothing here
/// paints a gradient, a coloured surface or a tinted chip. The only hues in
/// the whole module are the semantic ones (stock, price cut, error).

/// Hairline-bordered surface. The workhorse of the module.
class MonoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final bool filled;
  final Color? background;
  final bool selected;

  const MonoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Mono.gutter),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = Mono.radiusMd,
    this.filled = false,
    this.background,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final radii = BorderRadius.circular(radius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? (filled ? context.monoSurfaceAlt : context.monoSurface),
        borderRadius: radii,
        border: Border.all(
          color: selected ? context.monoInk : context.monoBorder,
          width: selected ? 1.6 : Mono.hairline,
        ),
      ),
      child: child,
    );
    final padded = Padding(padding: margin ?? EdgeInsets.zero, child: content);
    if (onTap == null && onLongPress == null) return padded;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radii,
          child: content,
        ),
      ),
    );
  }
}

/// Uppercase, letter-spaced section label — the module's typographic accent.
class MonoSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const MonoSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(2, 0, 2, 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: context.theme.textTheme.labelSmall
                  ?.copyWith(color: context.monoInk),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(action!.toUpperCase(),
                      style: context.theme.textTheme.labelSmall),
                  const SizedBox(width: 3),
                  Icon(_forward(context), size: 13, color: context.monoInk),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

IconData _forward(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back_ios_new_rounded
        : Icons.arrow_forward_ios_rounded;

/// Primary action: black block, white label, no rounding tricks.
class MonoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool outlined;
  final bool busy;
  final bool small;

  const MonoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
    this.outlined = false,
    this.busy = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final style = (outlined ? OutlinedButton.styleFrom() : ElevatedButton.styleFrom())
        .copyWith(
      minimumSize: WidgetStatePropertyAll(Size(0, small ? 38 : 50)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: small ? 14 : 20),
      ),
      textStyle: WidgetStatePropertyAll(
        context.theme.textTheme.labelLarge?.copyWith(
          fontSize: small ? 12.5 : 13.5,
          letterSpacing: 0.4,
        ),
      ),
    );
    final child = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: outlined ? context.monoInk : context.monoScheme.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: small ? 15 : 17),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
    final button = outlined
        ? OutlinedButton(onPressed: enabled ? onPressed : null, style: style, child: child)
        : ElevatedButton(
            onPressed: enabled ? onPressed : null, style: style, child: child);
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Pill filter used on browse/search screens. Selected = solid black.
class MonoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const MonoChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.monoInk : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? context.monoInk : context.monoBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: selected ? context.monoScheme.onPrimary : context.monoMuted),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: context.theme.textTheme.labelMedium?.copyWith(
                color: selected ? context.monoScheme.onPrimary : context.monoInk,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corner tag ("NEW", "-20%", "OUT OF STOCK"). Always black on white or the
/// reverse — never a coloured fill.
class MonoTag extends StatelessWidget {
  final String text;
  final bool inverted;
  final bool danger;

  const MonoTag({
    super.key,
    required this.text,
    this.inverted = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = inverted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: danger
            ? Mono.danger
            : (dark ? context.monoInk : context.monoSurface),
        borderRadius: Mono.brXs,
        border: Border.all(
          color: danger ? Mono.danger : (dark ? context.monoInk : context.monoInk),
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: context.theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          letterSpacing: 0.8,
          color: danger
              ? Colors.white
              : (dark ? context.monoScheme.onPrimary : context.monoInk),
        ),
      ),
    );
  }
}

/// Network image with a monochrome fallback, so a listing without a photo
/// still looks designed instead of broken.
class MonoImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? radius;
  final IconData placeholderIcon;

  const MonoImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.placeholderIcon = Icons.shopping_bag_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final radii = radius ?? BorderRadius.zero;
    final frame = ClipRRect(
      borderRadius: radii,
      child: SizedBox(
        width: width,
        height: height,
        child: (url == null || url!.trim().isEmpty)
            ? _Placeholder(icon: placeholderIcon)
            : Image.network(
                url!,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, __, ___) => _Placeholder(icon: placeholderIcon),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _Placeholder(icon: placeholderIcon, loading: true);
                },
              ),
      ),
    );
    return frame;
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final bool loading;
  const _Placeholder({required this.icon, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.monoSurfaceAlt,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.6))
          : Icon(icon, size: 26, color: context.monoMuted.withValues(alpha: 0.55)),
    );
  }
}

/// Price line: bold black price, struck-through compare-at price beside it.
class MonoPrice extends StatelessWidget {
  final double price;
  final double? compareAt;
  final String Function(num) format;
  final double? fontSize;
  final bool muted;

  const MonoPrice({
    super.key,
    required this.price,
    this.compareAt,
    required this.format,
    this.fontSize,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          format(price),
          style: context.theme.textTheme.titleSmall?.copyWith(
            fontSize: fontSize ?? 14.5,
            fontWeight: FontWeight.w800,
            color: muted ? context.monoMuted : context.monoInk,
            letterSpacing: -0.3,
          ),
        ),
        if (compareAt != null && compareAt! > price) ...[
          const SizedBox(width: 6),
          Text(
            format(compareAt!),
            style: context.theme.textTheme.bodySmall?.copyWith(
              fontSize: (fontSize ?? 14.5) - 2.5,
              decoration: TextDecoration.lineThrough,
              color: context.monoMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// 0–5 stars drawn as filled / outlined glyphs in ink.
class MonoRating extends StatelessWidget {
  final double rating;
  final int? count;
  final double size;
  final ValueChanged<int>? onTap;

  const MonoRating({
    super.key,
    required this.rating,
    this.count,
    this.size = 13,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onTap == null ? null : () => onTap!(i),
            child: Padding(
              padding: const EdgeInsets.only(right: 1.5),
              child: Icon(
                rating >= i
                    ? Icons.star_rounded
                    : (rating >= i - 0.5
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded),
                size: size,
                color: context.monoInk,
              ),
            ),
          ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text('($count)',
              style: context.theme.textTheme.bodySmall
                  ?.copyWith(fontSize: size - 2)),
        ],
      ],
    );
  }
}

/// Compact KPI block for the console dashboard.
class MonoStat extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool emphasized;

  const MonoStat({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.icon,
    this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return MonoCard(
      onTap: onTap,
      filled: emphasized,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: context.monoInk),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.labelSmall
                      ?.copyWith(fontSize: 9.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.theme.textTheme.headlineSmall?.copyWith(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Empty state: a hairline box, an icon and one sentence.
class MonoEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MonoEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.monoBorder),
              ),
              child: Icon(icon, size: 26, color: context.monoMuted),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.theme.textTheme.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: context.theme.textTheme.bodySmall,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              MonoButton(
                label: actionLabel!,
                onPressed: onAction,
                outlined: true,
                expanded: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder that matches the final layout, so a refresh does not
/// make the screen jump.
class MonoSkeleton extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  const MonoSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = Mono.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: context.monoSurfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// − 1 + stepper used in the cart and on the product page.
class MonoStepper extends StatelessWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final bool compact;

  const MonoStepper({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 34.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Mono.radiusSm),
        border: Border.all(color: context.monoInk),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            size: size,
            onTap: value <= 1 ? () => onChanged(0) : () => onChanged(value - 1),
          ),
          Container(
            constraints: BoxConstraints(minWidth: compact ? 30 : 38),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              value == value.roundToDouble()
                  ? value.toInt().toString()
                  : value.toStringAsFixed(2),
              style: context.theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            size: size,
            onTap: (max > 0 && value >= max) ? null : () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, required this.size, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon,
            size: 15, color: onTap == null ? context.monoMuted : context.monoInk),
      ),
    );
  }
}

/// A label/value line used in order details, checkout and settings.
class MonoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasizeValue;
  final Widget? trailing;

  const MonoRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasizeValue = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: context.theme.textTheme.bodySmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: emphasizeValue ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill for an order. Ink for every state except the two that must
/// stop the eye: cancelled / refunded.
class MonoStatusPill extends StatelessWidget {
  final String label;
  final bool danger;
  final bool solid;

  const MonoStatusPill({
    super.key,
    required this.label,
    this.danger = false,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = solid || danger
        ? Colors.white
        : context.monoInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: danger ? Mono.danger : (solid ? context.monoInk : Colors.transparent),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: danger ? Mono.danger : context.monoInk),
      ),
      child: Text(
        label.toUpperCase(),
        style: context.theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          color: fg,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

/// A horizontal hairline.
class MonoDivider extends StatelessWidget {
  final double height;
  const MonoDivider({super.key, this.height = 1});

  @override
  Widget build(BuildContext context) =>
      Divider(height: height, thickness: Mono.hairline, color: context.monoBorder);
}

/// Sticky bar pinned at the bottom of checkout / product screens.
class MonoBottomBar extends StatelessWidget {
  final Widget child;
  const MonoBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Mono.gutter,
        12,
        Mono.gutter,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.monoSurface,
        border: Border(top: BorderSide(color: context.monoInk, width: Mono.hairline)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Minimal bar chart drawn in ink — no chart dependency, no colours.
class MonoBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double height;

  const MonoBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final peak = values.fold<double>(0, (m, v) => v > m ? v : m);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: peak <= 0
                              ? 0.02
                              : (values[i] / peak).clamp(0.02, 1.0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: i == values.length - 1
                                  ? context.monoInk
                                  : context.monoInk.withValues(alpha: 0.35),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels.length > i ? labels[i] : '',
                      style: context.theme.textTheme.labelSmall
                          ?.copyWith(fontSize: 8.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A vertical timeline (order history on both sides of the counter).
class MonoTimeline extends StatelessWidget {
  final List<({String title, String? subtitle, bool done, bool current})> steps;

  const MonoTimeline({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: steps[i].done || steps[i].current
                          ? context.monoInk
                          : Colors.transparent,
                      border: Border.all(
                        color: steps[i].done || steps[i].current
                            ? context.monoInk
                            : context.monoBorder,
                        width: 1.4,
                      ),
                    ),
                  ),
                  if (i < steps.length - 1)
                    Container(
                      width: 1.4,
                      height: 34,
                      color: steps[i].done
                          ? context.monoInk
                          : context.monoBorder,
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 14 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].title,
                        style: context.theme.textTheme.titleSmall?.copyWith(
                          color: steps[i].done || steps[i].current
                              ? context.monoInk
                              : context.monoMuted,
                        ),
                      ),
                      if (steps[i].subtitle != null)
                        Text(steps[i].subtitle!,
                            style: context.theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
