// Protected backups: an export sealed with a passphrase (ADR-0019).
//
// The tests seal with a low iteration count, because the real one is meant to
// be slow; one test runs the real count, on another isolate, as the app does.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/result.dart';
import 'package:period_tracker/data/transfer/protected_backup.dart';

const String _export = '{\n  "schema_version": 3,\n  "day_logs": []\n}';

const BackupSealer _fast = BackupSealer(iterations: 1000, inBackground: false);

Map<String, Object?> _fields(String sealed) =>
    jsonDecode(sealed)! as Map<String, Object?>;

String _with(String sealed, void Function(Map<String, Object?>) change) {
  final fields = _fields(sealed);
  change(fields);
  return jsonEncode(fields);
}

void main() {
  group('a protected backup', () {
    test('opens with its passphrase to exactly the export it sealed', () async {
      final sealed = await _fast.seal(_export, 'four unrelated words');
      final opened = await _fast.open(sealed, 'four unrelated words');
      expect(opened.valueOrNull, _export);
    });

    test('does not contain the export it sealed', () async {
      final sealed = await _fast.seal(_export, 'four unrelated words');
      expect(sealed, isNot(contains('day_logs')));
      expect(sealed, isNot(contains('schema_version')));
    });

    test('is recognised as one, and an ordinary export is not', () async {
      final sealed = await _fast.seal(_export, 'four unrelated words');
      expect(ProtectedBackup.isProtected(sealed), isTrue);
      expect(ProtectedBackup.isProtected(_export), isFalse);
      expect(ProtectedBackup.isProtected('not json'), isFalse);
    });

    test('records how it was sealed, so a later build can open it', () async {
      final fields = _fields(await _fast.seal(_export, 'four unrelated words'));
      expect(fields['format'], ProtectedBackup.formatName);
      expect(fields['version'], ProtectedBackup.formatVersion);
      final kdf = fields['kdf']! as Map<String, Object?>;
      expect(kdf['name'], 'pbkdf2-hmac-sha256');
      expect(kdf['iterations'], 1000);
      expect(base64.decode(kdf['salt']! as String), hasLength(16));
      final cipher = fields['cipher']! as Map<String, Object?>;
      expect(cipher['name'], 'aes-256-gcm');
      expect(base64.decode(cipher['nonce']! as String), hasLength(12));
    });

    test('gets a new salt and nonce every time it is sealed', () async {
      final one = _fields(await _fast.seal(_export, 'four unrelated words'));
      final two = _fields(await _fast.seal(_export, 'four unrelated words'));
      expect(
        (one['kdf']! as Map<String, Object?>)['salt'],
        isNot((two['kdf']! as Map<String, Object?>)['salt']),
      );
      expect(one['ciphertext'], isNot(two['ciphertext']));
    });

    test('opens on a passphrase outside ASCII, as typed', () async {
      final sealed = await _fast.seal(_export, 'mot de passe très long 🌙');
      expect(
        (await _fast.open(sealed, 'mot de passe très long 🌙')).valueOrNull,
        _export,
      );
    });
  });

  group('refuses to open', () {
    late String sealed;
    setUp(() async {
      sealed = await _fast.seal(
        _export,
        'four unrelated words',
        random: Random(1),
      );
    });

    Future<ProtectedBackupRefusal?> refusal(
      String text, [
      String? passphrase,
    ]) async => (await _fast.open(
      text,
      passphrase ?? 'four unrelated words',
    )).errorOrNull;

    test('with the wrong passphrase', () async {
      expect(
        await refusal(sealed, 'four unrelated word'),
        ProtectedBackupRefusal.wrongPassphrase,
      );
    });

    test('a file changed after it was sealed', () async {
      final altered = _with(sealed, (fields) {
        final bytes = base64.decode(fields['ciphertext']! as String);
        bytes[0] ^= 1;
        fields['ciphertext'] = base64.encode(bytes);
      });
      expect(await refusal(altered), ProtectedBackupRefusal.wrongPassphrase);
    });

    test('a file relabelled with another version', () async {
      // The version is bound to the ciphertext, so it cannot be edited to
      // send the file down another version's path.
      final relabelled = _with(sealed, (fields) => fields['version'] = 0);
      expect(await refusal(relabelled), ProtectedBackupRefusal.damaged);
    });

    test('a file from a newer build, saying so', () async {
      final newer = _with(sealed, (fields) => fields['version'] = 2);
      expect(await refusal(newer), ProtectedBackupRefusal.newerVersion);
      final otherCipher = _with(
        sealed,
        (fields) => (fields['cipher']! as Map<String, Object?>)['name'] =
            'xchacha20-poly1305',
      );
      expect(await refusal(otherCipher), ProtectedBackupRefusal.newerVersion);
    });

    test('a file asking for an unreasonable amount of work', () async {
      // The key is derived before anything can be checked, so a crafted file
      // could otherwise hold the app for hours.
      final greedy = _with(
        sealed,
        (fields) => (fields['kdf']! as Map<String, Object?>)['iterations'] =
            ProtectedBackup.maxIterations + 1,
      );
      expect(await refusal(greedy), ProtectedBackupRefusal.damaged);
    });

    test('anything that is not a whole protected backup', () async {
      for (final text in <String>[
        'not json',
        '[]',
        _export,
        _with(sealed, (fields) => fields.remove('kdf')),
        _with(sealed, (fields) => fields['ciphertext'] = 'not base64!'),
        _with(
          sealed,
          (fields) => (fields['kdf']! as Map<String, Object?>)['salt'] = base64
              .encode(<int>[1, 2, 3]),
        ),
        _with(
          sealed,
          (fields) => fields['ciphertext'] = base64.encode(<int>[1]),
        ),
      ]) {
        expect(
          await refusal(text),
          ProtectedBackupRefusal.damaged,
          reason: text,
        );
      }
    });
  });

  test('is sealed with at least the 600,000 iterations OWASP gives', () {
    expect(ProtectedBackup.iterations, greaterThanOrEqualTo(600000));
    expect(const BackupSealer().iterations, ProtectedBackup.iterations);
  });

  test(
    'round-trips at the real count, on another isolate, as the app does',
    () async {
      const sealer = BackupSealer();
      final sealed = await sealer.seal(_export, 'four unrelated words');
      expect(
        (_fields(sealed)['kdf']! as Map<String, Object?>)['iterations'],
        ProtectedBackup.iterations,
      );
      final opened = await sealer.open(sealed, 'four unrelated words');
      expect(opened, isA<Ok<String, ProtectedBackupRefusal>>());
      expect(opened.valueOrNull, _export);
    },
  );

  test('is offered under a name that says it is protected', () {
    expect(
      ProtectedBackup.suggestedFileName(FixedClock.iso('2026-10-28')),
      'period-tracker-export-2026-10-28-protected.json',
    );
  });
}
