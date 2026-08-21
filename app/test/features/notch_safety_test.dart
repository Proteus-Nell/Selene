// Nothing important renders under a camera cutout (AND-33).
//
// Every phone this app targets has a status bar, and most have a cutout. The
// two surfaces that grow — a bottom sheet tall enough to reach the top of the
// screen, and a dialog pushed up by the keyboard — both landed their headings
// underneath it, where they are simply not readable.
//
// The tests here give the test view a cutout and assert that the things a user
// has to be able to read and reach are below it. That is a cheaper check than a
// golden and a more specific one: a golden would go red for any pixel change,
// and would not say why.
//
// Worth knowing before changing either fix, because the two surfaces fail for
// different reasons. A bottom sheet genuinely is laid out under the cutout, and
// `useSafeArea: true` is what moves it down. A dialog is not: `showDialog`
// already applies a SafeArea, and the dialog went under the camera by
// *overflowing* — too tall for the space left once the keyboard opened, and an
// unscrollable dialog paints straight through its bounds rather than shrinking.
// So the dialog's fix is `scrollable: true`, and an inset computed from view
// padding would be dead code (inside that SafeArea the padding already reads
// zero). Reverting either line fails a test below.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/repositories/condition_repository.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/features/calendar/calendar_screen.dart';
import 'package:period_tracker/features/calendar/day_cell.dart';
import 'package:period_tracker/features/conditions/conditions_screen.dart';
import 'package:period_tracker/features/settings/delete_everything_dialog.dart';

import 'harness.dart';

