import 'package:flutter/material.dart';

/// The app's colour tokens and themes.
///
/// The palette is chosen for contrast first. Every pair used for text clears
/// 4.5:1 and every pair used for a control clears 3:1, with margin, because
/// AND-18 turns those into a CI gate and retrofitting a palette that fails is
/// painful. `theme_test.dart` recomputes every ratio from these constants, so a
/// colour cannot be nudged without the suite noticing.
///
/// It is deliberately quiet: muted, low-saturation, no pink-for-girls
/// shorthand. This is a health record, and it is read by people whose
/// relationship with the subject is not always a cheerful one
/// (`docs/PLAN.md` 6.3).
abstract final class AppColors {
  /// Background behind everything, light theme.
  static const Color lightSurface = Color(0xFFFFF8F8);

  /// Body text and icons on [lightSurface].
  static const Color lightOnSurface = Color(0xFF1B1B1F);

  /// Raised surfaces such as cards, light theme.
  static const Color lightSurfaceContainer = Color(0xFFF4E7E8);

  /// Secondary text, light theme.
  static const Color lightOnSurfaceVariant = Color(0xFF4A4448);

  /// Primary action colour, light theme.
  static const Color lightPrimary = Color(0xFF8E2C4A);

  /// Text on [lightPrimary].
  static const Color lightOnPrimary = Color(0xFFFFFFFF);

  /// Secondary accent, used for the predicted window.
  static const Color lightSecondary = Color(0xFF3D5464);

  /// Text on [lightSecondary].
  static const Color lightOnSecondary = Color(0xFFFFFFFF);

  /// Error colour, light theme.
  static const Color lightError = Color(0xFFA3170F);

  /// Text on [lightError].
  static const Color lightOnError = Color(0xFFFFFFFF);

  /// Borders and dividers, light theme.
  static const Color lightOutline = Color(0xFF6F6569);

  /// Background behind everything, dark theme.
  static const Color darkSurface = Color(0xFF131316);

  /// Body text and icons on [darkSurface].
  static const Color darkOnSurface = Color(0xFFE7E1E4);

  /// Raised surfaces such as cards, dark theme.
  static const Color darkSurfaceContainer = Color(0xFF1F1D20);

  /// Secondary text, dark theme.
  static const Color darkOnSurfaceVariant = Color(0xFFCFC7CB);

  /// Primary action colour, dark theme.
  static const Color darkPrimary = Color(0xFFFFB1C2);

  /// Text on [darkPrimary].
  static const Color darkOnPrimary = Color(0xFF5B1130);

  /// Secondary accent, dark theme.
  static const Color darkSecondary = Color(0xFFA9CBE3);

  /// Text on [darkSecondary].
  static const Color darkOnSecondary = Color(0xFF0F2C3D);

  /// Error colour, dark theme.
  static const Color darkError = Color(0xFFFFB4AB);

  /// Text on [darkError].
  static const Color darkOnError = Color(0xFF690005);

  /// Borders and dividers, dark theme.
  static const Color darkOutline = Color(0xFF9A9095);
}

/// Builds the app's [ThemeData].
abstract final class AppTheme {
  /// Smallest interactive size, in logical pixels.
  ///
  /// Android's guideline and the number `androidTapTargetGuideline` checks.
  /// Applied through the themes below rather than remembered per widget.
  static const double minTapTarget = 48;

  /// The light theme.
  static ThemeData light() => _build(_lightScheme);

  /// The dark theme.
  static ThemeData dark() => _build(_darkScheme);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    secondary: AppColors.lightSecondary,
    onSecondary: AppColors.lightOnSecondary,
    error: AppColors.lightError,
    onError: AppColors.lightOnError,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightOnSurface,
    surfaceContainer: AppColors.lightSurfaceContainer,
    surfaceContainerHighest: AppColors.lightSurfaceContainer,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
    outline: AppColors.lightOutline,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.darkOnSecondary,
    error: AppColors.darkError,
    onError: AppColors.darkOnError,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    surfaceContainer: AppColors.darkSurfaceContainer,
    surfaceContainerHighest: AppColors.darkSurfaceContainer,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    outline: AppColors.darkOutline,
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      // Every interactive default is pushed to the 48dp floor here rather than
      // at each call site, because the call site is where it gets forgotten.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(minTapTarget, minTapTarget),
          textStyle: base.textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(minTapTarget, minTapTarget),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(minTapTarget, minTapTarget),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTapTarget, minTapTarget),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      chipTheme: base.chipTheme.copyWith(
        // Chips carry state, so the state must survive greyscale and reach a
        // screen reader: a checkmark and a border do the work, and the fill is
        // a light tint rather than a solid block.
        //
        // The tint is also what keeps the contrast honest. Material's default
        // selected chip pairs a container colour with a dark label and lands
        // at 1.32:1 in this palette; `a11y_test.dart` caught that, which is the
        // argument for having the test at all, because nothing about the
        // rendered chip looked wrong. Keeping one label colour for both states
        // means there is only one ratio to get right.
        showCheckmark: true,
        side: BorderSide(color: scheme.outline),
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        secondarySelectedColor: scheme.primary.withValues(alpha: 0.18),
        checkmarkColor: scheme.onSurface,
        labelStyle: base.textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
