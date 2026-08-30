import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// Theme assembly. Both themes are built by one function from one palette, so
/// light and dark cannot drift apart — a fix in one is a fix in both.
abstract final class AppTheme {
  static ThemeData get light => _build(AppPalette.light);
  static ThemeData get dark => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.gold,
      onSecondary: p.isDark ? const Color(0xFF1B1408) : Colors.white,
      error: p.food,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
      surfaceContainerHighest: p.surfaceSunken,
      outline: p.border,
      outlineVariant: p.borderStrong,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      splashFactory: InkSparkle.splashFactory,
      textTheme: AppType.textTheme(p.ink, p.inkMuted),
      extensions: [p],

      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.strong(color: p.ink, size: 16),
      ),

      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: Strokes.hair,
        space: 1,
      ),

      // Chips carry filter state across the whole app. Pill shape + mono label
      // keeps them reading as controls rather than content.
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accent,
        checkmarkColor: p.onAccent,
        labelStyle: AppType.label(color: p.inkMuted),
        secondaryLabelStyle: AppType.label(color: p.onAccent),
        side: BorderSide(color: p.border, width: Strokes.hair),
        shape: const RoundedRectangleBorder(borderRadius: Radii.rPill),
        padding: const EdgeInsets.symmetric(horizontal: Space.s12, vertical: Space.s8),
        showCheckmark: false,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: Space.s24),
          shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
          textStyle: AppType.strong(size: 15),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: Space.s20),
          side: BorderSide(color: p.borderStrong, width: Strokes.hair),
          shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
          textStyle: AppType.strong(size: 15),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: AppType.strong(size: 14),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: AppType.body(color: p.inkFaint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.s16,
          vertical: Space.s16,
        ),
        border: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: p.border, width: Strokes.hair),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: p.border, width: Strokes.hair),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: p.accent, width: Strokes.edge),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accentSoft,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppType.labelS(
            color: states.contains(WidgetState.selected) ? p.ink : p.inkFaint,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? p.accent : p.inkFaint,
          ),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: p.isDark
            ? Colors.black.withValues(alpha: 0.62)
            : const Color(0xFF1E3B35).withValues(alpha: 0.34),
        shape: const RoundedRectangleBorder(borderRadius: Radii.rSheet),
        showDragHandle: false,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.isDark ? p.surfaceRaised : const Color(0xFF1E3B35),
        contentTextStyle: AppType.body(color: p.isDark ? p.ink : Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
        insetPadding: const EdgeInsets.all(Space.s16),
      ),

      // Fade-forwards rather than zoom: pushing to an event detail should feel
      // like turning a page, not opening a new context.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
