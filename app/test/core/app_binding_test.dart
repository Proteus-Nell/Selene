// The app's binding answers the framework's question about animations from
// the app's own setting, and not from the phone's (ADR-0029).
//
// This is the half of the decoupling that no widget test can see. Flutter cuts
// every animation to a twentieth of its length when the binding says
// animations are disabled, and the stock binding says whatever Android does.
//
// Plain tests, and deliberately no testWidgets anywhere in this file: a widget
// test installs the test binding, there can be only one binding in an isolate,
// and the thing under test is the app's.

import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/app_binding.dart';

/// A vsync whose ticker never runs on its own, so a test can move a
/// controller through time by hand.
///
/// Attributes:
///     tick (TickerCallback): The controller's own tick, to call with the
///         time elapsed since it started.
class _HeldVsync implements TickerProvider {
  /// The controller's own tick.
  late TickerCallback tick;

  @override
  Ticker createTicker(TickerCallback onTick) {
    tick = onTick;
    // Muted, so it is started and stopped as usual but asks for no frames.
    return Ticker(onTick)..muted = true;
  }
}

/// How far a one-second animation has got after a tenth of a second.
///
/// A tenth of the way if the framework is running it at full length. All the
/// way if the framework has cut it to a twentieth, which ends at 50ms.
///
/// Returns:
///     double: The controller's value at 100ms, between 0 and 1.
double _progressAfterATenth() {
  final vsync = _HeldVsync();
  final controller = AnimationController(
    vsync: vsync,
    duration: const Duration(seconds: 1),
  );
  addTearDown(controller.dispose);
  controller.forward();
  vsync.tick(const Duration(milliseconds: 100));
  return controller.value;
}

void main() {
  setUpAll(AppBinding.ensureInitialized);

  test('is the binding in force once it has been asked for', () {
    expect(WidgetsBinding.instance, isA<AppBinding>());
  });

  test('tells the framework what the app set, starting with full movement', () {
    expect(SemanticsBinding.instance.disableAnimations, isFalse);

    setFrameworkAnimationsReduced(reduced: true);
    expect(SemanticsBinding.instance.disableAnimations, isTrue);

    setFrameworkAnimationsReduced(reduced: false);
    expect(SemanticsBinding.instance.disableAnimations, isFalse);
  });

  test("does not hear the phone's setting", () {
    // debugSemanticsDisableAnimations is how the framework lets a test stand
    // in for the platform's flag, and the stock binding obeys it. This one
    // must not: it is the same question Android's "remove animations" asks.
    debugSemanticsDisableAnimations = true;
    addTearDown(() => debugSemanticsDisableAnimations = null);

    setFrameworkAnimationsReduced(reduced: false);
    expect(SemanticsBinding.instance.disableAnimations, isFalse);
  });

  group('an animation the framework runs', () {
    test(
      'is full length on a phone that has turned its own animations off',
      () {
        // What 1.2.1 got wrong on a real phone, at the level it went wrong: on
        // the stock binding this controller is finished by 50ms and the test
        // reads 1.0.
        debugSemanticsDisableAnimations = true;
        addTearDown(() => debugSemanticsDisableAnimations = null);
        setFrameworkAnimationsReduced(reduced: false);

        expect(_progressAfterATenth(), closeTo(0.1, 0.001));
      },
    );

    test("is cut short by Selene's own switch", () {
      setFrameworkAnimationsReduced(reduced: true);
      addTearDown(() => setFrameworkAnimationsReduced(reduced: false));

      expect(_progressAfterATenth(), 1.0);
    });
  });

  test('is what main starts the app on', () {
    // The override does nothing unless the app actually runs on this binding,
    // and going back to the stock one is a one-word change that every other
    // test would pass.
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('AppBinding.ensureInitialized()'));
    expect(
      source,
      isNot(contains('WidgetsFlutterBinding.ensureInitialized()')),
    );
  });
}
