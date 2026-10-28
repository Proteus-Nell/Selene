/// Database key.
///
/// The key the database file is encrypted with, and where it is kept
/// (ADR-0018). The key is 32 random bytes, made on the phone the first time
/// the database is opened by a build that encrypts it, and kept by Android's
/// Keystore. It never leaves the phone, is never shown, and is not in any
/// export: an export is readable on its own, or protected by a passphrase the
/// user chooses.
///
/// Includes:
///     - DatabaseKeyUnavailableException: The key store could not be read.
///     - DatabaseKeyStore: Where the key is kept.
///     - KeystoreDatabaseKeyStore: The store the app uses.
///     - MemoryDatabaseKeyStore: A store for tests.
///     - newDatabaseKey, isDatabaseKey: Making and checking a key.
library;

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Database key unavailable exception: the key store could not be read.
///
/// Distinct from finding no key. No key means none was ever made, and one can
/// be made now. A store that cannot be read may still hold the key, and making
/// a new one would lock the database for good, so the open stops instead and
/// the next launch tries again.
///
/// Attributes:
///     cause (Object): What the store threw.
final class DatabaseKeyUnavailableException implements Exception {
  /// Wraps what the store threw in [cause].
  ///
  /// Args:
  ///     cause (Object): What the store threw.
  const DatabaseKeyUnavailableException(this.cause);

  /// What the store threw.
  final Object cause;

  @override
  String toString() => 'DatabaseKeyUnavailableException: $cause';
}

/// Database key store: where the key that opens the database is kept.
abstract interface class DatabaseKeyStore {
  /// Return the stored key.
  ///
  /// Returns:
  ///     `Future<String?>`: The key, or null when none has been stored.
  ///
  /// Throws:
  ///     DatabaseKeyUnavailableException: When the store cannot be read.
  Future<String?> read();

  /// Store [key], replacing nothing: called only when [read] found none.
  ///
  /// Args:
  ///     key (String): A key from [newDatabaseKey].
  ///
  /// Throws:
  ///     DatabaseKeyUnavailableException: When the store cannot be written.
  Future<void> write(String key);
}

/// Keystore database key store: the key, kept by Android's Keystore.
///
/// Through `flutter_secure_storage`, which wraps the value with an RSA key
/// held by the Keystore and encrypts it with AES-GCM. A plugin rather than a
/// channel in this app's own Android code, because the notification action
/// opens the database from a background engine, and plugins are registered
/// there while the app's own channels are not.
///
/// `resetOnError` is off. With it on, one failed read would wipe the store,
/// and with it the only key to the database.
final class KeystoreDatabaseKeyStore implements DatabaseKeyStore {
  /// Creates the store.
  const KeystoreDatabaseKeyStore();

  /// The name the key is stored under. A new name, not a new value, if the
  /// key's format ever changes.
  static const String keyName = 'database_key_v1';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: keyName);
    } on Object catch (error) {
      throw DatabaseKeyUnavailableException(error);
    }
  }

  @override
  Future<void> write(String key) async {
    try {
      await _storage.write(key: keyName, value: key);
    } on Object catch (error) {
      throw DatabaseKeyUnavailableException(error);
    }
  }
}

/// Memory database key store: a key held in a field, for tests.
///
/// Attributes:
///     key (String?): The stored key, or null.
///     failing (bool): Whether every call throws, as an unreadable store does.
final class MemoryDatabaseKeyStore implements DatabaseKeyStore {
  /// Creates a store holding [key], which defaults to none.
  ///
  /// Args:
  ///     key (String?, optional): The key to start with. Defaults to null.
  ///     failing (bool, optional): Whether every call throws. Defaults to
  ///         false.
  MemoryDatabaseKeyStore({this.key, this.failing = false});

  /// The stored key, or null.
  String? key;

  /// Whether every call throws, as an unreadable store does.
  bool failing;

  @override
  Future<String?> read() async {
    if (failing) throw const DatabaseKeyUnavailableException('unreadable');
    return key;
  }

  @override
  Future<void> write(String key) async {
    if (failing) throw const DatabaseKeyUnavailableException('unwritable');
    this.key = key;
  }
}

/// Make a new database key: 32 bytes from a secure generator, as hex.
///
/// Args:
///     random (Random?, optional): The generator. Defaults to
///         [Random.secure], and only a test passes anything else.
///
/// Returns:
///     String: 64 lowercase hex digits.
String newDatabaseKey([Random? random]) {
  final source = random ?? Random.secure();
  return <String>[
    for (var i = 0; i < 32; i++)
      source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// Whether [key] has the shape [newDatabaseKey] makes.
///
/// Checked before a key goes into a pragma, which cannot take a bound
/// parameter, so nothing but hex digits ever reaches the SQL.
///
/// Args:
///     key (String): The candidate.
///
/// Returns:
///     bool: True for exactly 64 lowercase hex digits.
bool isDatabaseKey(String key) => _keyShape.hasMatch(key);

final RegExp _keyShape = RegExp(r'^[0-9a-f]{64}$');
