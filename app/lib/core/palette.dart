import 'package:flutter/material.dart';

/// One scheme's colours at one brightness.
///
/// Every field is opaque and stated outright rather than derived, because the
/// contrast gate in `theme_test.dart` recomputes each ratio from these numbers.
/// A tone generated at runtime is a tone no test can pin.
@immutable
final class AppPalette {
  /// Creates a palette.
  const AppPalette({
    required this.surface,
    required this.onSurface,
    required this.surfaceContainer,
    required this.onSurfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.error,
    required this.onError,
    required this.outline,
    required this.menstrual,
    required this.follicular,
    required this.ovular,
    required this.luteal,
  });

  /// Background behind everything.
  final Color surface;

  /// Body text and icons on [surface].
  final Color onSurface;

  /// Raised surfaces such as cards.
  final Color surfaceContainer;

  /// Secondary text.
  final Color onSurfaceVariant;

  /// Primary action colour.
  final Color primary;

  /// Text on [primary].
  final Color onPrimary;

  /// Secondary accent.
  final Color secondary;

  /// Text on [secondary].
  final Color onSecondary;

  /// Error colour.
  final Color error;

  /// Text on [error].
  final Color onError;

  /// Borders and dividers.
  final Color outline;

  /// The bleeding days, as logged.
  final Color menstrual;

  /// Between the end of bleeding and the luteal phase.
  final Color follicular;

  /// The estimated ovulation range.
  ///
  /// Used **only** where the user has opted in (`SettingKey.showOvulationWindow`,
  /// `docs/PLAN.md` 6.2, ADR-0007). It is not a `CyclePhase`: the domain has no
  /// ovulation phase and is not getting one. It is here because the arc the
  /// opted-in ring draws needs a colour, and a colour that exists is easier to
  /// keep out of the wrong screen than one improvised at a call site.
  final Color ovular;

  /// The run of days before a period is due.
  final Color luteal;

  /// The four phase colours in cycle order, for a legend or a ring.
  List<Color> get phaseColors => <Color>[
    menstrual,
    follicular,
    ovular,
    luteal,
  ];

  /// Interpolates towards [other], for [ThemeExtension.lerp].
  AppPalette lerpTo(AppPalette other, double t) => AppPalette(
    surface: Color.lerp(surface, other.surface, t)!,
    onSurface: Color.lerp(onSurface, other.onSurface, t)!,
    surfaceContainer: Color.lerp(
      surfaceContainer,
      other.surfaceContainer,
      t,
    )!,
    onSurfaceVariant: Color.lerp(
      onSurfaceVariant,
      other.onSurfaceVariant,
      t,
    )!,
    primary: Color.lerp(primary, other.primary, t)!,
    onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    secondary: Color.lerp(secondary, other.secondary, t)!,
    onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
    error: Color.lerp(error, other.error, t)!,
    onError: Color.lerp(onError, other.onError, t)!,
    outline: Color.lerp(outline, other.outline, t)!,
    menstrual: Color.lerp(menstrual, other.menstrual, t)!,
    follicular: Color.lerp(follicular, other.follicular, t)!,
    ovular: Color.lerp(ovular, other.ovular, t)!,
    luteal: Color.lerp(luteal, other.luteal, t)!,
  );
}

/// The colour schemes the user can choose between (AND-39).
///
/// Six of them, each measured against the same gates before it was offered.
/// The choice is a preference and nothing more: no scheme unlocks a feature,
/// hides a warning, or changes a number. What it does change is whether someone
/// can stand to open the app, which for a health record read on bad days is not
/// a small thing.
///
/// The palettes themselves are on [AppPalettes]. The labels are not here, they
/// are in `app_en.arb`, because a label is a user-facing string and this is a
/// data type.
enum AppScheme {
  /// Warm and soft, closest to the reference designs. The default.
  rose('rose', AppPalettes.roseLight, AppPalettes.roseDark),

  /// Calm and botanical. What the app wore before this release.
  sage('sage', AppPalettes.sageLight, AppPalettes.sageDark),

  /// Cool and quiet.
  lilac('lilac', AppPalettes.lilacLight, AppPalettes.lilacDark),

  /// Soft blue against terracotta. The furthest from pink.
  periwinkle('periwinkle', AppPalettes.periLight, AppPalettes.periDark),

  /// Near-monochrome with one accent. The most discreet on a shared screen.
  ink('ink', AppPalettes.inkLight, AppPalettes.inkDark),

