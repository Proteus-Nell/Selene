// The Android manifest, checked from Dart (AND-17).
//
// assert_no_network.sh is the real gate and runs on the built APK, where
// manifest merging has already pulled in whatever the plugins declare. This
// test is the cheaper half: it runs on every push, needs no Android SDK, and
// catches a hand-edit to the app's own manifest long before CI gets as far as
// building an APK.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

File findFile(String relativePath) {
  var directory = Directory.current.absolute;
  for (var depth = 0; depth < 5; depth++) {
    final candidate = File('${directory.path}/$relativePath');
    if (candidate.existsSync()) return candidate;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('could not find $relativePath');
}

void main() {
  final document = XmlDocument.parse(
    findFile('app/android/app/src/main/AndroidManifest.xml').readAsStringSync(),
  );

  Iterable<XmlElement> permissions() =>
      document.findAllElements('uses-permission');

  String? nameOf(XmlElement element) => element.getAttribute('android:name');

  String? nodeOf(XmlElement element) => element.getAttribute('tools:node');

  group('permissions', () {
    test('are only the two the app actually needs', () {
      final requested = permissions()
          .where((p) => nodeOf(p) != 'remove')
          .map(nameOf)
          .whereType<String>()
          .toSet();
      expect(requested, <String>{
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      });
    });

    test('still actively strip every network permission', () {
      // Flutter injects INTERNET into the debug manifest, and any plugin may
      // declare one in its own. tools:node="remove" strips them no matter who
      // asked (ADR-0004).
      final removed = permissions()
          .where((p) => nodeOf(p) == 'remove')
          .map(nameOf)
          .whereType<String>()
          .toSet();
      expect(removed, contains('android.permission.INTERNET'));
      expect(removed, contains('android.permission.ACCESS_NETWORK_STATE'));
      expect(removed, contains('android.permission.ACCESS_WIFI_STATE'));
    });

    test('do not ask for an exact alarm', () {
      // The reminders are inexact by design. Asking the user to grant an alarm
      // permission in system settings would be spending trust on precision a
      // period reminder does not need.
      final all = permissions().map(nameOf).whereType<String>().toSet();
      expect(all, isNot(contains('android.permission.SCHEDULE_EXACT_ALARM')));
      expect(all, isNot(contains('android.permission.USE_EXACT_ALARM')));
    });
  });

  group('scheduled notifications', () {
    test('have a receiver, and one that survives a reboot', () {
      // Without the boot receiver every scheduled reminder is lost the first
      // time the phone restarts, silently.
      final receivers = document
          .findAllElements('receiver')
          .map(nameOf)
          .whereType<String>()
          .toSet();
      expect(
        receivers,
        contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
        ),
      );
      expect(
        receivers,
        contains(
          'com.dexterous.flutterlocalnotifications.'
          'ScheduledNotificationBootReceiver',
        ),
      );
    });

    test('listen for the boot and package-replaced broadcasts', () {
      final boot = document
          .findAllElements('receiver')
          .firstWhere(
            (r) =>
                (nameOf(r) ?? '').endsWith('ScheduledNotificationBootReceiver'),
          );
      final actions = boot
          .findAllElements('action')
          .map(nameOf)
          .whereType<String>()
          .toSet();
      expect(actions, contains('android.intent.action.BOOT_COMPLETED'));
      expect(actions, contains('android.intent.action.MY_PACKAGE_REPLACED'));
    });

    test('are not exported', () {
      for (final receiver in document.findAllElements('receiver')) {
        expect(receiver.getAttribute('android:exported'), 'false');
      }
    });
  });

  group('backup', () {
    test('is still switched off, so the database cannot reach the cloud', () {
      final application = document.findAllElements('application').single;
      expect(application.getAttribute('android:allowBackup'), 'false');
    });
  });
}
