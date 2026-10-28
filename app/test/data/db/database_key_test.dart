// The key the database is encrypted with (ADR-0018).
//
// What is pinned here is the shape of the key, which is the only thing that
// stands between it and the pragma it is spliced into, and that the store the
// app uses keeps what it is given.

import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/data/db/connection.dart';
import 'package:period_tracker/data/db/database.dart';
import 'package:period_tracker/data/db/database_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a new key', () {
    test('is 64 hex digits, which is 32 bytes', () {
      final key = newDatabaseKey();
      expect(key, hasLength(64));
      expect(isDatabaseKey(key), isTrue);
    });

    test('is different every time', () {
      final keys = <String>{for (var i = 0; i < 50; i++) newDatabaseKey()};
      expect(keys, hasLength(50));
    });

    test('comes from the generator it is given', () {
      expect(newDatabaseKey(Random(7)), newDatabaseKey(Random(7)));
    });
  });

  group('the shape check', () {
    test('refuses anything a pragma could be steered by', () {
      for (final bad in <String>[
        '',
        'ab' * 31,
        'ab' * 33,
        'AB' * 32,
        "${'ab' * 31}'-",
        "x' ; DROP TABLE day_logs; --",
      ]) {
        expect(isDatabaseKey(bad), isFalse, reason: bad);
      }
    });

    test('is checked before the key reaches the database', () async {
      // A key that is not the right shape never gets as far as SQL. The
      // connection refuses it on open.
      final directory = Directory.systemTemp.createTempSync('key_shape');
      addTearDown(() => directory.deleteSync(recursive: true));
      final db = AppDatabase(
        createQueryExecutor(
          File('${directory.path}/x.sqlite'),
          key: "'; ATTACH DATABASE 'elsewhere' AS e; --",
        ),
      );
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(isA<ArgumentError>()),
      );
      await db.close();
    });
  });

  group('the Keystore store', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

    test('has nothing before a key is written', () async {
      expect(await const KeystoreDatabaseKeyStore().read(), isNull);
    });

    test('gives back the key it was given', () async {
      const store = KeystoreDatabaseKeyStore();
      final key = newDatabaseKey();
      await store.write(key);
      expect(await store.read(), key);
    });
  });

  group('the memory store', () {
    test('throws as an unreadable store does, when told to', () async {
      final store = MemoryDatabaseKeyStore(failing: true);
      await expectLater(
        store.read(),
        throwsA(isA<DatabaseKeyUnavailableException>()),
      );
      await expectLater(
        store.write(newDatabaseKey()),
        throwsA(isA<DatabaseKeyUnavailableException>()),
      );
    });
  });
}
