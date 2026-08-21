// The lookup screen (AND-32).
//
// The screen holds two bodies of text with different provenance, and most of
// what is tested here is that it keeps them apart. The medicines are a dated
// snapshot of a regulator's own words; the hygiene entries are hand-written for
// this app. Presenting the second as though it were the first would be
// borrowing an authority we do not have (ADR-0009).
//
// The other half is the urgent entry. TSS is the one thing on this page anyone
// might need within the hour, and a page where it is styled like reference
// reading is a page where it is not found.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/features/lookup/lookup_screen.dart';

import '../harness.dart';

File _repoFile(String relativePath) {
  var directory = Directory.current.absolute;
  for (var depth = 0; depth < 5; depth++) {
    final candidate = File('${directory.path}/$relativePath');
    if (candidate.existsSync()) return candidate;
    directory = directory.parent;
  }
  throw StateError('could not find $relativePath');
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(harness(const LookupScreen(), database: db));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String term) async {
    await tester.enterText(find.byType(TextField), term);
    await tester.pumpAndSettle();
  }

  /// Scrolls the page — not the search field — until [finder] is on screen.
  ///
  /// The screen has two scrollables: the outer ListView and the TextField's
  /// own. `scrollUntilVisible` picks the wrong one by default and fails with a
  /// bare "Bad state: No element", which reads as a missing widget rather than
  /// as a mis-aimed scroll.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('the screen', () {
    testWidgets('says nothing typed here leaves the device', (tester) async {
      // A user typing a drug name into a search box has every reason to assume
      // it goes somewhere. Here it does not, and only the screen can say so.
      await pump(tester);
      final subtitle = l10nOf(tester).lookupSubtitle.toLowerCase();
      expect(find.text(l10nOf(tester).lookupSubtitle), findsOneWidget);
      expect(subtitle, contains('nothing you type here is sent anywhere'));
    });

    testWidgets('shows the hygiene entries with no query', (tester) async {
      await pump(tester);
      expect(find.text(l10nOf(tester).hygieneTssTitle), findsOneWidget);
      expect(find.text(l10nOf(tester).hygieneTamponsTitle), findsOneWidget);
    });

    testWidgets('marks the curated entries as curated', (tester) async {
      // The provenance distinction, on screen. These are our words; the
      // medicines are a regulator's.
      await pump(tester);
      final note = l10nOf(tester).lookupCuratedNote.toLowerCase();
      expect(find.text(l10nOf(tester).lookupCuratedNote), findsOneWidget);
      expect(
        note,
        contains("not a regulator's own wording"),
        reason: 'the screen no longer distinguishes curated from sourced text',
      );
    });
  });

  group('toxic shock syndrome', () {
    testWidgets('is first, above the other entries', (tester) async {
      // It is the only thing on this page anyone might need within the hour.
      await pump(tester);
      final tss = tester.getTopLeft(find.text(l10nOf(tester).hygieneTssTitle));
      final tampons = tester.getTopLeft(
        find.text(l10nOf(tester).hygieneTamponsTitle),
      );
      expect(tss.dy, lessThan(tampons.dy));
    });

    testWidgets('leads with what to do, not with what it is', (tester) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      final action = tester.getTopLeft(find.text(l10n.hygieneTssUrgent));
      final explanation = tester.getTopLeft(find.text(l10n.hygieneTssBody));
      expect(
        action.dy,
        lessThan(explanation.dy),
        reason:
            'the explanation comes before the instruction, so someone '
            'scanning in a hurry reads the definition first',
      );
    });

    testWidgets('is found by the words a frightened person would type', (
      tester,
    ) async {
      // Nobody types "toxic shock syndrome" when they have a fever and a
      // tampon in. A search that only matched titles would fail the person in
      // the most hurry.
      for (final term in <String>['tss', 'fever', 'rash']) {
        await pump(tester);
        await search(tester, term);
        expect(
          find.text(l10nOf(tester).hygieneTssTitle),
          findsOneWidget,
          reason: 'searching "$term" did not find it',
        );
      }
    });
  });

  group('searching', () {
    testWidgets('narrows to what matches', (tester) async {
      await pump(tester);
      await search(tester, 'cup');
      expect(find.text(l10nOf(tester).hygieneCupsTitle), findsOneWidget);
      expect(find.text(l10nOf(tester).hygieneTamponsTitle), findsNothing);
    });

    testWidgets('is case insensitive', (tester) async {
      await pump(tester);
      await search(tester, 'TAMPON');
      expect(find.text(l10nOf(tester).hygieneTamponsTitle), findsOneWidget);
    });

    testWidgets('offers the browser when nothing matches', (tester) async {
      // The point of the hand-off: having somewhere to go when it is not here.
      await pump(tester);
      await search(tester, 'something nobody bundled');
      final offer = find.text(l10nOf(tester).lookupSearchOnlineAction);
      await reveal(tester, offer);
      expect(offer, findsOneWidget);
    });
  });

  group('the medicines section', () {
    testWidgets('always says it is US labelling, or says why it is absent', (
      tester,
    ) async {
      // Always, not only when a US user is detected — the app has no way to
      // detect anything, and a reader applying US warnings to a box bought
      // elsewhere is being quietly misinformed.
      await pump(tester);
      final l10n = l10nOf(tester);
      final expected = medicinesFetched
          ? l10n.lookupMedicinesUsOnly
          : l10n.lookupMedicinesUnavailable;
      final finder = find.text(expected);
      await reveal(tester, finder);
      expect(finder, findsOneWidget);
    });

    testWidgets('explains itself when the artifact was never fetched', (
      tester,
    ) async {
      // The state this repository ships in until someone runs --fetch. An
      // empty list would read as a broken screen.
      if (medicinesFetched) {
        markTestSkipped('the artifact has been fetched');
        return;
      }
      await pump(tester);

      // Checked before scrolling: the rest of the screen still works, rather
      // than the whole page failing because one section has no data. After
      // scrolling to the medicines section the ListView has disposed the
      // hygiene cards, so asserting it afterwards would fail for the wrong
      // reason.
      expect(find.text(l10nOf(tester).hygieneTssTitle), findsOneWidget);

      final finder = find.text(l10nOf(tester).lookupMedicinesUnavailable);
      await reveal(tester, finder);
      expect(finder, findsOneWidget);
    });

    testWidgets("carries openFDA's disclaimer", (tester) async {
      await pump(tester);
      final finder = find.text(medicinesDisclaimer);
      await reveal(tester, finder);
      expect(finder, findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('survives a 200% text scale', (tester) async {
      await tester.pumpWidget(
        harness(
          const LookupScreen(),
          database: db,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('HYGIENE_SOURCES.md', () {
    test('exists and covers every curated entry', () {
      // An uncited health claim in a health app is what this file exists to
      // make impossible, and TSS is the claim where it matters most.
      final sources = _repoFile('docs/HYGIENE_SOURCES.md').readAsStringSync();
      for (final subject in <String>[
        'Toxic shock syndrome',
        'Tampons',
        'Menstrual cups',
        'Pads',
      ]) {
        expect(
          sources,
          contains(subject),
          reason: '$subject is on the screen but not in the sources file',
        );
      }
    });

    test('tracks what has not been verified yet', () {
      final sources = _repoFile('docs/HYGIENE_SOURCES.md').readAsStringSync();
      final outstanding = RegExp(r'\[VERIFY\]').allMatches(sources).length;
      // Printing is the point: this is a status report to whoever runs the
      // suite, not an assertion. A failing test would be the wrong instrument,
      // because reading the sources is a release task, not a per-commit one.
      // ignore: avoid_print
      print(
        outstanding == 0
            ? 'All hygiene claims are verified.'
            : '$outstanding hygiene claim(s) still marked [VERIFY]. '
                  'RELEASE.md must not pass while any remain.',
      );
      expect(outstanding, greaterThanOrEqualTo(0));
    });
  });
}
