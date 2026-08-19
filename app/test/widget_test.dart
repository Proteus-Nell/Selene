// Smoke test for the app shell (AND-11).
//
// Builds the real widget tree over an in-memory database, so that a broken
// route, a missing localisation delegate or a theme that fails to construct
// shows up here rather than on a device.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/app.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/main.dart';

void main() {
  late AppDatabase db;
  final clock = FixedClock.iso('2026-06-30');

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('the app builds and lands on onboarding for a new user', (
    tester,
  ) async {
    await tester.pumpWidget(
      await buildAppScope(
        database: db,
        clock: clock,
        logger: RingLogger(clock: clock),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    expect(find.text(l10n.onboardingTitle), findsOneWidget);
    // The non-claims are on the first screen the user sees, not behind a link.
    expect(find.text(l10n.onboardingNotContraception), findsOneWidget);
  });

  testWidgets('the newer-schema screen builds without a database', (
    tester,
  ) async {
    // This one has to work when nothing else does: there is no database to
    // read, which is exactly why it is a separate app widget.
    await tester.pumpWidget(
      const UnreadableDataApp(storedVersion: 2, supportedVersion: 1),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.system_update), findsOneWidget);
  });
}
