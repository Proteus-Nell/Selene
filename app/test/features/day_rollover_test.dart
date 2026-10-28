// The prediction is recomputed when the app comes back on a new day
// (ADR-0016). A late period's range moves with the day, so a phone that kept
// the app alive overnight must not show yesterday's.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/models/prediction.dart';
import 'package:period_tracker/features/common/day_rollover.dart';

import 'harness.dart';

/// A clock whose day a test can move on.
final class _MovableClock implements Clock {
  _MovableClock(this.day);

  CivilDate day;

  @override
  CivilDate today() => day;

  @override
  DateTime nowUtc() => DateTime.utc(day.year, day.month, day.day, 9);
}

/// Shows the start of whatever window the prediction currently holds.
class _WindowStart extends ConsumerWidget {
  const _WindowStart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(predictionProvider).valueOrNull;
    final start = switch (result) {
      Predicted(:final prediction) => prediction.window80.start.toIso8601(),
      _ => 'none',
    };
    return Text(start, textDirection: TextDirection.ltr);
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> comeBack(WidgetTester tester) async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets('a moved range moves on with the day after a return', (
    tester,
  ) async {
    // Day 31 of six 28-day cycles: a day past the window, so the range shown
    // has moved forward to start today.
    final clock = _MovableClock(testClock.today());
    await seedHistory(db, const <int>[
      28,
      28,
      28,
      28,
      28,
      28,
    ], endingDaysAgo: 27);
    await tester.pumpWidget(
      harness(
        const DayRollover(child: _WindowStart()),
        database: db,
        clock: clock,
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.widget<Text>(find.byType(Text)).data!;
    expect(
      CivilDate.parseIso8601(first),
      greaterThanOrEqualTo(clock.today()),
    );

    // Coming back the same day changes nothing.
    await comeBack(tester);
    expect(tester.widget<Text>(find.byType(Text)).data, first);

    // Coming back two days later moves the range on with it.
    clock.day = clock.day.addDays(2);
    await comeBack(tester);
    final later = tester.widget<Text>(find.byType(Text)).data!;
    expect(
      CivilDate.parseIso8601(later),
      greaterThanOrEqualTo(clock.today()),
    );
    expect(
      CivilDate.parseIso8601(later),
      greaterThan(CivilDate.parseIso8601(first)),
    );
  });
}
