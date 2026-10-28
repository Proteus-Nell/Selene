// The Android manifest, checked from Dart (AND-17).
//
// assert_no_network.sh is the real gate and runs on the built APK, where
// manifest merging has already pulled in whatever the plugins declare. This
// test is the cheaper half: it runs on every push, needs no Android SDK, and
// catches a hand-edit to the app's own manifest long before CI gets as far as
// building an APK.

import 'dart:convert';
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

  group('the plugins this app depends on', () {
    // assert_no_network.sh is the real gate and runs on the built APK, after
    // manifest merging. This is the cheaper half of the same question, and it
    // is the half that runs without an Android SDK: every Android plugin the
    // app resolves has its own AndroidManifest.xml, and manifest merging pulls
    // whatever they declare into the APK.
    //
    // Added at AND-29, which introduced local_auth — the first dependency
    // since the MVP to declare a permission of its own. CI catches a network
    // permission eventually; this catches it on the commit that adds it,
    // before anyone waits twelve minutes for a build.
    List<File> pluginManifests() {
      final config = jsonDecode(
        findFile('app/.dart_tool/package_config.json').readAsStringSync(),
      );
      final packages =
          (config as Map<String, Object?>)['packages']! as List<Object?>;
      final manifests = <File>[];
      for (final entry in packages.cast<Map<String, Object?>>()) {
        final root = entry['rootUri']! as String;
        if (!root.startsWith('file://')) continue;
        final manifest = File(
          '${Uri.parse(root).toFilePath()}/android/src/main/AndroidManifest.xml',
        );
        if (manifest.existsSync()) manifests.add(manifest);
      }
      return manifests;
    }

    test('none of them asks for a network permission', () {
      const forbidden = <String>[
        'android.permission.INTERNET',
        'android.permission.ACCESS_NETWORK_STATE',
        'android.permission.ACCESS_WIFI_STATE',
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
      ];
      final offenders = <String>[];
      for (final manifest in pluginManifests()) {
        final text = manifest.readAsStringSync();
        for (final permission in forbidden) {
          if (text.contains(permission)) {
            offenders.add('${manifest.path}: $permission');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'A dependency declares a network permission. The app manifest '
            'removes INTERNET with tools:node="remove", so the merged APK may '
            'still be clean — but a dependency that wants the network is a '
            'dependency worth looking at before trusting the removal to hold. '
            'ADR-0004 is the whole privacy story.\n${offenders.join("\n")}',
      );
    });

    test('the scan actually found some manifests', () {
      // A guard that finds nothing passes for the wrong reason. If the package
      // layout changes, this fails rather than quietly covering nothing.
      expect(
        pluginManifests(),
        isNotEmpty,
        reason:
            'no plugin manifests found — the scan is looking in the wrong '
            'place and has been proving nothing',
      );
    });
  });

  group('receivers', () {
    Set<String> declaredReceivers() => document
        .findAllElements('receiver')
        .map((r) => r.getAttribute('android:name'))
        .whereType<String>()
        .toSet();

    test('every receiver the notification plugin needs is declared', () {
      // The plugin's own manifest declares no receivers at all, so anything it
      // is not given here simply does not exist at runtime. A missing
      // ActionBroadcastReceiver is the quiet one: the action button still
      // renders and still taps, and the broadcast goes nowhere.
      const prefix = 'com.dexterous.flutterlocalnotifications.';
      expect(declaredReceivers(), <String>{
        '${prefix}ScheduledNotificationReceiver',
        '${prefix}ScheduledNotificationBootReceiver',
        '${prefix}ActionBroadcastReceiver',
      });
    });

    test('none of them is exported', () {
      // They are internal plumbing. An exported receiver is an entry point any
      // other app on the device can send intents to.
      for (final receiver in document.findAllElements('receiver')) {
        expect(
          receiver.getAttribute('android:exported'),
          'false',
          reason: '${receiver.getAttribute('android:name')} is exported',
        );
      }
    });
  });

  group('permissions', () {
    test('are only the three the app actually needs', () {
      final requested = permissions()
          .where((p) => nodeOf(p) != 'remove')
          .map(nameOf)
          .whereType<String>()
          .toSet();
      expect(requested, <String>{
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.SCHEDULE_EXACT_ALARM',
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

    test('ask for the exact alarm the user can take back, and not the other '
        'one', () {
      // A medicine reminder is set for a time the user chose, so it is
      // scheduled for that minute where they have allowed it (ADR-0026).
      // SCHEDULE_EXACT_ALARM is the one they grant, and can revoke, on
      // Android's own screen.
      //
      // USE_EXACT_ALARM is granted at install and cannot be turned off again.
      // It is meant for alarm clocks and calendars, and holding a permission
      // nobody can revoke, for reminders a user may never set, is exactly the
      // trade this app does not make.
      final all = permissions().map(nameOf).whereType<String>().toSet();
      expect(all, contains('android.permission.SCHEDULE_EXACT_ALARM'));
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
