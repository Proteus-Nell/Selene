// Temperature, mucus and progesterone in the day editor (ADR-0020).
//
// Recorded only, and the section says so before anything is entered. What is
// pinned here is that each control stores what it says, in the unit it says,
// that a number is written only once it is finished and in range, and that
// there is always a way back to having recorded nothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/log/log_screen.dart';
import 'package:period_tracker/features/log/measurements_editor.dart';

import 'harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<DayLog?> today() => db.dayLogDao.logFor(testClock.today());

  Future<void> pumpLog(WidgetTester tester) async {
    await tester.pumpWidget(harness(const LogScreen(), database: db));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// Opens the section, which a day with nothing in it keeps collapsed.
  Future<void> open(WidgetTester tester) async {
    final title = find.text(l10nOf(tester).logMeasurementsTitle);
    await reveal(tester, title);
    await tester.tap(title);
    await tester.pumpAndSettle();
  }

  Finder fieldLabelled(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  Future<void> type(WidgetTester tester, Finder field, String text) async {
    await reveal(tester, field);
    await tester.enterText(field, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('says it is only a record, and starts closed', (tester) async {
    await pumpLog(tester);
    final l10n = l10nOf(tester);
    await reveal(tester, find.text(l10n.logMeasurementsTitle));
    expect(find.text(l10n.logMeasurementsHint), findsOneWidget);
    expect(
      l10n.logMeasurementsHint.toLowerCase(),
      contains('does not use any of these to predict'),
    );
    expect(find.text(l10n.logMucusTitle), findsNothing);
  });

  testWidgets('a temperature is stored in Celsius, once it is finished', (
    tester,
  ) async {
    await pumpLog(tester);
    await open(tester);
    final l10n = l10nOf(tester);
    final field = fieldLabelled(
      '${l10n.logTemperatureLabel} (${l10n.logTemperatureCelsius})',
    );
    await reveal(tester, field);
    await tester.enterText(field, '36.5');
    await tester.pump();
    // Not on the keystroke.
    expect(await today(), isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await today())!.basalTemperatureCelsius, 36.5);
    // Only a measurement, and the day is kept rather than deleted as empty.
    expect((await today())!.flow, FlowIntensity.none);
  });

  testWidgets('in Fahrenheit it is entered in Fahrenheit, and still stored in '
      'Celsius', (tester) async {
    await db.settingsDao.writeBool(
      SettingKey.temperatureFahrenheit,
      value: true,
    );
    await pumpLog(tester);
    await open(tester);
    final l10n = l10nOf(tester);
    await type(
      tester,
      fieldLabelled(
        '${l10n.logTemperatureLabel} (${l10n.logTemperatureFahrenheit})',
      ),
      '97.7',
    );
    expect((await today())!.basalTemperatureCelsius, 36.5);
  });

  testWidgets('a temperature no one could take is refused, and says why', (
    tester,
  ) async {
    await pumpLog(tester);
    await open(tester);
    final l10n = l10nOf(tester);
    await type(
      tester,
      fieldLabelled(
        '${l10n.logTemperatureLabel} (${l10n.logTemperatureCelsius})',
      ),
      '365',
    );
    expect(await today(), isNull);
    expect(find.text(l10n.logTemperatureInvalid('34', '42')), findsOneWidget);
  });

  testWidgets('clearing a temperature clears it', (tester) async {
    await db.dayLogDao.save(
      DayLog(date: testClock.today(), basalTemperatureCelsius: 36.7),
    );
    await pumpLog(tester);
    final l10n = l10nOf(tester);
    // Open already, because the day has one.
    final field = fieldLabelled(
      '${l10n.logTemperatureLabel} (${l10n.logTemperatureCelsius})',
    );
    await reveal(tester, field);
    expect(find.text('36.7'), findsOneWidget);
    await type(tester, field, '');
    // Nothing else recorded, so the day goes.
    expect(await today(), isNull);
  });

  testWidgets('mucus is one tap, and the same tap again takes it back', (
    tester,
  ) async {
    await pumpLog(tester);
    await open(tester);
    final l10n = l10nOf(tester);
    final chip = find.text(l10n.logMucusEggWhite);
    await reveal(tester, chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect((await today())!.cervicalMucus, CervicalMucus.eggWhite);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(await today(), isNull);
  });

  testWidgets('a PdG strip result is recorded', (tester) async {
    await pumpLog(tester);
    await open(tester);
    final chip = find.text(l10nOf(tester).logPdgPositive);
    await reveal(tester, chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect((await today())!.pdgStrip, PdgStripResult.positive);
  });

  testWidgets('a blood result is stored with its unit, and relabelled, not '
      'converted', (tester) async {
    await pumpLog(tester);
    await open(tester);
    final l10n = l10nOf(tester);
    await type(tester, fieldLabelled(l10n.logProgesteroneBloodLabel), '12,5');
    var stored = (await today())!;
    expect(stored.progesteroneValue, 12.5);
    expect(stored.progesteroneUnit, ProgesteroneUnit.ngPerMl);

    await tester.tap(find.text(l10n.logProgesteroneNgPerMl));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.logProgesteroneNmolPerL).last);
    await tester.pumpAndSettle();
    stored = (await today())!;
    expect(stored.progesteroneValue, 12.5);
    expect(stored.progesteroneUnit, ProgesteroneUnit.nmolPerL);

    // Clearing the number takes the unit with it.
    await type(tester, fieldLabelled(l10n.logProgesteroneBloodLabel), '');
    expect(await today(), isNull);
  });

  testWidgets('a day that has one opens with them showing', (tester) async {
    await db.dayLogDao.save(
      DayLog(date: testClock.today(), cervicalMucus: CervicalMucus.dry),
    );
    await pumpLog(tester);
    await reveal(tester, find.byType(MeasurementsEditor));
    expect(find.text(l10nOf(tester).logMucusTitle), findsOneWidget);
  });
}
