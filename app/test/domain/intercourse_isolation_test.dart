// Nothing in the prediction layer may read the intercourse column (AND-30).
//
// Assumption A5: this app will not present a safe day or a contraceptive
// fertile window. The shortest path to breaking that is not a deliberate
// decision to add fertility prediction — it is a well-meaning correlation
// between this column and a cycle phase, added by someone who thought they were
// making the model better informed.
//
// So the guarantee is structural rather than behavioural, the same shape as
// ADR-0010's guard for conditions: the prediction layer has no way to *name*
// the type. That is stronger than any assertion about outputs, because it holds
// for code that has not been written yet.
//
// The second half is about the data rather than the code. Even where reading it
// would be harmless, it must not travel: not into the log ring, not into the
// exported filename, not into a notification. `docs/PLAN.md` 6.5 says to treat
// this as if it will be read by someone the user did not choose, and every one
// of those is a place it could be read from without unlocking the app.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/cycle_repository.dart';
import 'package:period_tracker/data/repositories/prediction_repository.dart';
import 'package:period_tracker/data/transfer/export_v1.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// Every Dart file under [directory].
List<File> _dartFilesIn(String directory) =>
    Directory(directory)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

void main() {
  test('the prediction layer cannot name the type', () {
    // Matched on the type at a word boundary and on the import, not on a bare
    // substring: the word appears in ordinary prose and a guard that fails on
    // a comment is a guard someone eventually deletes.
    final offenders = <String>[];
    for (final file in _dartFilesIn('lib/domain/predict')) {
      final source = file.readAsStringSync();
      if (RegExp(r'\bIntercourse\b').hasMatch(source) ||
          RegExp(r'\bintercourse\b').hasMatch(source)) {
        offenders.add(file.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'The prediction model now mentions the intercourse column. '
          'Assumption A5 forbids this app from presenting a fertile window or '
          'a safe day, and correlating this column with a cycle phase is how '
          'that rule gets broken by accident. If this is deliberate it needs a '
          'new ADR and a rewritten A5, not a passing test.\n'
          '${offenders.join("\n")}',
    );
  });

  test('neither can the cycle segmentation it feeds', () {
    // Segmentation is upstream of the filter and its output is what the filter
    // sees. A fertility inference smuggled in here would reach the prediction
    // without the prediction layer ever naming the type.
    final offenders = <String>[];
    for (final file in _dartFilesIn('lib/domain/cycles')) {
      final source = file.readAsStringSync();
      if (RegExp(r'\bIntercourse\b').hasMatch(source)) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('nor can the summary for a doctor, or its spreadsheet files', () {
    // ADR-0024: a summary is a record someone else reads, and a spreadsheet
    // may travel further still. The summary has no field for the column, and
    // this keeps it that way. Comments are skipped: the files say in prose why
    // the column is not there, and that is worth keeping.
    final offenders = <String>[];
    for (final directory in <String>[
      'lib/data/summary',
      'lib/features/summary',
    ]) {
      for (final file in _dartFilesIn(directory)) {
        final code = file
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        if (RegExp(r'\bIntercourse\b|\.intercourse\b').hasMatch(code)) {
          offenders.add(file.path);
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the scan is looking somewhere real', () {
    // A guard that finds no files passes for the wrong reason.
    expect(_dartFilesIn('lib/domain/predict'), isNotEmpty);
    expect(_dartFilesIn('lib/domain/cycles'), isNotEmpty);
    expect(_dartFilesIn('lib/data/summary'), isNotEmpty);
    expect(_dartFilesIn('lib/features/summary'), isNotEmpty);
  });

  group('and the value does not travel', () {
    late AppDatabase db;
    final clock = FixedClock.iso('2026-06-30');

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> logSomething() => db.dayLogDao.save(
      DayLog(
        date: CivilDate.parseIso8601('2026-06-20'),
        flow: FlowIntensity.medium,
        intercourse: Intercourse.unprotected,
      ),
    );

    test('into the log ring', () async {
      // The log viewer is reachable from settings and the ring is dumped into
      // bug reports. It records counts, never content — this is the field where
      // that rule matters most.
      final logger = RingLogger(clock: clock);
      await logSomething();
      final cycles = CycleRepository(
        database: db,
        clock: clock,
        logger: logger,
      );
      await cycles.logs();
      await PredictionRepository(
        database: db,
        cycles: cycles,
        logger: logger,
      ).current();

      final dump = logger.dump().toLowerCase();
      expect(dump, isNot(contains('intercourse')));
      expect(dump, isNot(contains('unprotected')));
      expect(dump, isNot(contains('protected')));
    });

    test('into the suggested export filename', () async {
      // The filename is visible in a file picker, a notification shade and a
      // shared-storage listing, none of which are behind the app lock.
      final name = ExportV1.suggestedFileName(clock);
      expect(name.toLowerCase(), isNot(contains('intercourse')));
      expect(name.toLowerCase(), isNot(contains('sex')));
    });

    test('but it does reach the export file itself', () async {
      // The one place it must travel. The export is the user's own backup and
      // dropping a field would lose them data they deliberately recorded —
      // the opposite failure from the ones above.
      await logSomething();
      final text = ExportV1.encode(
        await ExportV1.build(database: db, clock: clock),
      );
      expect(text, contains('"intercourse": "unprotected"'));
    });
  });
}
