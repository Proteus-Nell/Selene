// Widening a persisted enum is a schema change.
//
// Enums reach SQLite by name rather than by index (see `tables.dart`), so
// adding a value is free at the storage layer: no column changes, no snapshot
// changes, nothing to migrate. `migration_test.dart` compares schema shape and
// sees nothing at all, because nothing about the shape moved. That is exactly
// the hazard this file exists for — the change looks like it costs nothing.
//
// What moves is the *reader*. drift generates an `EnumNameConverter`, which
// resolves a stored string with `values.byName` and throws on a name it does
// not have. A database written by a newer build and opened by an older one
// therefore throws while reading the row, and `AppDatabase`'s downgrade refusal
// cannot intercept it: the schema version never changed, so the old build has
// no reason to believe the file is anything other than its own. The last test
// below runs that failure rather than describing it.
//
// Bumping `latestSchemaVersion` is what turns that crash into a refusal with a
// sentence the user can act on. Hence the rule, pinned here rather than only
// written down: a rule whose sole enforcement is a comment in a file nobody
// opens while adding an enum value is not enforced.
//
// Settings deliberately are not covered. `SettingKey` is also persisted by
// name, but it is read by looking up a known key, never by parsing a stored
// one, so a row an old build has no key for is a row it never selects. That is
// why the settings table can grow without a migration and these four columns
// cannot, and it is the distinction to check against before adding anything
// here.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/domain/models/day_log.dart';

/// Every enum stored in a `textEnum` column, as of each shipped schema version.
///
/// Append a version; never edit one that has shipped. An entry here is a claim
/// about what is already on real devices, and rewriting it makes the
/// no-value-was-ever-dropped test below compare a fiction against a fiction.
const Map<int, Map<String, List<String>>>
_pinned = <int, Map<String, List<String>>>{
  1: <String, List<String>>{
    'FlowIntensity': <String>['none', 'spotting', 'light', 'medium', 'heavy'],
    'Symptom': <String>['cramps', 'headache', 'mood', 'energy', 'sleep'],
    'SymptomSeverity': <String>['none', 'mild', 'moderate', 'severe'],
  },
  2: <String, List<String>>{
    'FlowIntensity': <String>['none', 'spotting', 'light', 'medium', 'heavy'],
    'Symptom': <String>['cramps', 'headache', 'mood', 'energy', 'sleep'],
    'SymptomSeverity': <String>['none', 'mild', 'moderate', 'severe'],
    // New in v2. The table is new too, so no shipped database contains any of
    // these names yet — but the next value added to this list will be the first
    // one that needs its own version.
    'Condition': <String>[
      'hormonalContraceptionCombined',
      'hormonalContraceptionProgestogen',
      'hormonalIud',
      'contraceptiveImplant',
      'copperIud',
      'pregnancy',
      'postpartum',
      'breastfeeding',
      'pcos',
      'endometriosis',
      'thyroidDisorder',
      'perimenopause',
      'uterineFibroids',
      'other',
    ],
  },
  // v3 widened Symptom and changed no table. It is here because the widening
  // is the schema change: without the bump, a v2 build reading a day logged
  // with `bloating` throws instead of refusing the file. The five original
  // names are unchanged and in their original spelling, which is what lets a
  // v1 export still import.
  3: <String, List<String>>{
    'FlowIntensity': <String>['none', 'spotting', 'light', 'medium', 'heavy'],
    'Symptom': <String>[
      'cramps',
      'headache',
      'bloating',
      'nausea',
      'breastTenderness',
      'backPain',
      'acne',
      'digestiveUpset',
      'sleep',
      'brainFog',
      'poorConcentration',
      'mood',
      'energy',
      'irritability',
      'anxiety',
      'lowMood',
    ],
    'SymptomSeverity': <String>['none', 'mild', 'moderate', 'severe'],
    'Condition': <String>[
      'hormonalContraceptionCombined',
      'hormonalContraceptionProgestogen',
      'hormonalIud',
      'contraceptiveImplant',
      'copperIud',
      'pregnancy',
      'postpartum',
      'breastfeeding',
      'pcos',
      'endometriosis',
      'thyroidDisorder',
      'perimenopause',
      'uterineFibroids',
      'other',
    ],
  },
  // v4 added day_logs.intercourse, which brought a new persisted enum with it.
  // A new enum is the same hazard as a widened one and for the same reason: a
  // v3 build reading a row that says 'protected' throws on a name it has never
  // heard of. The column is nullable, so every row a v3 build wrote reads back
  // fine — it is rows written *after* the upgrade that an older build cannot
  // read, which is what the version bump exists to refuse.
  4: <String, List<String>>{
    'FlowIntensity': <String>['none', 'spotting', 'light', 'medium', 'heavy'],
    'Symptom': <String>[
      'cramps',
      'headache',
      'bloating',
      'nausea',
      'breastTenderness',
      'backPain',
      'acne',
      'digestiveUpset',
      'sleep',
      'brainFog',
      'poorConcentration',
      'mood',
      'energy',
      'irritability',
      'anxiety',
      'lowMood',
    ],
    'SymptomSeverity': <String>['none', 'mild', 'moderate', 'severe'],
    'Condition': <String>[
      'hormonalContraceptionCombined',
      'hormonalContraceptionProgestogen',
      'hormonalIud',
      'contraceptiveImplant',
      'copperIud',
      'pregnancy',
      'postpartum',
      'breastfeeding',
      'pcos',
      'endometriosis',
      'thyroidDisorder',
      'perimenopause',
      'uterineFibroids',
      'other',
    ],
    'Intercourse': <String>['protected', 'unprotected'],
  },
};

