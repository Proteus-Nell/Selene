// Recording intercourse (AND-30).
//
// The most sensitive field the app stores, so the tests are less about the
// happy path than about the three ways this could quietly become something the
// user did not agree to:
//
//   * recording an answer on their behalf — there is no "none" value, and null
//     means "not recorded", which is a different statement from either answer;
//   * making it un-take-back-able — a recorded answer has to be clearable;
//   * broadcasting it — the calendar marker says something was logged and
//     never which answer, and so does the screen reader.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/calendar/calendar_screen.dart';
import 'package:period_tracker/features/calendar/day_cell.dart';
import 'package:period_tracker/features/log/log_screen.dart';
import 'package:period_tracker/features/onboarding/onboarding_screen.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> pumpLog(WidgetTester tester) async {
    await tester.pumpWidget(harness(const LogScreen(), database: db));
    await tester.pumpAndSettle();
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.scrollUntilVisible(finder, 120);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('the control', () {
    testWidgets('records nothing until it is touched', (tester) async {
      // Nothing recorded is the default and must stay distinguishable from a
      // recorded answer. An app that stored "no" on the user's behalf would be
      // asserting something about their private life that they never said.
      await pumpLog(tester);
      expect(await db.dayLogDao.allLogs(), isEmpty);
    });

    testWidgets('records what was tapped', (tester) async {
      await pumpLog(tester);
      await tapChip(tester, l10nOf(tester).logIntercourseProtected);

      final logs = await db.dayLogDao.allLogs();
      expect(logs, hasLength(1));
      expect(logs.single.intercourse, Intercourse.protected);
    });

    testWidgets('a day whose only content is this is still stored', (
      tester,
    ) async {
      // isEmpty counts the field, so the editor cannot accept the tap and then
      // silently discard it on write.
      await pumpLog(tester);
      await tapChip(tester, l10nOf(tester).logIntercourseUnprotected);

      final logs = await db.dayLogDao.allLogs();
      expect(logs, hasLength(1));
      expect(logs.single.flow, FlowIntensity.none);
      expect(logs.single.intercourse, Intercourse.unprotected);
    });

    testWidgets('tapping the same answer again clears it', (tester) async {
      // There has to be a way back to having said nothing. Without this the app
      // is one that, once told, cannot be untold.
      await pumpLog(tester);
      final label = l10nOf(tester).logIntercourseProtected;
      await tapChip(tester, label);
      expect((await db.dayLogDao.allLogs()).single.intercourse, isNotNull);

      await tapChip(tester, label);
      // The day carried nothing else, so clearing it removes the row entirely
      // rather than storing an empty one.
      expect(await db.dayLogDao.allLogs(), isEmpty);
    });

    testWidgets('switching between the two answers replaces rather than adds', (
      tester,
    ) async {
      await pumpLog(tester);
      final l10n = l10nOf(tester);
      await tapChip(tester, l10n.logIntercourseProtected);
      await tapChip(tester, l10n.logIntercourseUnprotected);

      expect(
        (await db.dayLogDao.allLogs()).single.intercourse,
        Intercourse.unprotected,
      );
    });

    testWidgets('says it is optional and not used for predictions', (
      tester,
    ) async {
      // Both facts stated before the user touches it. They would otherwise
      // reasonably assume it feeds the model, since everything else here does.
      await pumpLog(tester);
      final hint = l10nOf(tester).logIntercourseHint.toLowerCase();
      expect(hint, contains('optional'));
      expect(hint, contains('not used for predictions'));
    });

    testWidgets('offers no third "not recorded" option', (tester) async {
      // Null is the absence of an answer, not an answer. A third chip would
      // make "I did not say" into something the user has to say.
      await pumpLog(tester);
      expect(Intercourse.values, hasLength(2));
    });
  });

  group('the calendar', () {
    Future<void> pumpCalendar(WidgetTester tester) async {
      await tester.pumpWidget(harness(const CalendarScreen(), database: db));
      await tester.pumpAndSettle();
    }

    testWidgets('marks the day, without saying which answer', (tester) async {
      // A calendar is the easiest screen in the app to read over a shoulder.
      // The marker exists so the user can find the day again, not so the grid
      // can broadcast what happened on it.
      await db.dayLogDao.save(
        DayLog(
          date: testClock.today(),
          intercourse: Intercourse.unprotected,
        ),
      );
      await pumpCalendar(tester);

      expect(
        find.descendant(
          of: find.byType(DayCell),
          matching: find.byType(IntercourseMarker),
        ),
        findsOneWidget,
      );
      // Neither answer appears anywhere on the screen.
      final l10n = l10nOf(tester);
      expect(find.text(l10n.logIntercourseUnprotected), findsNothing);
      expect(find.text(l10n.logIntercourseProtected), findsNothing);
    });

    testWidgets('the screen reader is told the same, and no more', (
      tester,
    ) async {
      // A screen reader is audible to whoever is in the room, so it says less
      // than the database knows, deliberately.
      final handle = tester.ensureSemantics();
      await db.dayLogDao.save(
        DayLog(
          date: testClock.today(),
          intercourse: Intercourse.unprotected,
        ),
      );
      await pumpCalendar(tester);

      final cell = find.byWidgetPredicate(
        (widget) => widget is DayCell && widget.date == testClock.today(),
      );
      final label = tester.getSemantics(cell).label.toLowerCase();
      expect(label, contains('intercourse'));
      expect(
        label,
        isNot(contains('unprotected')),
        reason: 'the screen reader announces which answer was recorded',
      );
      handle.dispose();
    });

    testWidgets('no marker where nothing was recorded', (tester) async {
      await db.dayLogDao.save(
        DayLog(date: testClock.today(), flow: FlowIntensity.heavy),
      );
      await pumpCalendar(tester);
      expect(
        find.descendant(
          of: find.byType(DayCell),
          matching: find.byType(IntercourseMarker),
        ),
        findsNothing,
      );
    });

    testWidgets('the legend names it, so the marker is not a mystery', (
      tester,
    ) async {
      await pumpCalendar(tester);
      final legend = find.text(l10nOf(tester).calendarLegendIntercourse);
      await tester.scrollUntilVisible(legend, 200);
      await tester.pumpAndSettle();
      expect(legend, findsOneWidget);
    });
  });

  group('onboarding', () {
    testWidgets('names it before the user has recorded anything', (
      tester,
    ) async {
      // PLAN 6.5 says to treat this data as if it will be read by someone the
      // user did not choose. The corollary is that they get to know which field
      // carries the most risk before deciding whether to use it.
      await tester.pumpWidget(
        harness(OnboardingScreen(onFinished: () {}), database: db),
      );
      await tester.pumpAndSettle();

      final title = find.text(l10nOf(tester).onboardingSensitiveTitle);
      await tester.scrollUntilVisible(title, 200);
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);

      final body = l10nOf(tester).onboardingSensitiveBody.toLowerCase();
      expect(body, contains('most sensitive'));
      expect(
        body,
        contains('never used to predict'),
        reason: 'the disclosure does not say it is kept out of the model',
      );
      expect(
        body,
        contains('app lock'),
        reason:
            'the disclosure names the risk without naming the remedy, which '
            'leaves the user worried and with nothing to do about it',
      );
    });
  });
}