/// A camera cutout, in logical pixels.
///
/// Deliberately larger than most real ones. At 48 these tests passed with the
/// sheet fix reverted, because a drag handle happens to be about that tall —
/// so they were measuring a coincidence rather than the clearance. This is
/// still within what a phone with a punch-hole and a status bar actually has.
const double _cutout = 72;

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  /// Makes the test view the shape of a real phone with a cutout.
  ///
  /// The default test view is 800x600 logical, which is nothing anyone ships
  /// and is *wider than it is tall*. Simulating a cutout on it produces a
  /// scenario harsher than any real device — a dialog with the keyboard up had
  /// 204 logical pixels to live in — and a test that fails there is reporting
  /// on a phone that does not exist.
  ///
  /// These numbers are an ordinary mid-range Android handset: 1080x2400
  /// physical at 2.75x, which is 393x873 logical.
  void makeItAPhone(WidgetTester tester) {
    tester.view.devicePixelRatio = 2.75;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
  }

  /// Gives the test view a camera cutout, the way a real device has one.
  ///
  /// Set on `tester.view` rather than by wrapping the widget in a MediaQuery.
  /// A wrapped MediaQuery sits *below* the Navigator, so a route pushed on top
  /// — every dialog and every bottom sheet, which is exactly what is under
  /// test — never sees it, and the test reports clearance the device does not
  /// have. View padding propagates to routes because it describes the display.
  ///
  /// Physical pixels, hence the devicePixelRatio: `view.padding` is in device
  /// pixels while everything measured below is in logical ones.
  void giveTheViewACutout(WidgetTester tester) {
    makeItAPhone(tester);
    final scale = tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(top: _cutout * scale);
    tester.view.viewPadding = FakeViewPadding(top: _cutout * scale);
    addTearDown(tester.view.reset);
  }

  group('the add-a-condition sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      giveTheViewACutout(tester);
      await tester.pumpWidget(
        harness(const ConditionsScreen(), database: db),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nOf(tester).conditionsAdd));
      await tester.pumpAndSettle();
    }

    testWidgets('keeps its heading clear of the cutout', (tester) async {
      // Fourteen conditions make the sheet tall enough to reach the top of the
      // screen, and there the title sat under the status bar and the camera.
      await openSheet(tester);
      final title = find.text(l10nOf(tester).conditionsAddTitle);
      expect(title, findsOneWidget);
      expect(
        tester.getTopLeft(title).dy,
        greaterThanOrEqualTo(_cutout),
        reason: 'the sheet title is underneath the camera cutout',
      );
    });

    testWidgets('offers a visible way back', (tester) async {
      // Swiping down and tapping outside both work, but neither is
      // discoverable, and neither is available to someone navigating with a
      // screen reader or a switch device.
      await openSheet(tester);
      final back = find.byIcon(Icons.arrow_back);
      expect(back, findsOneWidget);

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text(l10nOf(tester).conditionsAddTitle), findsNothing);
    });

    testWidgets('and the way back is announced, not just drawn', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openSheet(tester);
      expect(
        tester.getSemantics(find.byIcon(Icons.arrow_back)).tooltip,
        isNotEmpty,
        reason: 'the back control has no label for a screen reader',
      );
      handle.dispose();
    });

    testWidgets('going back records nothing', (tester) async {
      await openSheet(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(
        await ConditionRepository(database: db, clock: testClock).all(),
        isEmpty,
      );
    });

    testWidgets('choosing one still works', (tester) async {
      // The back button must not have displaced the thing the sheet is for.
      // Scrolled to, because a cutout this tall leaves the sheet shorter than
      // the fourteen conditions it holds — which is the situation on a real
      // phone too, and the reason the list is scrollable.
      await openSheet(tester);
      final pcos = find.text(conditionLabel(l10nOf(tester), Condition.pcos));
      // The sheet's own list, not the screen's underneath it. Both are in the
      // tree, and the default picks neither.
      await tester.scrollUntilVisible(
        pcos,
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(pcos, findsOneWidget);

      await tester.tap(pcos);
      await tester.pumpAndSettle();
      // Tapping one moves on to the date picker rather than doing nothing.
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group("the calendar's day editor", () {
    testWidgets('opens below the cutout', (tester) async {
      // The same defect as the conditions sheet and the same fix. This one is
      // scroll-controlled and holds sixteen symptom chips, a flow row, notes
      // and more, so it reaches the top of the screen on any phone.
      //
      // Asserted on the sheet's own box rather than on its heading: that box is
      // exactly what `useSafeArea` moves, and the heading is a formatted date
      // that a test would have to reconstruct to look up.
      giveTheViewACutout(tester);
      await tester.pumpWidget(harness(const CalendarScreen(), database: db));
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(DayCell).at(14));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        tester.getRect(find.byType(BottomSheet)).top,
        greaterThanOrEqualTo(_cutout),
        reason: 'the day editor opens underneath the camera cutout',
      );
    });
  });

  group('the delete-everything dialog', () {
    /// Opens the dialog over a bare screen, at [textScale], with the keyboard
    /// [keyboardUp] or not.
    ///
    /// The keyboard is set on the view rather than by tapping the field: the
    /// test binding has no soft keyboard, so tapping a TextField in a widget
    /// test moves focus and changes nothing about the layout. On a phone it
    /// takes roughly a third of the screen away, and that is the loss being
    /// simulated.
    Future<void> openDialog(
      WidgetTester tester, {
      double textScale = 1,
      bool keyboardUp = false,
    }) async {
      giveTheViewACutout(tester);
      if (keyboardUp) {
        tester.view.viewInsets = FakeViewPadding(
          bottom: 300 * tester.view.devicePixelRatio,
        );
      }
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showDeleteEverythingDialog(context, loggedDays: 40),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
          database: db,
          textScaler: TextScaler.linear(textScale),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    /// The dialog's own surface.
    ///
    /// The Material inside the Dialog, not the AlertDialog widget. AlertDialog
    /// builds the Dialog, so its own render box spans the whole inset area —
    /// measuring it reports (0, 0) for a dialog that is in fact correctly
    /// placed, which is a test that fails for the wrong reason.
    Rect surfaceOf(WidgetTester tester) => tester.getRect(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );

    testWidgets('keeps its title clear of the cutout', (tester) async {
      await openDialog(tester);
      final title = find.text(l10nOf(tester).settingsDeleteConfirmTitle);
      expect(title, findsOneWidget);
      expect(
        tester.getTopLeft(title).dy,
        greaterThanOrEqualTo(_cutout),
        reason: 'the delete confirmation title is underneath the cutout',
      );
    });

    testWidgets('survives the keyboard at a large text size', (tester) async {
      // The reported case. This is the dialog that grows: it carries a text
      // field, so the keyboard opens under it and takes a third of the screen,
      // and Android's "large" font setting is 1.3 — neither is unusual and
      // together they leave less room than the dialog needs.
      //
      // An unscrollable dialog does not shrink to fit. It overflows its box,
      // and a RenderFlex that overflows still *paints* its children: they run
      // out past the top of the dialog and up under the camera, which is what
      // "appears too high up" looks like from the outside.
      await openDialog(tester, textScale: 1.3, keyboardUp: true);
      expect(
        tester.takeException(),
        isNull,
        reason: 'the dialog overflowed rather than scrolling its content',
      );

      final title = find.text(l10nOf(tester).settingsDeleteConfirmTitle);
      expect(title, findsOneWidget);
      expect(
        tester.getTopLeft(title).dy,
        greaterThanOrEqualTo(_cutout),
        reason: 'the title is underneath the cutout once the keyboard is up',
      );
      // And the field the user has to type into is still on screen, above the
      // keyboard. Clearing the cutout by pushing the dialog down would move
      // this off the bottom instead, which is not a fix.
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(
        surfaceOf(tester).bottom,
        lessThanOrEqualTo(screen.bottom - 300),
        reason: 'the dialog runs down underneath the keyboard',
      );
    });

    testWidgets('stays on screen at 200% text scale', (tester) async {
      // The other way this dialog gets too tall, and the one that does not
      // need a keyboard: at 2.0 the content alone is taller than the space
      // between the cutout and the bottom of the screen.
      await openDialog(tester, textScale: 2);
      expect(
        tester.takeException(),
        isNull,
        reason: 'the dialog overflowed at 200% text scale',
      );

      final surface = surfaceOf(tester);
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(
        surface.top,
        greaterThanOrEqualTo(_cutout),
        reason: 'the dialog runs up underneath the cutout at 200% text scale',
      );
      expect(
        surface.bottom,
        lessThanOrEqualTo(screen.bottom),
        reason: 'the dialog runs off the bottom of the screen',
      );
    });
  });
}
