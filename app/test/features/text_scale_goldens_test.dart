// Text-scale goldens (AND-18, docs/PLAN.md 2.4.4).
//
// "Usable to 200%" is the requirement, and most Flutter layouts break well
// before that: a fixed-height row, a Row of un-wrapped Text, or a calendar cell
// that is a fixed square all clip or overflow. The widget tests elsewhere
// assert that nothing throws; these capture what it actually looks like, so a
// regression that merely makes the screen unreadable rather than throwing still
// shows up in review as a changed image.
//
// Generated on linux-x64 with the pinned Flutter version, which is what CI
// runs. A mismatch on another platform means regenerate, not debug.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/features/calendar/calendar_screen.dart';
import 'package:period_tracker/features/insights/insights_screen.dart';
import 'package:period_tracker/features/log/log_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  /// The three scales the plan names. 1.0 is the baseline the others are read
  /// against; without it a break at 1.5 looks like a scaling bug when it is
  /// really a layout one.
  // Keyed by label rather than by the double: a const map cannot use a double
  // as a key, because doubles have no primitive equality.
  const scales = <String, double>{'100': 1, '150': 1.5, '200': 2};

  final screens = <String, Widget>{
    'log': const LogScreen(),
    'calendar': const CalendarScreen(),
    'insights': const InsightsScreen(),
  };

  for (final screen in screens.entries) {
    for (final scale in scales.entries) {
      testWidgets('${screen.key} at ${scale.key}% text scale', (
        tester,
      ) async {
        await seedHistory(db, const <int>[28, 29, 28, 30, 28, 29, 28]);
        await tester.pumpWidget(
          harness(
            screen.value,
            database: db,
            textScaler: TextScaler.linear(scale.value),
          ),
        );
        await tester.pumpAndSettle();

        // An overflow throws during paint, so this catches the hard failures
        // before the image comparison catches the soft ones.
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(screen.value.runtimeType),
          matchesGoldenFile(
            'goldens/${screen.key}_text_${scale.key}.png',
          ),
        );
      });
    }
  }
}
