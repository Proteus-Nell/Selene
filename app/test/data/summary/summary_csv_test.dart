// The summary as spreadsheet files (ADR-0024).
//
// What is pinned here is the format, because a spreadsheet reads it with no
// one to ask: the columns, the values in the backup's own names, dates that
// read as dates, fields quoted where they must be, and CRLF line endings. And
// that intercourse, which the summary does not carry, is in none of them.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/summary/summary_csv.dart';

import 'summary_fixture.dart';

/// [csv]'s lines, without their line endings.
List<String> _lines(String csv) => csv.split('\r\n')..removeLast();

void main() {
  final summary = fixtureSummary();

  test('names each file by what it holds and its span, and nothing else', () {
    expect(SummaryCsv.files(summary, fahrenheit: false).keys, <String>[
      'selene-days-2026-05-01-to-2026-07-15.csv',
      'selene-cycles-2026-05-01-to-2026-07-15.csv',
      'selene-conditions-and-medicines-2026-05-01-to-2026-07-15.csv',
    ]);
  });

  test('ends every line with CRLF, and has no bare line feed', () {
    for (final csv in SummaryCsv.files(summary, fahrenheit: true).values) {
      expect(csv, endsWith('\r\n'));
      expect(csv.replaceAll('\r\n', ''), isNot(contains('\n')));
    }
  });

  group('the days', () {
    final lines = _lines(SummaryCsv.days(summary, fahrenheit: false));
    final header = lines.first.split(',');

    test('have a column for each field and each symptom', () {
      expect(header.take(3), <String>['date', 'cycle_day', 'flow']);
      expect(header, containsAll(<String>['cramps', 'breastTenderness']));
      expect(header.skip(header.length - 5), <String>[
        'basal_temperature_celsius',
        'cervical_mucus',
        'pdg_strip',
        'progesterone_value',
        'progesterone_unit',
      ]);
      expect(header, isNot(contains('basal_temperature_fahrenheit')));
    });

    test("hold one row a logged day, in the backup's names", () {
      expect(lines, hasLength(1 + summary.days.length));
      final first = Map<String, String>.fromIterables(
        header,
        lines[1].split(','),
      );
      expect(first['date'], '2026-05-03');
      expect(first['cycle_day'], '1');
      expect(first['flow'], 'heavy');
      expect(first['cramps'], 'severe');
      // Recorded as none in the log, so not recorded here.
      expect(first['headache'], '');
      final measured = Map<String, String>.fromIterables(
        header,
        lines[4].split(','),
      );
      expect(measured['date'], '2026-05-24');
      expect(measured['flow'], '');
      expect(measured['pdg_strip'], 'positive');
      expect(measured['progesterone_value'], '12.5');
      expect(measured['progesterone_unit'], 'ngPerMl');
      final temperature = Map<String, String>.fromIterables(
        header,
        lines[3].split(','),
      );
      expect(temperature['basal_temperature_celsius'], '36.55');
      expect(temperature['cervical_mucus'], 'eggWhite');
    });

    test('add Fahrenheit beside Celsius for someone who reads it', () {
      final lines = _lines(SummaryCsv.days(summary, fahrenheit: true));
      final header = lines.first.split(',');
      final row = Map<String, String>.fromIterables(
        header,
        lines[3].split(','),
      );
      expect(row['basal_temperature_celsius'], '36.55');
      expect(row['basal_temperature_fahrenheit'], '97.79');
    });
  });

  test('the cycles say where each started and ended, and how the app '
      'judged it', () {
    expect(_lines(SummaryCsv.cycles(summary)), <String>[
      'start,bleeding_end,next_start,bleeding_days,length_days,validity',
      '2026-05-03,2026-05-04,2026-06-01,2,29,ok',
      '2026-06-01,2026-06-01,2026-06-30,1,29,unconfirmedOutlier',
      // Still going: no next start, and no length yet.
      '2026-06-30,2026-06-30,,1,,ok',
    ]);
  });

  test('the conditions and medicines quote a name with a comma in it', () {
    expect(_lines(SummaryCsv.conditionsAndMedicines(summary)), <String>[
      'kind,name,start,end',
      'condition,endometriosis,2024-03-01,',
      'medicine,"ACETAMINOPHEN, CAFFEINE",,',
    ]);
  });

  test('no file says anything about intercourse', () {
    for (final csv in SummaryCsv.files(summary, fahrenheit: true).values) {
      expect(csv.toLowerCase(), isNot(contains('intercourse')));
      expect(csv, isNot(contains('protected')));
    }
  });
}
