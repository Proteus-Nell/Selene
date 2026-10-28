// PBKDF2-HMAC-SHA256, the key derivation behind protected backups (ADR-0019).
//
// Written here for speed rather than taken from a library, so it is held to
// the standard two ways: the published test vectors, and pointycastle's own
// implementation on inputs the vectors do not reach. A backup sealed with a
// derivation that was merely self-consistent would open in this app and in
// nothing else.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/transfer/pbkdf2.dart';
import 'package:pointycastle/export.dart';

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List reference(
  List<int> password,
  List<int> salt,
  int iterations,
  int length,
) {
  final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, length));
  return kdf.process(Uint8List.fromList(password));
}

void main() {
  group('the RFC 7914 vectors', () {
    test('one iteration, two blocks', () {
      expect(
        hex(
          pbkdf2HmacSha256(
            utf8.encode('passwd'),
            utf8.encode('salt'),
            iterations: 1,
            length: 64,
          ),
        ),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });

    test('80,000 iterations, two blocks', () {
      expect(
        hex(
          pbkdf2HmacSha256(
            utf8.encode('Password'),
            utf8.encode('NaCl'),
            iterations: 80000,
            length: 64,
          ),
        ),
        '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
        'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d',
      );
    });
  });

  group('agrees with pointycastle', () {
    final random = Random(20261028);
    List<int> bytes(int n) => <int>[
      for (var i = 0; i < n; i++) random.nextInt(256),
    ];

    test('for passphrases longer than a block, which HMAC hashes first', () {
      final password = bytes(100);
      final salt = bytes(16);
      expect(
        pbkdf2HmacSha256(password, salt, iterations: 50, length: 32),
        reference(password, salt, 50, 32),
      );
    });

    test('for lengths that are not a whole block', () {
      final password = utf8.encode('a few unrelated words');
      final salt = bytes(16);
      for (final length in <int>[1, 16, 31, 33, 70]) {
        expect(
          pbkdf2HmacSha256(password, salt, iterations: 7, length: length),
          reference(password, salt, 7, length),
          reason: 'length $length',
        );
      }
    });

    test('for an empty salt and a passphrase of exactly one block', () {
      final password = bytes(64);
      expect(
        pbkdf2HmacSha256(password, const <int>[], iterations: 3, length: 32),
        reference(password, const <int>[], 3, 32),
      );
    });

    test('for passphrases outside ASCII, as UTF-8', () {
      final password = utf8.encode('régime 経血 🌙');
      final salt = bytes(16);
      expect(
        pbkdf2HmacSha256(password, salt, iterations: 1000, length: 32),
        reference(password, salt, 1000, 32),
      );
    });
  });

  test('refuses an iteration count or a length below one', () {
    expect(
      () => pbkdf2HmacSha256(
        const <int>[1],
        const <int>[2],
        iterations: 0,
        length: 32,
      ),
      throwsArgumentError,
    );
    expect(
      () => pbkdf2HmacSha256(
        const <int>[1],
        const <int>[2],
        iterations: 1,
        length: 0,
      ),
      throwsArgumentError,
    );
  });
}
