// The missed-reminder banner sits in the shell's body, which has no app bar,
// so nothing above it clears the status bar or a camera cutout.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/notifications/notification_sync.dart';

import '../features/harness.dart';

void main() {
  testWidgets('the missed-reminder banner clears the notch, once', (
    tester,
  ) async {
    const notch = 48.0;
    final database = memoryDatabase();
    addTearDown(database.close);

    // A reminder that fell due while the app was closed.
    final today = testClock.today();
    await database.settingsDao.writeInt(
      SettingKey.lastOpenedEpochDay,
      today.addDays(-5).epochDay,
    );
    await database.settingsDao.writeRaw(
      SettingKey.scheduledFireDays.wireName,
      '${today.addDays(-2).epochDay}',
    );

    late double screenInset;
    await tester.pumpWidget(
      harness(
        NotificationSync(
          child: Builder(
            builder: (context) {
              screenInset = MediaQuery.paddingOf(context).top;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
        database: database,
        wrap: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: notch),
            viewPadding: const EdgeInsets.only(top: notch),
          ),
          child: child,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final message = find.text(l10nOf(tester).logMissedReminder);
    expect(message, findsOneWidget);
    expect(tester.getTopLeft(message).dy, greaterThanOrEqualTo(notch));
    // The banner took the inset, so the screen below must not pad for it too.
    expect(screenInset, 0);
  });
}
