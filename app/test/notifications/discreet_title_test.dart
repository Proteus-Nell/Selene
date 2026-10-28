// The discreet notification must not name what the app is about (AND-34).
//
// `notificationGenericTitle` is what a notification says when detailed
// notifications are off, which is the default. It renders on the lock screen,
// where it is read by whoever is near the phone rather than by the user — the
// same audience `lock_gate_test.dart` writes its leak check for, and the same
// reason for writing one.
//
// It said "Period Tracker" until AND-34, so the discreet mode announced the
// subject in the one place discretion is for. Nothing caught it: the tests
// around it assert on the *body*, and the title travelled through the gateway
// as a string nobody read.
//
// Asserted against the ARB rather than the generated class, as the other copy
// tests are: the ARB is what a person edits, and a rule that only holds after
// codegen is a rule that can be broken and committed.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Words that say what this app is for.
///
/// "tracker" is on the list because the old value was "Period Tracker" and
/// dropping only the first word would not have fixed anything worth fixing.
const List<String> _leaks = <String>[
  'period',
  'cycle',
  'menstrual',
  'bleed',
  'diary',
  'tracker',
];

void main() {
  final arb = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;

  String string(String key) {
    final value = arb[key];
    expect(value, isA<String>(), reason: '$key is missing from app_en.arb');
    return (value! as String).toLowerCase();
  }

  test('the discreet notification title gives nothing away', () {
    final title = string('notificationGenericTitle');
    for (final leak in _leaks) {
      expect(
        title,
        isNot(contains(leak)),
        reason:
            'the discreet notification title contains "$leak", so a glance at '
            'a lock screen says what this app is for',
      );
    }
  });

  test('and neither does its body', () {
    final body = string('notificationGenericBody');
    for (final leak in _leaks) {
      expect(body, isNot(contains(leak)), reason: 'the body contains "$leak"');
    }
  });

  test('nor does the body of a medicine reminder, which is shown with it', () {
    // Not the generic body: that one says to open the app to see what the
    // notification is about, and the app has nothing to show for a reminder
    // someone set themselves (ADR-0025). So it is held to the same words.
    final body = string('notificationMedicineBody');
    for (final leak in _leaks) {
      expect(body, isNot(contains(leak)), reason: 'the body contains "$leak"');
    }
    expect(body, isNot(contains('{medicine}')));
  });

  test('the app name itself does not name the subject', () {
    // It sits under the launcher icon and in the task switcher, which is the
    // same audience again.
    for (final leak in _leaks) {
      expect(
        string('appTitle'),
        isNot(contains(leak)),
        reason: 'the app name contains "$leak"',
      );
    }
  });

  test('and the manifest label matches it', () {
    // Two names for one app is how the launcher ends up discreet while the
    // task switcher is not — which is exactly the state AND-34 shipped in
    // before this was noticed.
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final label = RegExp('android:label="([^"]*)"').firstMatch(manifest);
    expect(label, isNotNull, reason: 'the manifest declares no android:label');
    expect(
      label!.group(1)!.toLowerCase(),
      string('appTitle'),
      reason:
          'android:label and appTitle disagree, so the launcher and the task '
          'switcher show different names',
    );
  });
}
