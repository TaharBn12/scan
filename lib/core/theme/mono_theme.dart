import 'package:flutter/material.dart';

/// The monochrome (black / white) design language of the e-commerce module.
///
/// Deliberately editorial: two real colours (pure black `#000` and pure
/// white `#FFF`) plus a neutral grey ramp, 1 px hairline borders, tight
/// radii, uppercase micro-labels and **no gradients anywhere**. Colour is
/// reserved for meaning only — a red badge for "cancelled", a green dot for
/// "in stock" — which is what keeps the black/white share above 53% of the
/// painted surface while the interface still reads as professional.
class Mono {
  const Mono._();

  // ---- the two anchors ----
  static const Color ink = Color(0xFF000000);
  static const Color paper = Color(0xFFFFFFFF);

  // ---- neutral ramp (light mode) ----
  static const Color ink900 = Color(0xFF0A0A0A);
  static const Color ink800 = Color(0xFF141414);
  static const Color ink700 = Color(0xFF1F1F1F);
  static const Color ink600 = Color(0xFF2B2B2B);
  static const Color ink500 = Color(0xFF3D3D3D);
  static const Color grey500 = Color(0xFF6B6B6B);
  static const Color grey400 = Color(0xFF8F8F8F);
  static const Color grey300 = Color(0xFFB8B8B8);
  static const Color grey200 = Color(0xFFD9D9D9);
  static const Color grey100 = Color(0xFFEDEDED);
  static const Color grey50 = Color(0xFFF6F6F6);

  // ---- dark mode mirrors ----
  static const Color darkPaper = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF111111);
  static const Color darkElevated = Color(0xFF1A1A1A);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkMuted = Color(0xFF9A9A9A);

  // ---- semantics (the only colours allowed) ----
  static const Color success = Color(0xFF111111);
  static const Color danger = Color(0xFFC1121F);
  static const Color warning = Color(0xFF7A5B00);
  static const Color inStock = Color(0xFF1B7F3B);
  static const Color outOfStock = Color(0xFFC1121F);
  static const Color priceCut = Color(0xFFC1121F);

  // ---- metrics ----
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 18;
  static const double hairline = 1;
  static const double gutter = 16;

  static BorderRadius get brXs => BorderRadius.circular(radiusXs);
  static BorderRadius get brSm => BorderRadius.circular(radiusSm);
  static BorderRadius get brMd => BorderRadius.circular(radiusMd);
  static BorderRadius get brLg => BorderRadius.circular(radiusLg);

  /// Bundled face, same as the POS, so Arabic renders identically.
  static const String fontFamily = 'IBMPlexSansArabic';

  /// The one permitted shadow: a whisper, never a grey blob.
  static List<BoxShadow> shadow(bool dark) => [
        BoxShadow(
          color: dark
              ? Colors.black.withValues(alpha: 0.5)
              : ink.withValues(alpha: 0.06),
          blurRadius: dark ? 22 : 16,
          offset: const Offset(0, 6),
        ),
      ];
}

/// Full Material 3 themes for the storefront + its admin console.
class MonoTheme {
  const MonoTheme._();

  static ThemeData light({VisualDensity? density}) =>
      _build(Brightness.light, density);

  static ThemeData dark({VisualDensity? density}) =>
      _build(Brightness.dark, density);

