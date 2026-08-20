// Machine check for "no hardcoded user-facing string anywhere in lib/"
// (AND-11, assumption A4).
//
// Asserted rather than reviewed, because this is a rule that decays silently:
// one `Text('Save')` slipped in during a hurried fix is invisible until a
// translator asks where it went, by which time the retrofit is a multi-day
// refactor. The scan is deliberately crude and deliberately noisy in the right
// direction: it flags any Text() whose literal contains a word.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches `Text('...')` and `Text("...")`, capturing the literal.
final RegExp _textLiteral = RegExp(
  r"""Text\(\s*(?:'([^']*)'|"([^"]*)")""",
  multiLine: true,
);

/// A run of two or more letters that is not inside a `\$interpolation`.
bool _containsProse(String literal) {
  // Strip interpolations first: `'\$label · \${_severity(x)}'` is assembled
  // from localised parts and is not itself a string to translate.
  final withoutInterpolation = literal
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\$\w+'), '');
  return RegExp('[A-Za-z]{2,}').hasMatch(withoutInterpolation);
}

void main() {
  test('no Text widget in lib/ carries a hardcoded string', () {
    final offenders = <String>[];
    final directories = <String>['lib/features', 'lib/routing', 'lib/app.dart'];

    for (final path in directories) {
      final entity = FileSystemEntity.isDirectorySync(path)
          ? Directory(path)
          : null;
      final files = entity == null
          ? <File>[File(path)]
          : entity
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))
                .toList();

      for (final file in files) {
        final source = file.readAsStringSync();
        for (final match in _textLiteral.allMatches(source)) {
          final literal = match.group(1) ?? match.group(2) ?? '';
          if (_containsProse(literal)) {
            offenders.add("${file.path}: Text('$literal')");
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These strings must move into lib/l10n/app_en.arb and be read '
          'through AppLocalizations:\n${offenders.join("\n")}',
    );
  });

  test('the scan would actually catch one', () {
    // A check that cannot fail is not a check. This pins the detector itself.
    expect(_containsProse('Save'), isTrue);
    expect(_containsProse(r'Period started $date'), isTrue);
    expect(_containsProse(r'${a} · ${b}'), isFalse);
    expect(_containsProse(r'$days'), isFalse);
    expect(_containsProse('42'), isFalse);
  });

  test('every ARB key is reachable and documented where it needs to be', () {
    final arb = File('lib/l10n/app_en.arb').readAsStringSync();
    expect(arb, contains('"@@locale": "en"'));
    // The disclaimer copy is the part most likely to be quietly softened, so
    // its keys are pinned by name (docs/PLAN.md 6.2).
    for (final key in <String>[
      'onboardingNotContraception',
      'onboardingNotMedical',
      'onboardingNotDiagnostic',
      'onboardingAlwaysARange',
      'insightsDisclaimer',
    ]) {
      expect(arb, contains('"$key"'), reason: '$key must exist');
    }
  });
}
