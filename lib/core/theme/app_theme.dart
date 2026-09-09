import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme_controller.dart';

/// One selectable accent for the whole app. The merchant picks one in
/// Settings → Appearance; everything else (surfaces, borders, states) is
/// derived from it so the app always stays visually consistent.
class AccentPalette {
  final String id;
  final String labelKey;
  final Color seed;
  final Color gradientEnd;

  const AccentPalette({
    required this.id,
    required this.labelKey,
    required this.seed,
    required this.gradientEnd,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [seed, gradientEnd],
      );
}

/// Design tokens + Material 3 themes.
///
/// The look is built on four ideas:
///  * one accent colour, everything else neutral (slate greys);
///  * soft, low-contrast elevation instead of heavy Material shadows;
///  * generous 16/20/24 radii and 1px hairline borders on every surface;
///  * a single bundled Arabic+Latin font, so all three languages match.
class AppTheme {
  AppTheme._();

  // ------------------------------------------------------------- palettes

  static const List<AccentPalette> accents = [
    AccentPalette(
      id: 'indigo',
      labelKey: 'accent_indigo',
      seed: Color(0xFF4F46E5),
      gradientEnd: Color(0xFF7C3AED),
    ),
    AccentPalette(
      id: 'emerald',
      labelKey: 'accent_emerald',
      seed: Color(0xFF059669),
      gradientEnd: Color(0xFF10B981),
    ),
    AccentPalette(
      id: 'ocean',
      labelKey: 'accent_ocean',
      seed: Color(0xFF0369A1),
      gradientEnd: Color(0xFF0EA5E9),
    ),
    AccentPalette(
      id: 'sunset',
      labelKey: 'accent_sunset',
      seed: Color(0xFFEA580C),
      gradientEnd: Color(0xFFF59E0B),
    ),
    AccentPalette(
      id: 'rose',
      labelKey: 'accent_rose',
      seed: Color(0xFFE11D48),
      gradientEnd: Color(0xFFF43F5E),
    ),
    AccentPalette(
      id: 'graphite',
      labelKey: 'accent_graphite',
      seed: Color(0xFF334155),
      gradientEnd: Color(0xFF64748B),
    ),
  ];

  static AccentPalette accentById(String? id) => accents.firstWhere(
        (a) => a.id == id,
        orElse: () => accents.first,
      );

  // --------------------------------------------------------------- tokens

  /// The accent currently selected by the merchant. Kept as a static so the
  /// screens written before the theming rework keep following the palette
  /// (prefer `Theme.of(context).colorScheme.primary` in new code).
  static Color get primaryColor => themeController.accent.seed;

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0EA5E9);

