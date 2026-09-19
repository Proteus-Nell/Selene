import 'package:flutter/material.dart';
import 'package:period_tracker/core/palette.dart';

/// The cycle-phase colours, carried on [ThemeData] so a widget can reach them.
///
/// A theme extension rather than a global constant, because since AND-39 there
/// is no single answer: the colours depend on which of the six schemes the user
/// picked and whether the phone is in dark mode. Reaching for a constant would
/// have quietly painted every ring in Rose & Plum.
@immutable
class PhaseColors extends ThemeExtension<PhaseColors> {
  /// Wraps [palette]'s phase colours.
  const PhaseColors(this.palette);

  /// The palette these came from.
  final AppPalette palette;

  /// The bleeding days, as logged.
  Color get menstrual => palette.menstrual;

  /// Between the end of bleeding and the luteal phase.
  Color get follicular => palette.follicular;

  /// The estimated ovulation range, shown only where the user opted in.
  Color get ovular => palette.ovular;

  /// The run of days before a period is due.
  Color get luteal => palette.luteal;

  /// The four, in cycle order.
  List<Color> get inCycleOrder => palette.phaseColors;

  /// The phase colours of the theme in [context].
  ///
  /// `Something.of(context)` is the shape every Flutter reader already knows,
  /// and a constructor cannot carry the fallback below.
  // ignore: prefer_constructors_over_static_methods
  static PhaseColors of(BuildContext context) =>
      Theme.of(context).extension<PhaseColors>() ??
      const PhaseColors(AppPalettes.roseLight);

  @override
  PhaseColors copyWith({AppPalette? palette}) =>
      PhaseColors(palette ?? this.palette);

  @override
  PhaseColors lerp(ThemeExtension<PhaseColors>? other, double t) =>
      other is PhaseColors
      ? PhaseColors(palette.lerpTo(other.palette, t))
      : this;
}

/// Builds the app's [ThemeData].
///
/// The palette is chosen for contrast first. Every pair used for text clears
/// 4.5:1 and every pair used for a control clears 3:1, with margin, because
/// AND-18 turns those into a CI gate and retrofitting a palette that fails is
/// painful. `theme_test.dart` recomputes every ratio for all eleven palettes
/// from [AppPalettes], so a colour cannot be nudged without the suite noticing.
///
/// Every scheme is deliberately quiet, and none of them is the pink-for-girls
/// shorthand: Rose & Plum, the default since AND-39, is a deep rose against a
/// plum, not a bubblegum. This is a health record, read by people whose
/// relationship with the subject is not always a cheerful one
/// (`docs/PLAN.md` 6.3), and the six-way choice exists because that
/// relationship is not the same for everyone — Ink & Ochre is there for a
/// screen someone else can see, and Night for reading at 3am.
abstract final class AppTheme {
  /// Smallest interactive size, in logical pixels.
  ///
  /// Android's guideline and the number `androidTapTargetGuideline` checks.
  /// Applied through the themes below rather than remembered per widget.
  static const double minTapTarget = 48;

  /// Corner radius for a block the user can act on.
  ///
  /// Cards are for actionable things. Anything the app is merely telling the
  /// user sits flat on the page instead, with no fill and no border — a box
  /// drawn round a sentence is a box the eye has to dismiss before it can read
  /// (AND-39).
  static const double cardRadius = 10;

  /// The light theme for [scheme].
  static ThemeData light([AppScheme scheme = AppScheme.fallback]) =>
      _build(scheme.palette(Brightness.light), Brightness.light);

  /// The dark theme for [scheme].
  static ThemeData dark([AppScheme scheme = AppScheme.fallback]) =>
      _build(scheme.palette(Brightness.dark), Brightness.dark);

  /// The [ColorScheme] for [palette] at [brightness].
  static ColorScheme colorSchemeOf(
    AppPalette palette,
    Brightness brightness,
  ) => ColorScheme(
    brightness: brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.secondary,
    onSecondary: palette.onSecondary,
    error: palette.error,
    onError: palette.onError,
    surface: palette.surface,
    onSurface: palette.onSurface,
    surfaceContainer: palette.surfaceContainer,
    surfaceContainerHighest: palette.surfaceContainer,
    onSurfaceVariant: palette.onSurfaceVariant,
    outline: palette.outline,
  );

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final scheme = colorSchemeOf(palette, brightness);
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Bundled rather than fetched (`assets/fonts/`, AND-34). Roboto is not
      // the same shape on every Android skin, and a health record that reflows
      // differently on someone else's phone is a layout nobody has tested.
      //
      // Google Fonts' **latin subset**, 222 codepoints, which covers every
      // character in `app_en.arb` — `fonts_test.dart` re-checks that rather
      // than trusting it. A non-English locale would need a wider subset, and
      // that is the moment to notice, not after the strings are translated.
      fontFamily: 'Figtree',
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[PhaseColors(palette)],
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
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
        //
        // The checkmark is still there and is still what carries the state
        // without colour — it is drawn by `ChipMotion` rather than by Material
        // (AND-34). Material's own opens a drawer the width of the chip's
        // height when a chip is selected, so the row reflows under the finger,
        // and it rides a fixed 195ms animation that "remove animations" never
        // reaches. `ChipMotion` reserves the slot up front and fades the mark
        // over `Motion.quick`. `motion_test.dart` fails if a selectable chip
        // is built outside it, because with this false an unwrapped one would
        // have no checkmark at all.
        showCheckmark: false,
        side: BorderSide(color: scheme.outline),
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        secondarySelectedColor: scheme.primary.withValues(alpha: 0.18),
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
          borderRadius: BorderRadius.circular(cardRadius),
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
