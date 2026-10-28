// The one-permission-request rule, held against concurrent prediction changes
// (AND-17, AND-19).
//
// Found by the end-to-end flow rather than by review: logging a day produces
// more than one prediction change, and two overlapping syncs each read the
// "already asked" flag before either had written it. The user got the same
// dialog twice, stacked, and the one underneath could not be answered until the
// top one went. Android gives an app one usable notification-permission
// request, so spending two on the same question is not a cosmetic bug.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/medicine_list_repository.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/notifications/notification_gateway.dart';
import 'package:period_tracker/notifications/notification_plan.dart';
import 'package:period_tracker/notifications/notification_sync.dart';
import 'package:period_tracker/notifications/scheduler.dart';

import '../features/harness.dart';

/// Keeps the medicine reminders scheduled on it, as the platform would.
class _Platform implements NotificationGateway {
  /// The medicine reminders queued now.
  final List<DailyReminder> daily = <DailyReminder>[];

  @override
  Future<void> initialize(NotificationCopy copy) async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> canScheduleExact() async => true;

  @override
  Future<bool> requestExactPermission() async => true;

  @override
  Future<void> cancelAll() async => daily.clear();

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required NotificationCopy copy,
    required bool detailed,
  }) async {}

  @override
  Future<void> scheduleDaily(
    DailyReminder reminder, {
    required NotificationCopy copy,
    required bool detailed,
  }) async => daily.add(reminder);

  @override
  Future<List<int>> pendingIds() async => <int>[
    for (final reminder in daily) reminder.id,
  ];
}

/// Writes a bleeding day [daysAgo] before the test clock's today.
Future<void> _log(AppDatabase database, int daysAgo) async {
  await database.dayLogDao.saveAll(<DayLog>[
    DayLog(
      date: testClock.today().addDays(-daysAgo),
      flow: FlowIntensity.medium,
    ),
  ]);
}

void main() {
  testWidgets('the permission prompt appears once a cycle exists', (
    tester,
  ) async {
    final database = memoryDatabase();
    addTearDown(database.close);

    await tester.pumpWidget(
      harness(
        const NotificationSync(child: Scaffold(body: SizedBox.shrink())),
        database: database,
      ),
    );
    await tester.pumpAndSettle();
    // Nothing logged yet, so there is nothing to ask about: a request made at
    // first launch is denied by reflex, and Android 13+ makes the second one
    // close to unanswerable (docs/PLAN.md 2.4.3).
    expect(find.byType(AlertDialog), findsNothing);

    await _log(database, 0);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('rapid prediction changes still produce exactly one prompt', (
    tester,
  ) async {
    final database = memoryDatabase();
    addTearDown(database.close);

    await tester.pumpWidget(
      harness(
        const NotificationSync(child: Scaffold(body: SizedBox.shrink())),
        database: database,
      ),
    );
    await tester.pumpAndSettle();

    // A single frame between writes, which is what logging looks like in
    // practice: the write, the invalidated cache and the recomputed result all
    // land as separate prediction changes, faster than the first sync's reads
    // and writes complete.
    for (final daysAgo in <int>[56, 28, 0]) {
      await _log(database, daysAgo);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('it is never asked again once answered', (tester) async {
    final database = memoryDatabase();
    addTearDown(database.close);

    await tester.pumpWidget(
      harness(
        const NotificationSync(child: Scaffold(body: SizedBox.shrink())),
        database: database,
      ),
    );
    await tester.pumpAndSettle();
    await _log(database, 28);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10nOf(tester).commonNotNow));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // Declining is an answer, not a deferral. Re-asking after a decline is how
    // an app teaches someone to decline reflexively.
    await _log(database, 0);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a medicine reminder reaches the platform as soon as it is set, '
      'and leaves it when taken off', (tester) async {
    // Nothing about the prediction changes when a reminder does, so without a
    // trigger of its own it would wait for the next logged day to be
    // scheduled, and a removed one would keep going off until then.
    final database = memoryDatabase();
    addTearDown(database.close);
    final platform = _Platform();
    const pill = RecordedMedicine(key: 'pill.oral.rx', name: 'PILL');
    await database.settingsDao.writeRaw(
      SettingKey.recordedMedicines.wireName,
      MedicineListRepository.encode(const <RecordedMedicine>[pill]),
    );
    final medicines = MedicineListRepository(database.settingsDao);

    await tester.pumpWidget(
      harness(
        const NotificationSync(child: Scaffold(body: SizedBox.shrink())),
        database: database,
        overrides: <Override>[
          notificationGatewayProvider.overrideWithValue(platform),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(platform.daily, isEmpty);

    await medicines.setReminders(pill.key, const <ReminderTime>[
      ReminderTime(8, 0),
    ]);
    await tester.pumpAndSettle();
    expect(platform.daily, const <DailyReminder>[
      DailyReminder(id: 2000, medicine: 'PILL', time: ReminderTime(8, 0)),
    ]);

    await medicines.remove(pill.key);
    await tester.pumpAndSettle();
    expect(platform.daily, isEmpty);
  });
}