/// What the code actually declares, right now.
Map<String, List<String>> _live() => <String, List<String>>{
  'FlowIntensity': FlowIntensity.values.map((v) => v.name).toList(),
  'Symptom': Symptom.values.map((v) => v.name).toList(),
  'SymptomSeverity': SymptomSeverity.values.map((v) => v.name).toList(),
  'Condition': Condition.values.map((v) => v.name).toList(),
  'Intercourse': Intercourse.values.map((v) => v.name).toList(),
};

/// The enums `tables.dart` actually persists, read out of the source.
///
/// Read from the file rather than listed by hand, so that a new `textEnum`
/// column cannot be added without this file noticing. A guard that has to be
/// updated in order to cover a new case covers nothing on the day it matters.
Set<String> _persistedInTables() {
  final source = File('lib/data/db/tables.dart').readAsStringSync();
  return RegExp(r'textEnum<(\w+)>')
      .allMatches(source)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  test('every enum stored in a column is pinned here', () {
    final persisted = _persistedInTables();
    expect(
      persisted,
      isNotEmpty,
      reason:
          'no textEnum columns found in lib/data/db/tables.dart. Either the '
          'columns moved or this test stopped looking where they live, and a '
          'guard that finds nothing passes for the wrong reason.',
    );
    expect(
      _live().keys.toSet(),
      persisted,
      reason:
          'the enums this test checks and the enums tables.dart stores have '
          'drifted apart. Add the new one to _live() and to _pinned, or the '
          'rule below simply will not apply to it.',
    );
    expect(
      _pinned[AppDatabase.latestSchemaVersion]!.keys.toSet(),
      persisted,
      reason:
          'a persisted enum is missing from the v${AppDatabase.latestSchemaVersion} '
          'manifest.',
    );
  });

  test('every shipped schema version has a manifest', () {
    expect(
      _pinned.keys.toList()..sort(),
      List<int>.generate(AppDatabase.latestSchemaVersion, (i) => i + 1),
      reason:
          'schemaVersion is ${AppDatabase.latestSchemaVersion} but the pinned '
          'versions are ${_pinned.keys.toList()}. Each version needs the set of '
          'enum names a database written by it can contain.',
    );
  });

  test('no persisted enum has widened since the version was last bumped', () {
    // The assertion the file is for. It fails on the commit that adds an enum
    // value, which is the only moment at which the fix is cheap.
    expect(
      _live(),
      _pinned[AppDatabase.latestSchemaVersion],
      reason:
          'a persisted enum gained or lost a value without a schema-version '
          'bump.\n\n'
          'Storage does not care — these are written by name, so no column '
          'moved and no migration is needed. The reader does: an older build '
          'resolves a stored name with values.byName and throws on one it does '
          'not have, and it will not refuse the file first, because the schema '
          'version still looks like its own. The version bump is the only '
          'thing that turns that crash into a refusal.\n\n'
          'So: run tools/scripts/new_migration.sh to bump '
          'AppDatabase.latestSchemaVersion and dump the snapshot, then add the '
          'new value set under the new version key in this file. Leave the '
          'existing entries alone.',
    );
  });

  test('no name that a shipped version could have written was ever dropped', () {
    // Removing or renaming a value is worse than adding one: a name already
    // written to a real device becomes unreadable by the build that is supposed
    // to be able to read it, and no version bump helps, because the row is in
    // the file the user already has. Order is deliberately not checked — that
    // is precisely what storing by name buys.
    for (var v = 1; v < AppDatabase.latestSchemaVersion; v++) {
      final older = _pinned[v]!;
      final newer = _pinned[v + 1]!;
      for (final entry in older.entries) {
        expect(
          newer[entry.key],
          isNotNull,
          reason:
              '${entry.key} was persisted at v$v and is absent at v${v + 1}. '
              'Rows written by v$v still contain those names. (An enum that is '
              'new at v${v + 1} is fine and is not what this checks — this is '
              'about one disappearing.)',
        );
        expect(
          entry.value.toSet().difference(newer[entry.key]!.toSet()),
          isEmpty,
          reason:
              '${entry.key} lost a value between v$v and v${v + 1}. Any device '
              'that stored it can no longer read its own row, and there is no '
              'migration that recovers a name the code has forgotten. Rename '
              'the label shown to the user, not the enum member.',
        );
      }
    }
  });

  test('an unknown stored name throws when read, rather than degrading', () async {
    // The reason for all of the above, executed rather than asserted in prose:
    // this is exactly what an old build does with a row a newer one wrote.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // The write is not the assertion, and is awaited on its own so that it
    // cannot be what satisfies it. The column is plain TEXT with no check
    // constraint, so this succeeds — which is the point: nothing at the
    // storage layer objects to a name the code has never heard of.
    await db.customStatement(
      "INSERT INTO day_logs (epoch_day, flow) VALUES (20000, 'torrential')",
    );

    await expectLater(
      db.dayLogDao.allLogs(),
      throwsA(isArgumentError),
      reason:
          'reading a flow value this build does not know returned instead of '
          'throwing. If drift has started tolerating unknown names, the failure '
          'mode is now a silently wrong reading of health data, which is worse '
          'than the crash this rule was written for — check what it returns '
          'before relaxing anything here.',
    );
  });
}