  static const Color lightBackground = Color(0xFFF6F7FB);
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Color(0xFFE6E8EF);
  static const Color lightMuted = Color(0xFF64748B);

  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF151C2C);
  static const Color darkElevated = Color(0xFF1C2436);
  static const Color darkBorder = Color(0xFF243044);
  static const Color darkMuted = Color(0xFF94A3B8);

  static const Color errorColor = danger;

  /// Bundled font covering Latin AND Arabic (see pubspec.yaml).
  static const String fontFamily = 'IBMPlexSansArabic';

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  static BorderRadius get brSm => BorderRadius.circular(radiusSm);
  static BorderRadius get brMd => BorderRadius.circular(radiusMd);
  static BorderRadius get brLg => BorderRadius.circular(radiusLg);

  /// Soft ambient shadow used by cards / sheets (never the default Material
  /// black blur, which looks dirty on coloured backgrounds).
  static List<BoxShadow> shadow(Brightness brightness, {bool strong = false}) {
    final dark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: dark
            ? Colors.black.withValues(alpha: strong ? 0.55 : 0.35)
            : const Color(0xFF0F172A).withValues(alpha: strong ? 0.10 : 0.05),
        blurRadius: strong ? 28 : 18,
        offset: Offset(0, strong ? 12 : 6),
      ),
    ];
  }

  // ----------------------------------------------------------- typography

  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.15),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
    headlineSmall: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, height: 1.2),
    titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.25),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.35),
    bodyMedium: TextStyle(fontSize: 14, height: 1.35),
    bodySmall: TextStyle(fontSize: 12, height: 1.3),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.1),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6),
  );

  // -------------------------------------------------------------- themes

  static ThemeData light(AccentPalette accent) => _build(
        brightness: Brightness.light,
        accent: accent,
        background: lightBackground,
        surface: lightSurface,
        surfaceAlt: const Color(0xFFF1F3F9),
        border: lightBorder,
        muted: lightMuted,
        onSurface: const Color(0xFF0F172A),
      );

  static ThemeData dark(AccentPalette accent) => _build(
        brightness: Brightness.dark,
        accent: accent,
        background: darkBackground,
        surface: darkSurface,
        surfaceAlt: darkElevated,
        border: darkBorder,
        muted: darkMuted,
        onSurface: const Color(0xFFE8ECF5),
      );

  /// Legacy entry points (kept so any old call site still compiles).
  static ThemeData get lightTheme => light(accents.first);
  static ThemeData get darkTheme => dark(accents.first);

  static ThemeData _build({
    required Brightness brightness,
    required AccentPalette accent,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color border,
    required Color muted,
    required Color onSurface,
  }) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? _lighten(accent.seed, 0.12) : accent.seed;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent.seed,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent.gradientEnd,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceAlt,
      outlineVariant: border,
      error: isDark ? const Color(0xFFF87171) : danger,
    );

    final text = textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    InputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: brSm,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: onSurface, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 18),
        iconTheme: IconThemeData(color: onSurface),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: brMd,
          side: BorderSide(color: border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: onSurface,
        shape: RoundedRectangleBorder(borderRadius: brSm),
        subtitleTextStyle: text.bodySmall?.copyWith(color: muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: brLg),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaceAlt : const Color(0xFF1E293B),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: _lighten(accent.seed, 0.3),
        shape: RoundedRectangleBorder(borderRadius: brSm),
        insetPadding: const EdgeInsets.all(16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceAlt : const Color(0xFFF8FAFC),
        hintStyle: text.bodyMedium?.copyWith(color: muted.withValues(alpha: 0.8)),
        labelStyle: text.bodyMedium?.copyWith(color: muted),
        floatingLabelStyle: text.labelMedium?.copyWith(color: primary),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        focusedBorder: inputBorder(primary, 1.6),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: muted.withValues(alpha: 0.2),
          disabledForegroundColor: muted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: brSm),
          textStyle: text.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: brSm),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: brSm),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: brSm),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: brSm),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? primary.withValues(alpha: isDark ? 0.28 : 0.12)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? surfaceAlt : const Color(0xFFF1F5F9),
        selectedColor: primary.withValues(alpha: isDark ? 0.3 : 0.14),
        checkmarkColor: primary,
        labelStyle: text.labelMedium?.copyWith(color: onSurface),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: primary),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: brMd),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: isDark ? 0.28 : 0.12),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(letterSpacing: 0),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: muted,
        indicatorColor: primary,
        dividerColor: Colors.transparent,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary
              : (isDark ? surfaceAlt : const Color(0xFFE2E8F0)),
        ),
        trackOutlineColor: WidgetStatePropertyAll(border),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
        circularTrackColor: border,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? surfaceAlt : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: text.bodySmall?.copyWith(color: Colors.white),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: brSm,
          side: BorderSide(color: border),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      }),
    );
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// Handy semantic colours that adapt to the current brightness.
extension AppColorsX on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get mutedColor =>
      isDarkMode ? AppTheme.darkMuted : AppTheme.lightMuted;
  Color get borderColor =>
      isDarkMode ? AppTheme.darkBorder : AppTheme.lightBorder;
  Color get surfaceAltColor =>
      isDarkMode ? AppTheme.darkElevated : const Color(0xFFF1F3F9);
}
