import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';

/// Stand-in enum for a state field.
enum _Confidence { high, medium, low }

RingLogger _logger({int capacity = 500}) =>
    RingLogger(clock: FixedClock(CivilDate(2026, 8, 17)), capacity: capacity);

void main() {
  group('privacy by construction', () {
    // These tests document a compile-time guarantee rather than a runtime one.
    //
    // LogEvent is an enum, so an event name cannot carry interpolated user data
    // the way a String could (`'period_started_$date'` does not typecheck).
    // LogField has exactly four constructors, for int counts, millisecond
    // durations, bools and enum members, so there is no way to place a String,
    // a DateTime or a CivilDate into a record.
    //
    // Taken together it is impossible to write a log line containing a period
    // date, a flow level or a symptom. See docs/PLAN.md 5.5 and 6.5.

    test('every encoded field value is a primitive, never free text', () {
      final log = _logger()
        ..info(
          LogEvent.predictionComputed,
          fields: <String, LogField>{
            'n_cycles': const LogField.count(7),
            'elapsed': const LogField.millis(3),
            'from_cache': const LogField.flag(false),
            'confidence': const LogField.state(_Confidence.medium),
          },
        );

      final decoded =
          jsonDecode(log.records.single.toJsonLine()) as Map<String, Object?>;

      expect(decoded['event'], 'predictionComputed');
      expect(decoded['n_cycles'], 7);
      expect(decoded['elapsed'], 3);
      expect(decoded['from_cache'], false);
      expect(decoded['confidence'], 'medium');
      // Exercises the remaining enum members so the encoding is covered for all
      // of them, not just the one used above.
      expect(const LogField.state(_Confidence.high).encoded, 'high');
      expect(const LogField.state(_Confidence.low).encoded, 'low');
    });

    test('a full dump contains no digits that could be a date', () {
      final log = _logger()
        ..info(
          LogEvent.logEntryCreated,
          fields: <String, LogField>{'total': const LogField.count(12)},
        )
        ..info(LogEvent.cyclesSegmented);

      // The only ISO-8601 text in a record is the log timestamp itself, which
      // is the time of the event, not any user-entered date.
      final dump = log.dump();
      expect(dump, isNot(contains('flow')));
      expect(dump, isNot(contains('symptom')));
      for (final line in dump.split('\n')) {
        final decoded = jsonDecode(line) as Map<String, Object?>;
        expect(decoded.keys, contains('ts'));
        decoded.remove('ts');
        for (final value in decoded.values) {
          expect(value, anyOf(isA<int>(), isA<bool>(), isA<String>()));
        }
      }
    });
  });

  group('ring buffer', () {
    test('retains records in order', () {
      final log = _logger()
        ..info(LogEvent.appStarted)
        ..info(LogEvent.dbOpened)
        ..warn(LogEvent.notificationMissed);

      expect(log.length, 3);
      expect(
        log.records.map((r) => r.event).toList(),
        <LogEvent>[
          LogEvent.appStarted,
          LogEvent.dbOpened,
          LogEvent.notificationMissed,
        ],
      );
    });

    test('drops the oldest once capacity is reached', () {
      final log = _logger(capacity: 3);
      for (var i = 0; i < 10; i++) {
        log.info(
          LogEvent.predictionComputed,
          fields: {
            'i': LogField.count(i),
          },
        );
      }
      expect(log.length, 3);
      final indices = log.records
          .map((r) => (r.fields['i']! as CountField).value)
          .toList();
      expect(indices, <int>[7, 8, 9], reason: 'oldest dropped, newest kept');
    });

    test('never grows without bound', () {
      final log = _logger(capacity: 10);
      for (var i = 0; i < 5000; i++) {
        log.info(LogEvent.predictionCacheHit);
      }
      expect(log.length, 10);
    });

    test('clear discards everything', () {
      final log = _logger()..info(LogEvent.appStarted);
      expect(log.length, 1);
      log.clear();
      expect(log.length, 0);
      expect(log.dump(), isEmpty);
    });

    test('records list is unmodifiable', () {
      final log = _logger()..info(LogEvent.appStarted);
      expect(
        () => log.records.add(
          LogRecord(
            level: LogLevel.info,
            event: LogEvent.dbOpened,
            timestampUtc: DateTime.utc(2026),
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('a zero or negative capacity is rejected', () {
      expect(
        () => RingLogger(clock: FixedClock.iso('2026-08-17'), capacity: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('levels', () {
    test('debug is dropped unless explicitly retained', () {
      final log = _logger()..debug(LogEvent.predictionCacheHit);
      expect(log.length, 0, reason: 'debug off by default');

      log
        ..retainDebug = true
        ..debug(LogEvent.predictionCacheHit);
      expect(log.length, 1);
    });

    test('info, warn and error are always retained', () {
      final log = _logger()
        ..info(LogEvent.appStarted)
        ..warn(LogEvent.clockWentBackwards)
        ..error(LogEvent.dbCorruptionDetected);
      expect(
        log.records.map((r) => r.level).toList(),
        <LogLevel>[LogLevel.info, LogLevel.warn, LogLevel.error],
      );
    });
  });

  group('timestamps', () {
    test('come from the injected clock, in UTC', () {
      final clock = FixedClock(CivilDate(2026, 8, 17));
      final log = RingLogger(clock: clock)..info(LogEvent.appStarted);
      final ts = log.records.single.timestampUtc;
      expect(ts.isUtc, isTrue);
      expect(ts, clock.nowUtc());
    });
  });

  group('LogRecord encoding', () {
    test('produces one line of valid JSON', () {
      final record = LogRecord(
        level: LogLevel.warn,
        event: LogEvent.cycleFlaggedImplausible,
        timestampUtc: DateTime.utc(2026, 8, 17, 12, 30),
        fields: const <String, LogField>{'count': LogField.count(2)},
      );
      final line = record.toJsonLine();
      expect(line, isNot(contains('\n')));
      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['level'], 'warn');
      expect(decoded['event'], 'cycleFlaggedImplausible');
      expect(decoded['count'], 2);
      expect(decoded['ts'], '2026-08-17T12:30:00.000Z');
    });

    test('fields default to empty', () {
      final log = _logger()..info(LogEvent.appStarted);
      expect(log.records.single.fields, isEmpty);
    });
  });
}
