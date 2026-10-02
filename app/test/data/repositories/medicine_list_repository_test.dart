// The medicines recorded under Conditions and medication (ADR-0015).
//
// Kept as one setting rather than a table, so that they travel in exports with
// no change to the format, and go with "delete everything" like every other
// setting. What is pinned here is that both of those stay true, and that a
// stored value this build cannot read shows as an empty list rather than a
// screen that fails to open.

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';

import '../../features/harness.dart';
import '../reference/medicine_fixture.dart';

void main() {
  late AppDatabase db;
  late MedicineListRepository medicines;
  late MedicineIndex index;

  setUp(() {
    db = memoryDatabase();
    medicines = MedicineListRepository(db.settingsDao);
    index = fixtureIndex(fixtureDrugs);
  });
  tearDown(() => db.close());

  MedicineEntry entry(String key) => index.byKey(key)!;

  test('keeps medicines in the order they were added', () async {
    await medicines.add(entry('tranexamic-acid.oral.rx'));
    await medicines.add(entry('ibuprofen.oral.otc'));
    expect(await medicines.read(), const <RecordedMedicine>[
      RecordedMedicine(key: 'tranexamic-acid.oral.rx', name: 'TRANEXAMIC ACID'),
      RecordedMedicine(key: 'ibuprofen.oral.otc', name: 'IBUPROFEN'),
    ]);
  });

  test('does not record one twice', () async {
    expect(await medicines.add(entry('ibuprofen.oral.otc')), isTrue);
    expect(await medicines.add(entry('ibuprofen.oral.otc')), isFalse);
    expect(await medicines.read(), hasLength(1));
  });

  test('takes one off, and leaves nothing behind once none are left', () async {
    await medicines.add(entry('ibuprofen.oral.otc'));
    await medicines.add(entry('levonorgestrel.oral.otc'));
    await medicines.remove('ibuprofen.oral.otc');
    expect((await medicines.read()).single.key, 'levonorgestrel.oral.otc');

    await medicines.remove('levonorgestrel.oral.otc');
    expect(await medicines.read(), isEmpty);
    // Not an empty list left in the table: nothing that says there was one.
    expect(
      (await db.settingsDao.allRaw()).keys,
      isNot(contains(SettingKey.recordedMedicines.wireName)),
    );
  });

  test('is watched as it changes', () async {
    final seen = <int>[];
    final subscription = medicines.watch().listen(
      (list) => seen.add(list.length),
    );
    await pumpEventQueue();
    await medicines.add(entry('ibuprofen.oral.otc'));
    await pumpEventQueue();
    await medicines.add(entry('levonorgestrel.oral.otc'));
    await pumpEventQueue();
    await subscription.cancel();
    expect(seen, <int>[0, 1, 2]);
  });

  test('travels with the other settings, which exports carry', () async {
    // The exporter writes allRaw() verbatim, and an import writes it back
    // with replaceAll(): the round trip a backup makes.
    await medicines.add(entry('ibuprofen.oral.otc'));
    final exported = await db.settingsDao.allRaw();

    final restored = memoryDatabase();
    addTearDown(restored.close);
    await restored.settingsDao.replaceAll(exported);
    expect(
      await MedicineListRepository(restored.settingsDao).read(),
      const <RecordedMedicine>[
        RecordedMedicine(key: 'ibuprofen.oral.otc', name: 'IBUPROFEN'),
      ],
    );
  });

  test('goes with "delete everything"', () async {
    await medicines.add(entry('ibuprofen.oral.otc'));
    await db.dayLogDao.deleteEverything();
    expect(await medicines.read(), isEmpty);
  });

  group('a stored value', () {
    test('that cannot be read is an empty list', () {
      for (final raw in <String?>[
        null,
        '',
        'not json',
        '{"key": "a", "name": "b"}',
        '42',
      ]) {
        expect(MedicineListRepository.decode(raw), isEmpty, reason: raw);
      }
    });

    test('keeps the entries it can read, and skips the rest', () {
      expect(
        MedicineListRepository.decode(
          '[{"key": "a.oral.otc", "name": "A"}, {"key": "b"}, '
          '{"key": "", "name": "C"}, 7, {"key": "d.oral.rx", "name": "D"}]',
        ),
        const <RecordedMedicine>[
          RecordedMedicine(key: 'a.oral.otc', name: 'A'),
          RecordedMedicine(key: 'd.oral.rx', name: 'D'),
        ],
      );
    });

    test('is read back exactly as it was written', () {
      const recorded = <RecordedMedicine>[
        RecordedMedicine(key: 'a.oral.otc', name: 'A "quoted" name'),
        RecordedMedicine(key: 'b.oral.rx', name: 'B'),
      ];
      expect(
        MedicineListRepository.decode(MedicineListRepository.encode(recorded)),
        recorded,
      );
    });
  });
}
