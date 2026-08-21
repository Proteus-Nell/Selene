// MainActivity must be a FragmentActivity (AND-33).
//
// The app lock silently did nothing before this was fixed, and the reason is
// worth writing down because nothing about it is visible from Dart.
//
// `local_auth` shows Android's BiometricPrompt, which is a fragment and needs a
// `FragmentActivity` to attach to. With a plain `FlutterActivity` the plugin
// returns NOT_FRAGMENT_ACTIVITY, which arrives in Dart as `uiUnavailable` — so
// `authenticate()` returns immediately, having shown nothing, and the Unlock
// button looks dead.
//
// Nothing catches it earlier. It builds, it installs, and the settings toggle
// enables perfectly happily, because `isDeviceSupported()` only asks whether
// the device has a credential and never looks at the activity type. The failure
// appears only when a real person taps Unlock on a real phone — exactly the
// kind of thing a headless suite cannot see, and therefore has to assert about
// the source instead.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

File _repoFile(String relativePath) {
  var directory = Directory.current.absolute;
  for (var depth = 0; depth < 5; depth++) {
    final candidate = File('${directory.path}/$relativePath');
    if (candidate.existsSync()) return candidate;
    directory = directory.parent;
  }
  throw StateError('could not find $relativePath');
}

void main() {
  final source = _repoFile(
    'app/android/app/src/main/kotlin/io/github/proteusnell/'
    'period_tracker/MainActivity.kt',
  ).readAsStringSync();

  test('MainActivity extends FlutterFragmentActivity', () {
    expect(
      source,
      contains('FlutterFragmentActivity()'),
      reason:
          'MainActivity is not a FragmentActivity, so BiometricPrompt has '
          'nothing to attach to and the app lock will silently never prompt. '
          'This builds and installs fine and the settings toggle still works, '
          'so nothing else will tell you.',
    );
  });

  test('and imports it, rather than shadowing the name', () {
    expect(
      source,
      contains('import io.flutter.embedding.android.FlutterFragmentActivity'),
      reason:
          'the class name is right but the import is not, so this is either a '
          'different type or it does not compile',
    );
  });

  test('and does not extend plain FlutterActivity anywhere', () {
    // `FlutterFragmentActivity` contains the substring `FlutterActivity`, so
    // the check has to be anchored rather than a bare `contains`.
    expect(
      RegExp(r':\s*FlutterActivity\s*\(').hasMatch(source),
      isFalse,
      reason: 'MainActivity still extends FlutterActivity',
    );
  });
}
