// Choosing what the app looks like (AND-39).
//
// The scheme is a preference and nothing more — no scheme unlocks a feature or
// changes a number — so what is worth pinning is that the choice is stored, is
// read back, survives a value this build does not know, and that the one scheme
// with no light half says so instead of leaving a control that does nothing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/palette.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/features/appearance/appearance_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      harness(const AppearanceScreen(), database: db, textScaler: textScaler),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapRow(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('the scheme picker', () {
    testWidgets('offers every scheme, and no more', (tester) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      final labels = <String>[
        l10n.appearanceSchemeRose,
        l10n.appearanceSchemeSage,
        l10n.appearanceSchemeLilac,
        l10n.appearanceSchemePeriwinkle,
        l10n.appearanceSchemeInk,
        l10n.appearanceSchemeNight,
      ];
      expect(labels, hasLength(AppScheme.values.length));
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets("stores the tap under the scheme's own name", (tester) async {
      await pump(tester);
      await tapRow(tester, l10nOf(tester).appearanceSchemeLilac);
      expect(
        await db.settingsDao.raw(SettingKey.colourScheme),
        AppScheme.lilac.wireName,
      );
    });

    testWidgets('marks the stored scheme rather than the first row', (
      tester,
    ) async {
      await db.settingsDao.writeString(
        SettingKey.colourScheme,
        AppScheme.ink.wireName,
      );
      await pump(tester);
      final l10n = l10nOf(tester);
      final marked =
          <String>[
            l10n.appearanceSchemeRose,
            l10n.appearanceSchemeSage,
            l10n.appearanceSchemeLilac,
            l10n.appearanceSchemePeriwinkle,
            l10n.appearanceSchemeInk,
            l10n.appearanceSchemeNight,
          ].where(
            (label) => find
                .ancestor(
                  of: find.text(label),
                  matching: find.byWidgetPredicate(
                    (w) => w is Semantics && (w.properties.selected ?? false),
                  ),
                )
                .evaluate()
                .isNotEmpty,
          );
      expect(marked, hasLength(1), reason: 'exactly one row is the chosen one');
      expect(
        find.ancestor(
          of: find.text(l10n.appearanceSchemeInk),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.selected ?? false),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back rather than throwing on an unknown name', (
      tester,
    ) async {
      // A database written by a later build must still open. The app failing
      // to start because of a colour would be absurd.
      await db.settingsDao.writeString(
        SettingKey.colourScheme,
        'chartreuse-and-neon',
      );
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.ancestor(
          of: find.text(l10nOf(tester).appearanceSchemeRose),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.selected ?? false),
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('the theme control', () {
    testWidgets('stores light, dark and system', (tester) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      for (final choice in <(String, ThemeMode)>[
        (l10n.appearanceThemeDark, ThemeMode.dark),
        (l10n.appearanceThemeLight, ThemeMode.light),
        (l10n.appearanceThemeSystem, ThemeMode.system),
      ]) {
        await tapRow(tester, choice.$1);
        expect(
          await db.settingsDao.raw(SettingKey.themeMode),
          choice.$2.name,
          reason: choice.$1,
        );
      }
    });

    testWidgets('says why it is unavailable under Night', (tester) async {
      // Night has no light half, so the control cannot do anything. A disabled
      // control with a sentence beside it beats one that silently ignores the
      // tap.
      await db.settingsDao.writeString(
        SettingKey.colourScheme,
        AppScheme.night.wireName,
      );
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.appearanceThemeLockedByScheme), findsOneWidget);
      final button = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(button.onSelectionChanged, isNull);
    });

    testWidgets('is available under every other scheme', (tester) async {
      for (final scheme in AppScheme.values.where((s) => !s.forcesDark)) {
        await db.settingsDao.writeString(
          SettingKey.colourScheme,
          scheme.wireName,
        );
        await pump(tester);
        final button = tester.widget<SegmentedButton<ThemeMode>>(
          find.byType(SegmentedButton<ThemeMode>),
        );
        expect(
          button.onSelectionChanged,
          isNotNull,
          reason: '${scheme.name} left the theme control dead',
        );
      }
    });
  });

  group('the app', () {
    testWidgets('reads the stored scheme and mode back out', (tester) async {
      await db.settingsDao.writeString(
        SettingKey.colourScheme,
        AppScheme.periwinkle.wireName,
      );
      await db.settingsDao.writeString(
        SettingKey.themeMode,
        ThemeMode.dark.name,
      );
      await pump(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppearanceScreen)),
      );
      expect(
        container.read(colourSchemeProvider).valueOrNull,
        AppScheme.periwinkle,
      );
      expect(container.read(themeModeProvider).valueOrNull, ThemeMode.dark);
    });

    testWidgets('survives a 200% text scale', (tester) async {
      await pump(tester, textScaler: const TextScaler.linear(2));
      expect(tester.takeException(), isNull);
    });
  });
}
