import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';

void main() {
  group('FixedClock', () {
    test('reports the date it was frozen at', () {
      final clock = FixedClock(CivilDate(2026, 8, 17));
      expect(clock.today(), CivilDate(2026, 8, 17));
      expect(clock.today(), CivilDate(2026, 8, 17), reason: 'stable on reread');
    });

    test('iso constructor parses the day', () {
      expect(FixedClock.iso('2024-02-29').today(), CivilDate(2024, 2, 29));
      expect(FixedClock.iso('2026-08-17').today(), CivilDate(2026, 8, 17));
      // 2026 is not a leap year, so 29 February is not a real date and must be
      // rejected rather than silently rolled into March.
      expect(() => FixedClock.iso('2026-02-29'), throwsArgumentError);
    });

    test('advanced returns a new clock and leaves the original alone', () {
      final clock = FixedClock(CivilDate(2026, 8, 17));
      final later = clock.advanced(28);
      expect(later.today(), CivilDate(2026, 9, 14));
      expect(clock.today(), CivilDate(2026, 8, 17));
    });

    test('advancing backwards works', () {
      final clock = FixedClock(CivilDate(2026, 1, 1));
      expect(clock.advanced(-1).today(), CivilDate(2025, 12, 31));
    });

    test('nowUtc is in UTC', () {
      expect(FixedClock(CivilDate(2026, 8, 17)).nowUtc().isUtc, isTrue);
    });
  });

  group('SystemClock', () {
    test('today agrees with the local calendar day', () {
      const clock = SystemClock();
      final expected = CivilDate.fromDateTime(clock.nowUtc().toLocal());
      expect(clock.today(), expected);
    });

    test('nowUtc is in UTC', () {
      expect(const SystemClock().nowUtc().isUtc, isTrue);
    });
  });

  test('FixedClock is substitutable for SystemClock', () {
    // The whole point of the abstraction: anything taking a Clock can be
    // handed either, so date-dependent logic is testable without waiting.
    final clocks = <Clock>[const SystemClock(), FixedClock.iso('2026-08-17')];
    for (final clock in clocks) {
      expect(clock.today(), isA<CivilDate>());
      expect(clock.nowUtc(), isA<DateTime>());
    }
  });
}
