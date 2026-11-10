// The lock in front of editing a past day (ADR-0027).
//
// The rules are here rather than in the widget test because they are about
// time, and time is the one thing a widget test cannot step through cheaply:
// the stand-down lasts half an hour and the bulk-edit window is ten minutes.
// PastEditGuard takes both instants as arguments, so this file walks a
// timeline in a few lines and the widget test only has to prove the sheet
// asks the guard.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/features/today/past_edit_guard.dart';

void main() {
  final today = CivilDate(2026, 11, 10);
  final yesterday = today.addDays(-1);
  final tomorrow = today.addDays(1);
  final noon = DateTime.utc(2026, 11, 10, 12);

  group('the lock', () {
    test('is on a past day', () {
      const guard = PastEditGuard();
      expect(guard.locks(yesterday, today: today, now: noon), isTrue);
      expect(
        guard.locks(today.addDays(-30), today: today, now: noon),
        isTrue,
      );
    });

    test('is not on today, which is what the screen is for', () {
      // Asking about the day the Today tab is named after would be noise.
      const guard = PastEditGuard();
      expect(guard.locks(today, today: today, now: noon), isFalse);
    });

    test('is not on a future day, which cannot be written at all', () {
      // CycleRepository refuses a future-dated write, so there is nothing for
      // a lock to protect and the sheet offers no editor either.
      const guard = PastEditGuard();
      expect(guard.locks(tomorrow, today: today, now: noon), isFalse);
    });
  });

  group('the offer to stop asking', () {
    /// A guard that has had [days] distinct days changed, a minute apart,
    /// ending at [end].
    PastEditGuard afterChanging(int days, {required DateTime end}) {
      var guard = const PastEditGuard();
      for (var i = 0; i < days; i++) {
        guard = guard.changed(
          today.addDays(-1 - i),
          end.subtract(Duration(minutes: days - 1 - i)),
        );
      }
      return guard;
    }

    test('does not appear for a single correction', () {
      final guard = afterChanging(1, end: noon);
      expect(guard.recentlyChanged(noon), 1);
      expect(guard.offersStandDown(noon), isFalse);
    });

    test('does not appear at exactly three days', () {
      // Three is a correction; four is a sitting. The threshold is "more
      // than", so three must not trip it.
      final guard = afterChanging(3, end: noon);
      expect(guard.recentlyChanged(noon), 3);
      expect(guard.offersStandDown(noon), isFalse);
    });

    test('appears once more than three days have been changed', () {
      final guard = afterChanging(4, end: noon);
      expect(guard.recentlyChanged(noon), 4);
      expect(guard.offersStandDown(noon), isTrue);
    });

    test('counts a day once however often it is changed', () {
      var guard = const PastEditGuard();
      for (var i = 0; i < 5; i++) {
        guard = guard.changed(yesterday, noon.add(Duration(seconds: i)));
      }
      expect(guard.recentlyChanged(noon.add(const Duration(seconds: 5))), 1);
    });

    test('forgets days that fall out of the ten minutes', () {
      // Four days changed, but spread over half an hour: that is someone
      // using the app normally, not catching up.
      var guard = const PastEditGuard();
      for (var i = 0; i < 4; i++) {
        guard = guard.changed(
          today.addDays(-1 - i),
          noon.subtract(Duration(minutes: 30 - i * 10)),
        );
      }
      expect(guard.offersStandDown(noon), isFalse);
    });

    test('drops stale days as it records, so the map cannot grow forever', () {
      var guard = const PastEditGuard();
      for (var i = 0; i < 50; i++) {
        guard = guard.changed(
          today.addDays(-1 - i),
          noon.add(Duration(minutes: i)),
        );
      }
      // A minute apart, so only the last ten minutes' worth survive.
      expect(guard.changes.length, lessThanOrEqualTo(11));
    });
  });

  group('standing down', () {
    test('takes the lock off every past day', () {
      final guard = const PastEditGuard().standingDownFrom(noon);
      expect(guard.locks(yesterday, today: today, now: noon), isFalse);
      expect(
        guard.locks(today.addDays(-200), today: today, now: noon),
        isFalse,
      );
    });

    test('lasts half an hour and then stops, without being asked', () {
      final guard = const PastEditGuard().standingDownFrom(noon);
      final justBefore = noon.add(const Duration(minutes: 29, seconds: 59));
      final after = noon.add(const Duration(minutes: 30, seconds: 1));
      expect(guard.locks(yesterday, today: today, now: justBefore), isFalse);
      expect(guard.locks(yesterday, today: today, now: after), isTrue);
    });

    test('is not offered again while it is in force', () {
      // The offer is for getting past the lock, and there is no lock to get
      // past, so showing it would be offering something already true.
      var guard = const PastEditGuard();
      for (var i = 0; i < 4; i++) {
        guard = guard.changed(today.addDays(-1 - i), noon);
      }
      expect(guard.offersStandDown(noon), isTrue);
      expect(guard.standingDownFrom(noon).offersStandDown(noon), isFalse);
    });

    test('is offered again once it has expired', () {
      var guard = const PastEditGuard().standingDownFrom(noon);
      final after = noon.add(const Duration(minutes: 31));
      for (var i = 0; i < 4; i++) {
        guard = guard.changed(today.addDays(-1 - i), after);
      }
      expect(guard.offersStandDown(after), isTrue);
    });

    test('has no permanent form', () {
      // Deliberate: there is no "never ask again", and nothing persists it,
      // so the guard is always back by the next time the app is opened.
      expect(PastEditGuard.standDown, const Duration(minutes: 30));
      expect(PastEditGuard.bulkWindow, const Duration(minutes: 10));
      expect(PastEditGuard.bulkThreshold, 3);
    });
  });
}
