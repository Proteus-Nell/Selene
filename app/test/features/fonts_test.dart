// The bundled typeface, and the licence that has to travel with it (AND-34).
//
// Two different things are being held down here.
//
// The first is ordinary asset rot: `fontFamily: 'Figtree'` in the theme fails
// *silently* if the files are not in the bundle. Flutter falls back to the
// platform font, every screen still renders, every other test still passes, and
// the only symptom is that the app looks like a different app on a device
// nobody in CI is holding. So the declaration and the files are checked
// together.
//
// The second is not cosmetic at all. Figtree is under the SIL Open Font
// License 1.1, which requires the copyright notice and the licence text to be
// distributed *with* the font. `assets/fonts/OFL.txt` is therefore an app asset
// rather than a repository file: a cleanup that drops it while keeping the
// .ttf files makes every build after it non-compliant, and nothing about the
// running app would say so.
//
// The subset check at the end backs a claim the pubspec makes rather than
// repeating it. These are Google Fonts' latin cut, 222 codepoints, and the
// reason that is safe today is that English needs 67 of them. A translator
// arriving with a locale that needs more should find out here, not from a
// screenful of tofu.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The weights declared in the pubspec, and the files behind them.
const Map<int, String> _weights = <int, String>{
  400: 'assets/fonts/Figtree-400.ttf',
  500: 'assets/fonts/Figtree-500.ttf',
  600: 'assets/fonts/Figtree-600.ttf',
  700: 'assets/fonts/Figtree-700.ttf',
};

const String _licence = 'assets/fonts/OFL.txt';

String _pubspec() => File('pubspec.yaml').readAsStringSync();

void main() {
  group('the font files', () {
    test('are all present and are actually fonts', () {
      for (final path in _weights.values) {
        final file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              '$path is missing, so the theme falls back to the system '
              'font and nothing else in the suite notices',
        );
        // Four bytes rather than a size check: a text file of the right length
        // would pass a size check and render nothing.
        expect(
          file.readAsBytesSync().sublist(0, 4),
          <int>[0x00, 0x01, 0x00, 0x00],
          reason:
              '$path does not start with a TrueType version tag. A font '
              'mangled by line-ending normalisation looks exactly like this.',
        );
      }
    });

    test('are declared in the pubspec, under one family, at their weights', () {
      // Scanned as text rather than parsed: the app has no YAML dependency and
      // does not need one to answer "is this line still here".
      final pubspec = _pubspec();
      expect(pubspec, contains('family: Figtree'));
      _weights.forEach((weight, path) {
        expect(
          pubspec,
          contains('- asset: $path'),
          reason: '$path is on disk but not in the bundle',
        );
        expect(
          pubspec,
          contains('weight: $weight'),
          reason: 'the $weight weight is no longer declared',
        );
      });
    });
  });

  group('the licence', () {
    test('is on disk and carries the notice the OFL requires', () {
      final file = File(_licence);
      expect(file.existsSync(), isTrue, reason: '$_licence is missing');
      final text = file.readAsStringSync();
      expect(
        text,
        contains('Copyright'),
        reason: 'the copyright notice is gone from the licence file',
      );
      expect(
        text,
        contains('SIL Open Font License, Version 1.1'),
        reason: 'this is not the licence the bundled font is under',
      );
    });

    test('ships with the app rather than only living in the repository', () {
      // The OFL requires the notice and licence to be distributed with the
      // font. A file that is committed but not bundled satisfies the repository
      // and not the licence.
      expect(
        _pubspec(),
        contains('- $_licence'),
        reason:
            'OFL.txt is not declared as an asset, so it is not in the APK. '
            'The licence requires it to travel with the font files; bundle it '
            'or stop shipping the font.',
      );
    });
  });

  test('the latin subset covers every character the app can show', () {
    // The claim in the pubspec, checked. Read out of the font's own character
    // map, so it stays true when the font is replaced.
    final covered = _codepointsIn(File(_weights[400]!).readAsBytesSync());
    expect(
      covered.length,
      greaterThan(200),
      reason:
          'the character map came back suspiciously small; the reader '
          'below probably failed rather than the font',
    );

    final arb = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final missing = <String>{};
    for (final entry in arb.entries) {
      if (entry.key.startsWith('@') || entry.value is! String) continue;
      for (final rune in (entry.value as String).runes) {
        if (!covered.contains(rune)) {
          missing.add('U+${rune.toRadixString(16).toUpperCase()}');
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'The bundled subset cannot draw these, so they render as tofu: '
          '${missing.join(", ")}. Either reword the string or bundle a wider '
          'subset — this is the check that is meant to catch the first '
          'non-English locale.',
    );
  });
}

/// The codepoints a TrueType font can draw, read from its `cmap` table.
///
/// Only format 4 is read, which is the one Google Fonts' subsets use for the
/// basic multilingual plane. A font whose map is in another format comes back
/// empty and trips the sanity check above rather than passing quietly.
Set<int> _codepointsIn(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tableCount = data.getUint16(4);
  var cmapOffset = -1;
  for (var i = 0; i < tableCount; i++) {
    final record = 12 + 16 * i;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') cmapOffset = data.getUint32(record + 8);
  }
  if (cmapOffset < 0) return <int>{};

  var subtable = -1;
  final subtableCount = data.getUint16(cmapOffset + 2);
  for (var i = 0; i < subtableCount; i++) {
    final offset = cmapOffset + data.getUint32(cmapOffset + 4 + 8 * i + 4);
    if (data.getUint16(offset) == 4) subtable = offset;
  }
  if (subtable < 0) return <int>{};

  final segments = data.getUint16(subtable + 6) ~/ 2;
  final endOffset = subtable + 14;
  // The spec puts a two-byte pad between the end and start arrays.
  final startOffset = endOffset + segments * 2 + 2;
  final covered = <int>{};
  for (var segment = 0; segment < segments; segment++) {
    final end = data.getUint16(endOffset + segment * 2);
    final start = data.getUint16(startOffset + segment * 2);
    // The final segment is the 0xFFFF terminator, not a character.
    if (start == 0xFFFF && end == 0xFFFF) continue;
    for (var code = start; code <= end; code++) {
      covered.add(code);
    }
  }
  return covered;
}
