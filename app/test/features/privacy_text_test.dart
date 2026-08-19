// docs/PRIVACY.md and the in-app text must not drift apart (AND-16).
//
// The task requires the privacy statement to be shipped "verbatim". Verbatim is
// a claim that decays the moment someone edits one copy, so it is checked here
// rather than asserted in a commit message.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

  test('the honest limits are stated, not softened', () {
    final doc = findFile('docs/PRIVACY.md').readAsStringSync().toLowerCase();
    // ADR-0004 accepts an unencrypted database on the condition that the user
    // is told. This is that condition, checked.
    expect(doc, contains('plain text'));
    expect(doc, contains('no app lock'));
    expect(doc, contains('forensic'));
    // And the guarantee that is real is stated as such.
    expect(doc, contains('no internet permission'));
  });
}
