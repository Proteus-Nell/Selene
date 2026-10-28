// The medicines recorded under Conditions and medication (ADR-0015).
//
// Kept as one setting rather than a table, so that they travel in exports with
// no change to the format, and go with "delete everything" like every other
// setting. What is pinned here is that both of those stay true, and that a
// stored value this build cannot read shows as an empty list rather than a
// screen that fails to open. The times each is to be reminded of are a second
// setting beside it (ADR-0025), held to the same.

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

  group('reminder times', () {
    const ibuprofen = 'ibuprofen.oral.otc';
    const levonorgestrel = 'levonorgestrel.oral.otc';

    test('are none until one is set, and leave nothing stored', () async {
      expect(await medicines.reminders(), isEmpty);
      expect(
        (await db.settingsDao.allRaw()).keys,
        isNot(contains(SettingKey.medicineReminders.wireName)),
      );
    });

    test('are kept once each, earliest first, and no more than four', () async {
      await medicines.setReminders(ibuprofen, const <ReminderTime>[
        ReminderTime(20, 0),
        ReminderTime(8, 0),
        ReminderTime(8, 0),
        ReminderTime(12, 30),
        ReminderTime(13, 0),
        ReminderTime(14, 0),
      ]);
      expect(MedicineListRepository.maxReminders, 4);
      expect((await medicines.reminders())[ibuprofen], const <ReminderTime>[
        ReminderTime(8, 0),
        ReminderTime(12, 30),
        ReminderTime(13, 0),
        ReminderTime(14, 0),
      ]);
    });

    test("are each medicine's own", () async {
      await medicines.setReminders(ibuprofen, const <ReminderTime>[
        ReminderTime(8, 0),
      ]);
      await medicines.setReminders(levonorgestrel, const <ReminderTime>[
        ReminderTime(21, 15),
      ]);
      expect(await medicines.reminders(), const <String, List<ReminderTime>>{
        ibuprofen: <ReminderTime>[ReminderTime(8, 0)],
        levonorgestrel: <ReminderTime>[ReminderTime(21, 15)],
      });
    });

    test(
      'set to none are taken off, with the setting once none are left',
      () async {
        await medicines.setReminders(ibuprofen, const <ReminderTime>[
          ReminderTime(8, 0),
        ]);
        await medicines.setReminders(ibuprofen, const <ReminderTime>[]);
        expect(await medicines.reminders(), isEmpty);
        expect(
          (await db.settingsDao.allRaw()).keys,
          isNot(contains(SettingKey.medicineReminders.wireName)),
        );
      },
    );

    test(
      'go with their medicine, so one added back starts with none',
      () async {
        await medicines.add(entry(ibuprofen));
        await medicines.add(entry(levonorgestrel));
        await medicines.setReminders(ibuprofen, const <ReminderTime>[
          ReminderTime(8, 0),
        ]);
        await medicines.setReminders(levonorgestrel, const <ReminderTime>[
          ReminderTime(21, 0),
        ]);
        await medicines.remove(ibuprofen);
        expect(await medicines.reminders(), const <String, List<ReminderTime>>{
          levonorgestrel: <ReminderTime>[ReminderTime(21, 0)],
        });

        await medicines.add(entry(ibuprofen));
        expect((await medicines.reminders())[ibuprofen], isNull);
      },
    );

    test('are watched as they change', () async {
      final seen = <int>[];
      final subscription = medicines.watchReminders().listen(
        (reminders) => seen.add(reminders[ibuprofen]?.length ?? 0),
      );
      await pumpEventQueue();
      await medicines.setReminders(ibuprofen, const <ReminderTime>[
        ReminderTime(8, 0),
      ]);
      await pumpEventQueue();
      await medicines.setReminders(ibuprofen, const <ReminderTime>[
        ReminderTime(8, 0),
        ReminderTime(20, 0),
      ]);
      await pumpEventQueue();
      await subscription.cancel();
      expect(seen, <int>[0, 1, 2]);
    });

    test(
      'travel with the other settings, and go with "delete everything"',
      () async {
        await medicines.setReminders(ibuprofen, const <ReminderTime>[
          ReminderTime(8, 0),
        ]);
        final restored = memoryDatabase();
        addTearDown(restored.close);
        await restored.settingsDao.replaceAll(await db.settingsDao.allRaw());
        expect(
          await MedicineListRepository(restored.settingsDao).reminders(),
          const <String, List<ReminderTime>>{
            ibuprofen: <ReminderTime>[ReminderTime(8, 0)],
          },
        );

        await db.dayLogDao.deleteEverything();
        expect(await medicines.reminders(), isEmpty);
      },
    );

    test('that cannot be read are none, and a time that cannot is skipped', () {
      for (final raw in <String?>[null, '', 'not json', '[]', '42']) {
        expect(MedicineListRepository.decodeReminders(raw), isEmpty);
      }
      expect(
        MedicineListRepository.decodeReminders(
          '{"a.oral.otc": ["8:00", "24:00", "07:60", "07:30", 7], '
          '"": ["08:00"], "b.oral.rx": "08:00", "c.oral.rx": []}',
        ),
        const <String, List<ReminderTime>>{
          'a.oral.otc': <ReminderTime>[ReminderTime(7, 30)],
        },
      );
    });

    test('are read back exactly as they were written', () {
      const reminders = <String, List<ReminderTime>>{
        'a.oral.otc': <ReminderTime>[ReminderTime(0, 5), ReminderTime(23, 59)],
        'b.oral.rx': <ReminderTime>[ReminderTime(12, 0)],
      };
      final stored = MedicineListRepository.encodeReminders(reminders);
      expect(stored, contains('"00:05"'));
      expect(MedicineListRepository.decodeReminders(stored), reminders);
    });
  });

  group('a reminder time', () {
    test(
      'is read only as two-digit hours and minutes on the 24-hour clock',
      () {
        expect(ReminderTime.parse('08:05'), const ReminderTime(8, 5));
        expect(ReminderTime.parse('23:59'), const ReminderTime(23, 59));
        for (final text in <String>[
          '8:05',
          '24:00',
          '12:60',
          '0805',
          ' 08:05',
        ]) {
          expect(ReminderTime.parse(text), isNull, reason: text);
        }
      },
    );

    test('is written as it is read, and sorts by the clock', () {
      expect(const ReminderTime(7, 3).wire, '07:03');
      final times = <ReminderTime>[
        const ReminderTime(20, 0),
        const ReminderTime(7, 59),
        const ReminderTime(8, 0),
      ]..sort();
      expect(times, const <ReminderTime>[
        ReminderTime(7, 59),
        ReminderTime(8, 0),
        ReminderTime(20, 0),
      ]);
    });
  });
}
