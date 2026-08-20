// Pop-ups have to go away by themselves.
//
// Flutter's SnackBar constructor reads `persist = persist ?? action != null`,
// so every snack bar carrying an action defaults to never timing out: the timer
// fires, sees `persist`, and returns without hiding anything. Logging a period
// therefore left "Period logged" on screen indefinitely, and the only way out
// was to swipe it. A confirmation that has to be dismissed by hand costs more
// attention than it conveys.
//
// Asserted through the real screens rather than the helper alone, because the
// defect was in the default a call site inherited, not in any logic.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/common/snack.dart';
import 'package:period_tracker/features/log/log_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  /// Taps the primary action and returns once the pop-up is on screen.
  Future<void> logAndConfirm(WidgetTester tester) async {
    await tester.tap(find.text(l10nOf(tester).logPeriodStartedToday));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: 'nothing confirmed the tap',
    );
  }

  group('a confirmation with an action', () {
    testWidgets('leaves on its own', (tester) async {
      await tester.pumpWidget(harness(const LogScreen(), database: db));
      await tester.pumpAndSettle();
      await logAndConfirm(tester);

      // Undo is worth offering for longer than a bare acknowledgement, but not
      // for ever: this is the assertion that fails against Flutter's default.
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'the pop-up is still there and must be swiped away by hand',
      );
    });

    testWidgets('offers undo for long enough to reach for it', (tester) async {
      await tester.pumpWidget(harness(const LogScreen(), database: db));
      await tester.pumpAndSettle();
      await logAndConfirm(tester);

      // Read the sentence, decide it was a mistake, reach for the button. Four
      // seconds is enough to read and not enough to change your mind.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text(l10nOf(tester).commonUndo), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });

  group('with a screen reader', () {
    testWidgets('it waits, because the action has to be navigated to', (
      tester,
    ) async {
      // The one case where persisting is right, and the behaviour Flutter's own
      // documentation describes: an action nobody can reach in seven seconds is
      // an action they never had.
      await tester.pumpWidget(
        harness(const LogScreen(), database: db, accessibleNavigation: true),
      );
      await tester.pumpAndSettle();
      await logAndConfirm(tester);

      await tester.pump(const Duration(seconds: 20));
      expect(find.byType(SnackBar), findsOneWidget);

      // And it is dismissible deliberately rather than only by swipe, so a
      // pop-up that will not leave on its own always has a way out.
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.showCloseIcon, isTrue);
      expect(bar.persist, isTrue);
    });

    testWidgets('a plain confirmation still leaves', (tester) async {
      // Nothing to reach for, so nothing to wait for. Persisting here would
      // leave a screen-reader user with a pop-up and no reason for it.
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showAppSnackBar(context, 'Saved'),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
          database: db,
          accessibleNavigation: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pump();
      // Long enough for the entrance animation to finish. The auto-hide timer
      // is armed in the build that follows it, so a test that jumps straight
      // past the duration never arms one and reads as a stuck pop-up.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  test('every pop-up in the app goes through the helper', () {
    // The defect was a default inherited at a call site, so the guard is that
    // there are no call sites to inherit it. Enforced rather than reviewed:
    // this is exactly the kind of rule that decays one hurried fix at a time.
    final offenders = <String>[];
    for (final file
        in Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      if (file.path.endsWith('common/snack.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('showSnackBar(')) offenders.add(file.path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These call showSnackBar directly and will inherit persist: true if '
          'they pass an action. Use showAppSnackBar:\n${offenders.join("\n")}',
    );
  });
}
