// Contrast gate for every palette the app can wear (AND-11, AND-39,
// docs/PLAN.md 2.4.4).
//
// The ratios are recomputed from the tokens rather than asserted once by eye,
// so a colour cannot be nudged "just a little" without the suite noticing.
// AND-18 turns the same requirement into a CI gate over rendered widgets;
// checking the tokens themselves catches it a layer earlier, where the fix is
// one constant rather than a redesign.
//
// Since AND-39 there are six schemes and eleven palettes rather than two, and
// the loop below is deliberate: a gate that covered only the default would let
// the other five ship unmeasured, which is how a scheme picker becomes an
// accessibility regression with a settings toggle in front of it.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/palette.dart';
import 'package:period_tracker/core/theme.dart';

/// WCAG relative luminance.
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Every palette, each named for the failure message.
Map<String, AppPalette> _allPalettes() {
  final palettes = <String, AppPalette>{};
  for (final scheme in AppScheme.values) {
    palettes['${scheme.name} light'] = scheme.light;
    palettes['${scheme.name} dark'] = scheme.dark;
  }
  return palettes;
}

void main() {
  /// Body text needs 4.5:1; a control or a large label needs 3:1.
  void expectContrast(
    String label,
    Color foreground,
    Color background,
    double minimum,
  ) {
    final ratio = contrast(foreground, background);
    expect(
      ratio,
      greaterThanOrEqualTo(minimum),
      reason: '$label is ${ratio.toStringAsFixed(2)}:1, needs $minimum:1',
    );
  }

  _allPalettes().forEach((name, palette) {
    group('the $name palette', () {
      test('meets 4.5:1 everywhere text sits', () {
        expectContrast(
          '$name: onSurface on surface',
          palette.onSurface,
          palette.surface,
          4.5,
        );
        expectContrast(
          '$name: onSurface on a card',
          palette.onSurface,
          palette.surfaceContainer,
          4.5,
        );
        expectContrast(
          '$name: secondary text on surface',
          palette.onSurfaceVariant,
          palette.surface,
          4.5,
        );
        expectContrast(
          '$name: secondary text on a card',
          palette.onSurfaceVariant,
          palette.surfaceContainer,
          4.5,
        );
        expectContrast(
          '$name: button label',
          palette.onPrimary,
          palette.primary,
          4.5,
        );
        expectContrast(
          '$name: secondary button label',
          palette.onSecondary,
          palette.secondary,
          4.5,
        );
        expectContrast(
          '$name: error label',
          palette.onError,
          palette.error,
          4.5,
        );
      });

      test('meets 3:1 for controls and outlines', () {
        expectContrast(
          '$name: primary against surface',
          palette.primary,
          palette.surface,
          // 4.5 rather than 3, because primary is used as *text* and not only
          // as a control: the phase line in the middle of the cycle ring is
          // painted in it. That line used to take the phase's own colour and
          // Rose & Plum's follicular pink reaches 3.51 against its surface —
          // fine for an arc, not for eleven-pixel bold caps (AND-39).
          4.5,
        );
        expectContrast(
          '$name: secondary against surface',
          palette.secondary,
          palette.surface,
          3,
        );
        expectContrast(
          '$name: error against surface',
          palette.error,
          palette.surface,
          3,
        );
        expectContrast(
          '$name: outline against surface',
          palette.outline,
          palette.surface,
          3,
        );
      });

      test('meets 3:1 for every phase mark, on both grounds', () {
        // A ring arc and a legend swatch are graphical objects, so 3:1 is the
        // applicable floor (WCAG 1.4.11) rather than 4.5. Both grounds are
        // checked because the same four colours are used flat on the page and
        // inside a card.
        //
        // 3:1 is only enough while these stay marks. Two of them do not reach
        // 4.5 against their own surface, so a phase colour must never be used
        // for text — the swatch beside a label, never the label.
        const labels = <String>['menstrual', 'follicular', 'ovular', 'luteal'];
        final colors = palette.phaseColors;
        for (var i = 0; i < colors.length; i++) {
          expectContrast(
            '$name: ${labels[i]} on surface',
            colors[i],
            palette.surface,
            3,
          );
          expectContrast(
            '$name: ${labels[i]} on a card',
            colors[i],
            palette.surfaceContainer,
            3,
          );
        }
      });

      test('separates the card from the page it sits on', () {
        // Cards carry no elevation in this app, so the fill is the only thing
        // distinguishing one from the page. It does not need 3:1 — it is not
        // carrying information, the text inside it is — but it does need to be
        // visibly a different colour.
        expect(
          contrast(palette.surfaceContainer, palette.surface),
          greaterThan(1.05),
          reason: '$name: a card is indistinguishable from the page',
        );
      });
    });
  });

  group('the schemes', () {
    test('each store under a distinct name', () {
      final names = AppScheme.values.map((s) => s.wireName).toSet();
      expect(names.length, AppScheme.values.length);
    });

    test('survive a stored name this build does not have', () {
      // A database written by a later build must still open. Falling back is
      // the only sane answer; throwing would be an app that will not start
      // because of a colour.
      expect(AppScheme.fromWireName('chartreuse'), AppScheme.fallback);
      expect(AppScheme.fromWireName(null), AppScheme.fallback);
      for (final scheme in AppScheme.values) {
        expect(AppScheme.fromWireName(scheme.wireName), scheme);
      }
    });

    test('are dark-first only where they say so', () {
      // Night is the one scheme with no light half, and `forcesDark` is what
      // stops the theme control silently doing nothing.
      for (final scheme in AppScheme.values) {
        expect(
          identical(scheme.light, scheme.dark),
          scheme.forcesDark,
          reason: '${scheme.name}: forcesDark disagrees with its palettes',
        );
      }
      expect(AppScheme.night.forcesDark, isTrue);
    });

    test('reach a widget through the theme', () {
      // The phase colours travel on ThemeData rather than as a global, because
      // since AND-39 there is no single answer to what they are.
      for (final scheme in AppScheme.values) {
        expect(
          AppTheme.light(scheme).extension<PhaseColors>()?.menstrual,
          scheme.light.menstrual,
        );
        expect(
          AppTheme.dark(scheme).extension<PhaseColors>()?.luteal,
          scheme.dark.luteal,
        );
      }
    });
  });

  group('both themes', () {
    test('actually differ, so dark mode is not light mode repainted', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
      expect(
        AppTheme.light().colorScheme.surface,
        isNot(AppTheme.dark().colorScheme.surface),
      );
    });

    test('default to the scheme a fresh install wears', () {
      expect(
        AppTheme.light().colorScheme.primary,
        AppScheme.fallback.light.primary,
      );
      expect(AppScheme.fallback, AppScheme.rose);
    });

    test('push every interactive default to the 48dp floor', () {
      // Set once in the theme rather than at each call site, because the call
      // site is where it gets forgotten (2.4.4).
      for (final theme in <ThemeData>[AppTheme.light(), AppTheme.dark()]) {
        expect(
          theme.filledButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
          const Size(AppTheme.minTapTarget, AppTheme.minTapTarget),
        );
        expect(
          theme.iconButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
          const Size(AppTheme.minTapTarget, AppTheme.minTapTarget),
        );
      }
      expect(AppTheme.minTapTarget, greaterThanOrEqualTo(48));
    });
  });
}
