// Motion respects "remove animations", by construction (AND-34).
//
// Android's accessibility setting and iOS's reduce-motion both arrive as
// `MediaQuery.disableAnimationsOf`. An app that reads it at one call site and
// forgets at the next is an app that still moves, so the check lives on the
// token and this file is what holds it there: every duration in `Motion`, with
// animations off, must be exactly zero.
//
// Dropping the interpolation is not the same as dropping the change. The tests
// below the guard pump a real chip with animations disabled and assert that the
// selected state is on screen on the very next frame — nothing in this app may
// require an animation to have run in order to be readable.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/motion.dart';
import 'package:period_tracker/features/common/chip_motion.dart';

/// Pumps a throwaway tree under a [MediaQuery] with animations on or off, and
/// hands back a context from inside it.
Future<BuildContext> _contextWith(
  WidgetTester tester, {
  required bool disableAnimations,
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  group('with animations disabled', () {
    testWidgets('every duration token is exactly zero', (tester) async {
      final context = await _contextWith(tester, disableAnimations: true);
      Motion.all(context).forEach((name, duration) {
        expect(
          duration,
          Duration.zero,
          reason:
              'Motion.$name is $duration with animations off. It has to be '
              'zero: the setting is an accessibility request, not a hint, and '
              'a token that ignores it takes every call site with it.',
        );
      });
    });

    testWidgets('the guard above covers the whole token set', (tester) async {
      // A token added to Motion but not to `all` would be invisible to the
      // check above, which is the one way this guard can rot. Naming them here
      // means adding a token without wiring it up fails loudly.
      final context = await _contextWith(tester, disableAnimations: true);
      expect(
        Motion.all(context).keys,
        <String>['quick', 'standard', 'entrance', 'monthSlide', 'stagger'],
        reason:
            'Motion gained or lost a token. Add it to Motion.all and to this '
            'list, so the zero-duration guard keeps covering all of them.',
      );
    });
  });

  group('with animations enabled', () {
    testWidgets('the tokens are the figures AND-34 specified', (tester) async {
      final context = await _contextWith(tester, disableAnimations: false);
      expect(Motion.quick(context), const Duration(milliseconds: 120));
      expect(Motion.standard(context), const Duration(milliseconds: 220));
      expect(Motion.entrance(context), const Duration(milliseconds: 320));
      expect(Motion.monthSlide(context), const Duration(milliseconds: 180));
      expect(Motion.stagger(context), const Duration(milliseconds: 40));
    });

    testWidgets('there is one curve, and it decelerates', (tester) async {
      expect(Motion.curve, Curves.easeOutCubic);
    });
  });

  group('turning motion off', () {
    testWidgets('drops the interpolation, not the state change', (
      tester,
    ) async {
      // The failure this guards against is a chip whose checkmark only ever
      // appears at the end of an animation that no longer runs.
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => ChipMotion(
                  selected: selected,
                  builder: (context, checkSlot) => ChoiceChip(
                    avatar: checkSlot,
                    selected: selected,
                    onSelected: (value) => setState(() => selected = value),
                    label: const Text('Today'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final width = tester.getSize(find.byType(ChoiceChip)).width;
      await tester.tap(find.byType(ChoiceChip));
      // One frame, deliberately: no settle, no pumped duration.
      await tester.pump();

      expect(
        tester.widget<ChoiceChip>(find.byType(ChoiceChip)).selected,
        isTrue,
        reason: 'the selection did not land on the frame it was asked for',
      );
      expect(
        tester.getSize(find.byType(ChoiceChip)).width,
        width,
        reason:
            'the chip changed width when it was selected, which reflows the '
            'row under the finger that just tapped it',
      );
    });
  });

  group('selectable chips', () {
    test('are all built through ChipMotion', () {
      // `AppTheme` turns Material's own checkmark off, because it opens a
      // drawer that reflows the row and rides a duration no accessibility
      // setting reaches. `ChipMotion` reserves the slot and draws the mark
      // instead — so a selectable chip built outside it has no checkmark at
      // all, and the state stops surviving greyscale (PLAN 2.4.4).
      //
      // Scanned over the sources because that is the only place the fact
      // exists: a chip with no checkmark renders perfectly and announces
      // correctly, and nothing else in the suite would fail.
      final offences = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .where((f) => !f.path.endsWith('chip_motion.dart'))) {
        final source = file.readAsStringSync();
        for (final match in RegExp(
          r'(ChoiceChip|FilterChip)\(',
        ).allMatches(source)) {
          final before = source.substring(0, match.start).trimRight();
          // ChipMotion's builder is an arrow function whose body is the chip,
          // so a wrapped chip is preceded by `=>` with the ChipMotion call a
          // line or two above it. Windowed rather than searched whole-file,
          // which would excuse every chip in a file that wraps one of them.
          final window = before.substring(
            before.length < 200 ? 0 : before.length - 200,
          );
          if (before.endsWith('=>') && window.contains('ChipMotion(')) continue;
          offences.add('${file.path}: ${match.group(1)}');
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'These chips are selectable but are not wrapped in ChipMotion, so '
            'they carry no checkmark and no reserved slot.\n'
            '${offences.join("\n")}',
      );
    });
  });
}
