// The group names table the app ships (ADR-0021).
//
// `tools/scripts/gen_medicine_groups.py` resolves the sourced table against
// the medicines bundle, and research/tests/test_gen_medicine_groups.py tests
// that. What is pinned here is the Dart side: that the app reads what the
// generator wrote, that it was resolved against the bundle the app ships and
// not an older one, and that every drug it names is one the app can find.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicine_groups.dart';
import 'package:period_tracker/data/reference/medicine_groups_bundled.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/domain/models/condition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final table = MedicineGroups.bundled;

  test('was resolved against the bundle the app ships', () {
    // A bundle rebuilt without regenerating the groups would leave them
    // naming drugs by keys that have moved or gone.
    expect(medicineGroupsBundleSha256, medicinesBundleSha256);
  });

  test('every group has phrases, drugs, and where they come from', () {
    expect(table.groups, isNotEmpty);
    for (final group in table.groups) {
      expect(group.phrases, isNotEmpty, reason: group.name);
      expect(group.members, isNotEmpty, reason: group.name);
      expect(group.sources, isNotEmpty, reason: group.name);
      for (final source in group.sources) {
        expect(source.url, startsWith('https://'), reason: group.name);
        expect(source.title, isNotEmpty);
        expect(source.publisher, isNotEmpty);
      }
    }
  });

  test('includes the groups it was written for', () {
    final names = table.groups.map((group) => group.name);
    expect(
      names,
      containsAll(<String>[
        'NSAIDs',
        'SSRIs',
        'combined hormonal contraceptives',
        'oral contraceptives',
        'hormonal contraceptives',
      ]),
    );
  });

  test('maps the kinds of contraception, and nothing else', () {
    // The other conditions have no ingredients to count as.
    expect(table.conditions.keys.toSet(), <Condition>{
      Condition.hormonalContraceptionCombined,
      Condition.hormonalContraceptionProgestogen,
      Condition.hormonalIud,
      Condition.contraceptiveImplant,
    });
    for (final kind in table.conditions.values) {
      expect(kind.kind, isNotEmpty, reason: kind.condition.name);
      expect(kind.groups, isNotEmpty, reason: kind.condition.name);
    }
    expect(table.conditions[Condition.hormonalIud]!.names, <String>[
      'levonorgestrel',
    ]);
    expect(
      table.conditions[Condition.hormonalContraceptionCombined]!.groups.map(
        (group) => group.name,
      ),
      contains('combined hormonal contraceptives'),
    );
  });

  test('every drug it names is one the app can find', () async {
    final index = await MedicineBundle(rootBundle).index();
    final keys = index.entries.map((entry) => entry.key).toSet();
    for (final group in table.groups) {
      expect(keys.containsAll(group.members), isTrue, reason: group.name);
    }
    for (final kind in table.conditions.values) {
      expect(keys.containsAll(kind.kind), isTrue);
    }
    final pill = index.byKey('drospirenone+ethinyl-estradiol.oral.rx')!;
    expect(
      table.of(pill).map((group) => group.name),
      containsAll(<String>[
        'combined hormonal contraceptives',
        'combined oral contraceptives',
      ]),
    );
    expect(table.of(index.byKey('rifampin.oral.rx')!), isEmpty);
  });

  group('reading a table', () {
    test('refuses one in a format it does not know', () {
      expect(
        () => MedicineGroups.decode(
          '{"schema_version": 99, "groups": [], "conditions": []}',
        ),
        throwsFormatException,
      );
    });

    test('refuses one naming a condition the app does not have', () {
      const source = '''
{"schema_version": 1, "groups": [], "conditions": [{"condition": "flu",
 "kind": [], "names": [], "groups": [], "source": {"title": "t",
 "publisher": "p", "url": "https://example.org", "retrieved": "2026-10-28"}}]}
''';
      expect(() => MedicineGroups.decode(source), throwsFormatException);
    });

    test("finds the groups a drug is in, in the table's order", () {
      const first = MedicineGroup(
        name: 'first',
        phrases: <String>['first'],
        members: <String>{'a.oral.otc'},
      );
      const second = MedicineGroup(
        name: 'second',
        phrases: <String>['second'],
        members: <String>{'a.oral.otc', 'b.oral.otc'},
      );
      const groups = MedicineGroups(<MedicineGroup>[first, second]);
      final entry = MedicineEntry.fromJson(const <String, Object?>{
        'key': 'a.oral.otc',
        'name': 'A',
        'brands': <String>[],
        'substances': <String>['A'],
        'routes': <String>['ORAL'],
        'type': 'otc',
        'classes': <String>[],
        'match': <String>['a'],
        'labels': 1,
        'chunk': 0,
        'line': 0,
        'label': <String, Object?>{
          'set_id': 's',
          'manufacturer': 'm',
          'effective_time': '20260101',
        },
      });
      expect(groups.of(entry), <MedicineGroup>[first, second]);
      expect(MedicineGroups.none.of(entry), isEmpty);
    });
  });
}
