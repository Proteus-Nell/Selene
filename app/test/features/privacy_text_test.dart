// docs/PRIVACY.md and the in-app text must not drift apart (AND-16).
//
// The task requires the privacy statement to be shipped "verbatim". Verbatim is
// a claim that decays the moment someone edits one copy, so it is checked here
// rather than asserted in a commit message.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Finds a file by walking up from the working directory.
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
  test('every in-app privacy paragraph appears in docs/PRIVACY.md', () {
    final arb =
        jsonDecode(findFile('app/lib/l10n/app_en.arb').readAsStringSync())!
            as Map<String, Object?>;
    final doc = findFile('docs/PRIVACY.md').readAsStringSync();

    final keys = arb.keys
        .where((k) => k.startsWith('privacy') && !k.startsWith('@'))
        .toList();
    expect(keys, isNotEmpty);

    for (final key in keys) {
      final text = arb[key]! as String;
      expect(
        doc,
        contains(text),
        reason:
            '"$key" is shown in the app but is not in docs/PRIVACY.md. Edit '
            'both together.',
      );
    }
  });

  test('every permission the manifest declares is named in the doc', () {
    // A privacy statement that lists fewer permissions than the app actually
    // holds is worse than none: it invites the reader to stop checking. This
    // caught RECEIVE_BOOT_COMPLETED, which is granted at install with no
    // prompt and so is easy to add without noticing the doc still said
    // "POST_NOTIFICATIONS, and nothing else".
    final manifest = XmlDocument.parse(
      findFile(
        'app/android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync(),
    );
    final doc = findFile('docs/PRIVACY.md').readAsStringSync();

    final declared = manifest
        .findAllElements('uses-permission')
        .where((p) => p.getAttribute('tools:node') != 'remove')
        .map((p) => p.getAttribute('android:name'))
        .whereType<String>()
        .toList();

    expect(declared, isNotEmpty);
    for (final permission in declared) {
      final short = permission.split('.').last;
      expect(
        doc,
        contains(short),
        reason:
            'the manifest declares $permission but docs/PRIVACY.md does not '
            'mention it. Say what it is for, or stop asking for it.',
      );
    }
  });

  test('the honest limits are stated, not softened', () {
    final doc = findFile('docs/PRIVACY.md').readAsStringSync().toLowerCase();
    // ADR-0018 encrypts the database, which protects a copy of the file and
    // not an unlocked phone. Saying "encrypted" without the second half would
    // let the word do work it has not earned, so the second half is checked.
    expect(doc, contains('does not protect an unlocked phone'));
    expect(doc, contains('forensic'));
    // The one thing outside the encrypted file is named.
    expect(doc, contains('outside the encrypted file'));
    // And the lock is not mistaken for the encryption.
    expect(doc, contains('hides the screen'));
    // And the guarantee that is real is stated as such.
    expect(doc, contains('no internet permission'));
  });
}
