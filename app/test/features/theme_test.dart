// Contrast gate for the palette (AND-11, docs/PLAN.md 2.4.4).
//
// The ratios are recomputed from the tokens rather than asserted once by eye,
// so a colour cannot be nudged "just a little" without the suite noticing.
// AND-18 turns the same requirement into a CI gate over rendered widgets;
// checking the tokens themselves catches it a layer earlier, where the fix is
// one constant rather than a redesign.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('the light palette', () {
    test('meets 4.5:1 everywhere text sits', () {
      expectContrast(
        'onSurface on surface',
        AppColors.lightOnSurface,
        AppColors.lightSurface,
        4.5,
      );
      expectContrast(
        'onSurface on a card',
        AppColors.lightOnSurface,
        AppColors.lightSurfaceContainer,
        4.5,
      );
      expectContrast(
        'secondary text on surface',
        AppColors.lightOnSurfaceVariant,
        AppColors.lightSurface,
        4.5,
      );
      expectContrast(
        'secondary text on a card',
        AppColors.lightOnSurfaceVariant,
        AppColors.lightSurfaceContainer,
        4.5,
      );
      expectContrast(
        'button label',
        AppColors.lightOnPrimary,
        AppColors.lightPrimary,
        4.5,
      );
      expectContrast(
        'error label',
        AppColors.lightOnError,
        AppColors.lightError,
        4.5,
      );
    });

    test('meets 3:1 for controls and outlines', () {
      expectContrast(
        'primary against surface',
        AppColors.lightPrimary,
        AppColors.lightSurface,
        3,
      );
      expectContrast(
        'secondary against surface',
        AppColors.lightSecondary,
        AppColors.lightSurface,
        3,
      );
      expectContrast(
        'outline against surface',
        AppColors.lightOutline,
        AppColors.lightSurface,
        3,
      );
    });
  });

  group('the dark palette', () {
    test('meets 4.5:1 everywhere text sits', () {
      expectContrast(
        'onSurface on surface',
        AppColors.darkOnSurface,
        AppColors.darkSurface,
        4.5,
      );
      expectContrast(
        'onSurface on a card',
        AppColors.darkOnSurface,
        AppColors.darkSurfaceContainer,
        4.5,
      );
      expectContrast(
        'secondary text on surface',
        AppColors.darkOnSurfaceVariant,
        AppColors.darkSurface,
        4.5,
      );
      expectContrast(
        'secondary text on a card',
        AppColors.darkOnSurfaceVariant,
        AppColors.darkSurfaceContainer,
        4.5,
      );
      expectContrast(
        'button label',
        AppColors.darkOnPrimary,
        AppColors.darkPrimary,
        4.5,
      );
      expectContrast(
        'error label',
        AppColors.darkOnError,
        AppColors.darkError,
        4.5,
      );
    });

    test('meets 3:1 for controls and outlines', () {
      expectContrast(
        'primary against surface',
        AppColors.darkPrimary,
        AppColors.darkSurface,
        3,
      );
      expectContrast(
        'secondary against surface',
        AppColors.darkSecondary,
        AppColors.darkSurface,
        3,
      );
      expectContrast(
        'outline against surface',
        AppColors.darkOutline,
        AppColors.darkSurface,
        3,
      );
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