  /// Designed dark rather than inverted, and always dark. See [forcesDark].
  night('night', AppPalettes.nightDark, AppPalettes.nightDark);

  const AppScheme(this.wireName, this.light, this.dark);

  /// The key as stored.
  ///
  /// Spelled out rather than taken from [name], for the same reason
  /// `SettingKey.wireName` is: renaming the Dart member must not silently
  /// reset every user's choice.
  final String wireName;

  /// This scheme's light palette. Equal to [dark] when [forcesDark].
  final AppPalette light;

  /// This scheme's dark palette.
  final AppPalette dark;

  /// The scheme a fresh install wears.
  static const AppScheme fallback = AppScheme.rose;

  /// Whether choosing this scheme also means choosing dark.
  ///
  /// True for [night] alone. It is described as designed dark rather than
  /// inverted, and that is the literal truth: it has no light half to fall back
  /// to. Rather than quietly ignoring the theme control — a setting that does
  /// nothing is worse than one that is visibly unavailable — the appearance
  /// screen disables it and says why.
  bool get forcesDark => this == AppScheme.night;

  /// The palette for [brightness].
  AppPalette palette(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The scheme stored as [wireName], or [fallback] if it is absent or unknown.
  ///
  /// Unknown rather than throwing, because the value can come off disk: a
  /// database written by a build that had a scheme this one does not must open,
  /// and opening in the default is the only sane answer.
  static AppScheme fromWireName(String? wireName) {
    for (final scheme in AppScheme.values) {
      if (scheme.wireName == wireName) return scheme;
    }
    return fallback;
  }
}

/// The colour numbers themselves.
///
/// Every one of these was checked before it shipped, and `theme_test.dart`
/// re-checks all of them on every run. The light halves of the five light-first
/// schemes are the ones approved on the design canvas and are copied verbatim.
abstract final class AppPalettes {
  static const AppPalette roseLight = AppPalette(
    surface: Color(0xFFFCF5F5),
    onSurface: Color(0xFF2A1F22),
    surfaceContainer: Color(0xFFF6E3E5),
    onSurfaceVariant: Color(0xFF544348),
    primary: Color(0xFF8E2C4A),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF6B4A7A),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFF9A2F2A),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFF7A6469),
    menstrual: Color(0xFF8E1F38),
    follicular: Color(0xFFD4578E),
    ovular: Color(0xFFC2691F),
    luteal: Color(0xFF6B4A7A),
  );

  static const AppPalette roseDark = AppPalette(
    surface: Color(0xFF171315),
    onSurface: Color(0xFFF0E2E5),
    surfaceContainer: Color(0xFF241D20),
    onSurfaceVariant: Color(0xFFCFBDC2),
    primary: Color(0xFFF3A9BF),
    onPrimary: Color(0xFF490F24),
    secondary: Color(0xFFDCB4EC),
    onSecondary: Color(0xFF3A2148),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    outline: Color(0xFF9C8A90),
    menstrual: Color(0xFFFF8F8F),
    follicular: Color(0xFFF3A9BF),
    ovular: Color(0xFFE8B478),
    luteal: Color(0xFFC6A6E6),
  );

  static const AppPalette sageLight = AppPalette(
    surface: Color(0xFFF7F7F1),
    onSurface: Color(0xFF22261F),
    surfaceContainer: Color(0xFFE4EBDF),
    onSurfaceVariant: Color(0xFF474E44),
    primary: Color(0xFF3F6146),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF985331),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFF9A2F2A),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFF666D62),
    menstrual: Color(0xFF9A2F2A),
    follicular: Color(0xFF3F6146),
    ovular: Color(0xFF7A6212),
    luteal: Color(0xFF985331),
  );

  static const AppPalette sageDark = AppPalette(
    surface: Color(0xFF161713),
    onSurface: Color(0xFFE5E7E0),
    surfaceContainer: Color(0xFF20221C),
    onSurfaceVariant: Color(0xFFC2C6BC),
    primary: Color(0xFFAFCCB2),
    onPrimary: Color(0xFF17321D),
    secondary: Color(0xFFF0B48D),
    onSecondary: Color(0xFF4C2609),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    outline: Color(0xFF8D9189),
    menstrual: Color(0xFFFF9E9E),
    follicular: Color(0xFFAFCCB2),
    ovular: Color(0xFFE0CB84),
    luteal: Color(0xFFF0B48D),
  );

  static const AppPalette lilacLight = AppPalette(
    surface: Color(0xFFF6F4FA),
    onSurface: Color(0xFF221F2B),
    surfaceContainer: Color(0xFFE9E4F3),
    onSurfaceVariant: Color(0xFF4B4657),
    primary: Color(0xFF584791),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF3F6357),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFF9A2F4A),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFF6B6577),
    menstrual: Color(0xFF9A2F4A),
    follicular: Color(0xFF584791),
    ovular: Color(0xFF7A6212),
    luteal: Color(0xFF3F6357),
  );

  static const AppPalette lilacDark = AppPalette(
    surface: Color(0xFF151419),
    onSurface: Color(0xFFE6E3EC),
    surfaceContainer: Color(0xFF201F27),
    onSurfaceVariant: Color(0xFFC5C0D0),
    primary: Color(0xFFBFB0F0),
    onPrimary: Color(0xFF281C4F),
    secondary: Color(0xFF95CDBB),
    onSecondary: Color(0xFF0E3629),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    outline: Color(0xFF8E8A98),
    menstrual: Color(0xFFFF9EB4),
    follicular: Color(0xFFBFB0F0),
    ovular: Color(0xFFE0CB84),
    luteal: Color(0xFF95CDBB),
  );

  static const AppPalette periLight = AppPalette(
    surface: Color(0xFFF3F6FC),
    onSurface: Color(0xFF1D2130),
    surfaceContainer: Color(0xFFDEE7F6),
    onSurfaceVariant: Color(0xFF454B5E),
    primary: Color(0xFF3A5793),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF8A5138),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFF9A2F2A),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFF636A7D),
    menstrual: Color(0xFF9A2F2A),
    follicular: Color(0xFF3A5793),
    ovular: Color(0xFF6B6012),
    luteal: Color(0xFF8A5138),
  );

  static const AppPalette periDark = AppPalette(
    surface: Color(0xFF12151C),
    onSurface: Color(0xFFE1E6F0),
    surfaceContainer: Color(0xFF1C202A),
    onSurfaceVariant: Color(0xFFBEC5D4),
    primary: Color(0xFFA9C4F5),
    onPrimary: Color(0xFF132845),
    secondary: Color(0xFFF5B49A),
    onSecondary: Color(0xFF4A2413),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    outline: Color(0xFF87909F),
    menstrual: Color(0xFFFF9E9E),
    follicular: Color(0xFFA9C4F5),
    ovular: Color(0xFFDCC77E),
    luteal: Color(0xFFF5B49A),
  );

  static const AppPalette inkLight = AppPalette(
    surface: Color(0xFFF7F6F4),
    onSurface: Color(0xFF1F1E1C),
    surfaceContainer: Color(0xFFE7E5E1),
    onSurfaceVariant: Color(0xFF4A4845),
    primary: Color(0xFF2E2C29),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF8A6410),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFF8A2E12),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFF6A6763),
    menstrual: Color(0xFF8A2E12),
    follicular: Color(0xFF2E2C29),
    ovular: Color(0xFF8A6410),
    luteal: Color(0xFF5A564F),
  );

  static const AppPalette inkDark = AppPalette(
    surface: Color(0xFF161513),
    onSurface: Color(0xFFE8E6E2),
    surfaceContainer: Color(0xFF201F1C),
    onSurfaceVariant: Color(0xFFC6C3BE),
    primary: Color(0xFFDAD6CE),
    onPrimary: Color(0xFF2A2825),
    secondary: Color(0xFFE6C378),
    onSecondary: Color(0xFF3C2C00),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    outline: Color(0xFF8F8C86),
    menstrual: Color(0xFFFFAA8A),
    follicular: Color(0xFFDAD6CE),
    ovular: Color(0xFFE6C378),
    luteal: Color(0xFFA9A49A),
  );

  static const AppPalette nightDark = AppPalette(
    surface: Color(0xFF141419),
    onSurface: Color(0xFFE7E5EC),
    surfaceContainer: Color(0xFF20202A),
    onSurfaceVariant: Color(0xFFC2BFCB),
    primary: Color(0xFFB9A7F0),
    onPrimary: Color(0xFF241A45),
    secondary: Color(0xFFF0B48D),
    onSecondary: Color(0xFF4C2609),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    outline: Color(0xFF8E8B98),
    menstrual: Color(0xFFFF9E9E),
    follicular: Color(0xFFB9A7F0),
    ovular: Color(0xFFE8CC7A),
    luteal: Color(0xFFF0B48D),
  );
}