  static ThemeData _build(Brightness brightness, VisualDensity? density) {
    final dark = brightness == Brightness.dark;
    final scheme = dark ? _darkScheme() : _lightScheme();
    final text = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: density ?? VisualDensity.standard,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      fontFamily: Mono.fontFamily,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Mono.ink.withValues(alpha: 0.12),
        centerTitle: false,
        titleTextStyle: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Mono.brMd,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: Mono.hairline,
        space: Mono.hairline,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? Mono.darkElevated : Mono.paper,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.onSurface, width: 1.4),
        errorBorder: _inputBorder(Mono.danger),
        focusedErrorBorder: _inputBorder(Mono.danger, width: 1.4),
        disabledBorder: _inputBorder(scheme.outlineVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: Mono.brSm),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 50),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: Mono.brSm),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.onSurface, width: Mono.hairline),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: Mono.brSm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          textStyle: text.labelLarge?.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: scheme.onSurface,
          ),
          shape: RoundedRectangleBorder(borderRadius: Mono.brSm),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primary,
        labelStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: scheme.onPrimary),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.onSurface,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: text.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.onSurface.withValues(alpha: dark ? 1 : 1),
        elevation: 0,
        height: 66,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 21,
            color: s.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall!.copyWith(
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.onSurface,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: Mono.brMd),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Mono.paper : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: 0.12),
        ),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outlineVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant,
        circularTrackColor: scheme.outlineVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Mono.brSm),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Mono.brLg,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Mono.radiusLg)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: Mono.brSm),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Mono.brMd,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: text.bodyMedium,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: Mono.brXs,
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      }),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: Mono.brSm,
        borderSide: BorderSide(color: color, width: width),
      );

  static ColorScheme _lightScheme() => const ColorScheme(
        brightness: Brightness.light,
        primary: Mono.ink,
        onPrimary: Mono.paper,
        primaryContainer: Mono.ink800,
        onPrimaryContainer: Mono.paper,
        secondary: Mono.ink700,
        onSecondary: Mono.paper,
        secondaryContainer: Mono.grey100,
        onSecondaryContainer: Mono.ink900,
        tertiary: Mono.ink600,
        onTertiary: Mono.paper,
        tertiaryContainer: Mono.grey50,
        onTertiaryContainer: Mono.ink900,
        error: Mono.danger,
        onError: Mono.paper,
        errorContainer: Color(0xFFFCE7E9),
        onErrorContainer: Color(0xFF7A0A12),
        surface: Mono.paper,
        onSurface: Mono.ink,
        surfaceContainerLowest: Mono.paper,
        surfaceContainerLow: Mono.grey50,
        surfaceContainer: Mono.grey50,
        surfaceContainerHigh: Mono.grey100,
        surfaceContainerHighest: Mono.grey100,
        onSurfaceVariant: Mono.grey500,
        outline: Mono.grey300,
        outlineVariant: Mono.grey200,
        shadow: Mono.ink,
        scrim: Mono.ink,
        inverseSurface: Mono.ink900,
        onInverseSurface: Mono.paper,
        inversePrimary: Mono.paper,
      );

  static ColorScheme _darkScheme() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Mono.paper,
        onPrimary: Mono.ink,
        primaryContainer: Mono.grey100,
        onPrimaryContainer: Mono.ink,
        secondary: Mono.grey200,
        onSecondary: Mono.ink,
        secondaryContainer: Mono.darkElevated,
        onSecondaryContainer: Mono.paper,
        tertiary: Mono.grey300,
        onTertiary: Mono.ink,
        tertiaryContainer: Mono.darkElevated,
        onTertiaryContainer: Mono.paper,
        error: Color(0xFFFF6B74),
        onError: Color(0xFF3B0207),
        errorContainer: Color(0xFF5A0A11),
        onErrorContainer: Color(0xFFFFDADC),
        surface: Mono.darkPaper,
        onSurface: Mono.paper,
        surfaceContainerLowest: Color(0xFF050505),
        surfaceContainerLow: Mono.darkSurface,
        surfaceContainer: Mono.darkSurface,
        surfaceContainerHigh: Mono.darkElevated,
        surfaceContainerHighest: Color(0xFF222222),
        onSurfaceVariant: Mono.darkMuted,
        outline: Color(0xFF4A4A4A),
        outlineVariant: Mono.darkBorder,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: Mono.paper,
        onInverseSurface: Mono.ink,
        inversePrimary: Mono.ink,
      );

  static TextTheme _textTheme(ColorScheme scheme) {
    Color get on => scheme.onSurface;
    Color get muted => scheme.onSurfaceVariant;
    return TextTheme(
      displaySmall: TextStyle(
          fontSize: 34, fontWeight: FontWeight.w800, color: on, height: 1.1, letterSpacing: -1.2),
      headlineMedium: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w800, color: on, height: 1.15, letterSpacing: -0.8),
      headlineSmall: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: on, height: 1.2, letterSpacing: -0.5),
      titleLarge: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w700, color: on, letterSpacing: -0.3),
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: on, letterSpacing: -0.2),
      titleSmall: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: on, letterSpacing: -0.1),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: on, height: 1.45),
      bodyMedium: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400, color: on, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: muted, height: 1.4),
      labelLarge: TextStyle(
          fontSize: 13.5, fontWeight: FontWeight.w700, color: on, letterSpacing: 0.2),
      labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: on, letterSpacing: 0.3),
      labelSmall: TextStyle(
          fontSize: 10.5, fontWeight: FontWeight.w700, color: muted, letterSpacing: 1.0),
    );
  }
}

/// Semantic shortcuts for the storefront widgets, so a screen never hard-codes
/// a grey and the black/white share stays consistent.
extension MonoX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get monoScheme => theme.colorScheme;
  bool get isMonoDark => theme.brightness == Brightness.dark;

  Color get monoMuted => theme.colorScheme.onSurfaceVariant;
  Color get monoBorder => theme.colorScheme.outlineVariant;
  Color get monoSurface => theme.colorScheme.surface;
  Color get monoSurfaceAlt => theme.colorScheme.surfaceContainerLow;
  Color get monoInk => theme.colorScheme.onSurface;
  Color get monoPaper => theme.colorScheme.surface;
  Color get monoInverse => theme.colorScheme.inverseSurface;

  /// Hairline divider used between list rows.
  BorderSide get monoHairline => BorderSide(color: monoBorder, width: Mono.hairline);
}
