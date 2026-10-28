/// Protected backup.
///
/// An export sealed with a passphrase the person chooses, so a backup can be
/// kept where others might reach it, such as a cloud drive or an email to
/// oneself, and still be read only by someone who knows the passphrase
/// (ADR-0019). The database key cannot do this: it never leaves the phone, and
/// it is gone once the app is uninstalled.
///
/// The sealed file is JSON too, so it is one file, with the extension the
/// import already accepts:
///
/// ```json
/// {
///   "format": "selene-protected-backup",
///   "version": 1,
///   "kdf": {"name": "pbkdf2-hmac-sha256", "iterations": 600000, "salt": "…"},
///   "cipher": {"name": "aes-256-gcm", "nonce": "…"},
///   "ciphertext": "…"
/// }
/// ```
///
/// Inside is the ordinary export, byte for byte, so opening a protected backup
/// hands the import exactly what an unprotected one would have, and every check
/// the import makes still runs.
///
/// Includes:
///     - ProtectedBackupRefusal: Why a protected backup did not open.
///     - ProtectedBackup: The format, and the check for it.
///     - BackupSealer: Sealing and opening, off the UI isolate.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/core/result.dart';
import 'package:period_tracker/data/transfer/pbkdf2.dart';
import 'package:pointycastle/export.dart';

/// Protected backup refusal: why a protected backup did not open.
enum ProtectedBackupRefusal {
  /// The passphrase is not the one it was sealed with. Indistinguishable, by
  /// design of the cipher, from a file altered after it was sealed.
  wrongPassphrase,

  /// Sealed by a newer build, in a format or with an algorithm this one does
  /// not know.
  newerVersion,

  /// Not a well-formed protected backup.
  damaged,
}

/// Protected backup: the format, and the check for it.
abstract final class ProtectedBackup {
  /// The value of the `format` field.
  static const String formatName = 'selene-protected-backup';

  /// The newest version this build seals and opens.
  static const int formatVersion = 1;

  /// PBKDF2-HMAC-SHA256 iterations for a new seal: OWASP's 2023 figure.
  ///
  /// Each file records its own count, so raising this later leaves every
  /// existing backup openable.
  static const int iterations = 600000;

  /// The most iterations a file may ask for. A file is opened only after its
  /// key is derived, so without a ceiling a crafted one could hold the app for
  /// hours.
  static const int maxIterations = 5000000;

  /// The shortest passphrase the export accepts.
  static const int minimumPassphraseLength = 8;

  static const String _kdfName = 'pbkdf2-hmac-sha256';
  static const String _cipherName = 'aes-256-gcm';
  static const int _saltBytes = 16;
  static const int _nonceBytes = 12;
  static const int _tagBits = 128;

  /// Whether [text] is a protected backup rather than an ordinary export.
  ///
  /// Args:
  ///     text (String): The file's contents.
  ///
  /// Returns:
  ///     bool: True when it is a JSON object naming this format.
  static bool isProtected(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, Object?> && decoded['format'] == formatName;
    } on FormatException {
      return false;
    }
  }

  /// The name a protected export is offered under.
  ///
  /// Args:
  ///     clock (Clock): Supplies the date in the name.
  ///
  /// Returns:
  ///     String: A `.json` name, as an ordinary export has, marked protected.
  static String suggestedFileName(Clock clock) =>
      'period-tracker-export-${clock.today().toIso8601()}-protected.json';

  /// Associated data: the format and version are bound to the ciphertext, so
  /// a file relabelled as another version fails to open.
  static Uint8List _associatedData(int version) =>
      Uint8List.fromList(utf8.encode('$formatName/$version'));
}

/// Backup sealer: seals an export with a passphrase, and opens one.
///
/// The key derivation is deliberately slow, a second or more on a phone, so it
/// runs on another isolate and the screen stays responsive. A test can lower
/// the iterations and keep the work on its own isolate, where widget tests can
/// wait for it.
///
/// Attributes:
///     iterations (int): The count new seals use.
///     inBackground (bool): Whether the work runs on another isolate.
final class BackupSealer {
  /// Creates a sealer.
  ///
  /// Args:
  ///     iterations (int, optional): Defaults to
  ///         [ProtectedBackup.iterations]. Only a test passes anything else.
  ///     inBackground (bool, optional): Defaults to true.
  const BackupSealer({
    this.iterations = ProtectedBackup.iterations,
    this.inBackground = true,
  });

  /// The count new seals use.
  final int iterations;

  /// Whether the work runs on another isolate.
  final bool inBackground;

  /// Seal [export] with [passphrase].
  ///
  /// Args:
  ///     export (String): The ordinary export's contents.
  ///     passphrase (String): What the person chose, as typed.
  ///     random (Random?, optional): Source of the salt and nonce. Defaults
  ///         to [Random.secure]; only a test passes anything else.
  ///
  /// Returns:
  ///     `Future<String>`: The protected backup's contents.
  Future<String> seal(String export, String passphrase, {Random? random}) {
    final source = random ?? Random.secure();
    final salt = _randomBytes(source, ProtectedBackup._saltBytes);
    final nonce = _randomBytes(source, ProtectedBackup._nonceBytes);
    final count = iterations;
    String work() => _seal(export, passphrase, salt, nonce, count);
    return inBackground ? Isolate.run(work) : Future<String>.value(work());
  }

  /// Open a protected backup with [passphrase].
  ///
  /// Args:
  ///     text (String): The protected backup's contents.
  ///     passphrase (String): What the person typed.
  ///
  /// Returns:
  ///     `Future<Result<String, ProtectedBackupRefusal>>`: The ordinary
  ///     export inside, or why it did not open.
  Future<Result<String, ProtectedBackupRefusal>> open(
    String text,
    String passphrase,
  ) {
    Result<String, ProtectedBackupRefusal> work() => _open(text, passphrase);
    return inBackground
        ? Isolate.run(work)
        : Future<Result<String, ProtectedBackupRefusal>>.value(work());
  }
}

Uint8List _randomBytes(Random random, int count) => Uint8List.fromList(<int>[
  for (var i = 0; i < count; i++) random.nextInt(256),
]);

Uint8List _key(String passphrase, Uint8List salt, int iterations) =>
    pbkdf2HmacSha256(
      utf8.encode(passphrase),
      salt,
      iterations: iterations,
      length: 32,
    );

GCMBlockCipher _cipher({
  required bool forEncryption,
  required Uint8List key,
  required Uint8List nonce,
  required int version,
}) => GCMBlockCipher(AESEngine())
  ..init(
    forEncryption,
    AEADParameters(
      KeyParameter(key),
      ProtectedBackup._tagBits,
      nonce,
      ProtectedBackup._associatedData(version),
    ),
  );

String _seal(
  String export,
  String passphrase,
  Uint8List salt,
  Uint8List nonce,
  int iterations,
) {
  const version = ProtectedBackup.formatVersion;
  final cipher = _cipher(
    forEncryption: true,
    key: _key(passphrase, salt, iterations),
    nonce: nonce,
    version: version,
  );
  final sealed = cipher.process(Uint8List.fromList(utf8.encode(export)));
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'format': ProtectedBackup.formatName,
    'version': version,
    'kdf': <String, Object?>{
      'name': ProtectedBackup._kdfName,
      'iterations': iterations,
      'salt': base64.encode(salt),
    },
    'cipher': <String, Object?>{
      'name': ProtectedBackup._cipherName,
      'nonce': base64.encode(nonce),
    },
    'ciphertext': base64.encode(sealed),
  });
}

Result<String, ProtectedBackupRefusal> _open(String text, String passphrase) {
  Err<String, ProtectedBackupRefusal> refuse(ProtectedBackupRefusal why) =>
      Err<String, ProtectedBackupRefusal>(why);

  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return refuse(ProtectedBackupRefusal.damaged);
  }
  if (decoded is! Map<String, Object?> ||
      decoded['format'] != ProtectedBackup.formatName) {
    return refuse(ProtectedBackupRefusal.damaged);
  }
  final version = decoded['version'];
  if (version is! int || version < 1) {
    return refuse(ProtectedBackupRefusal.damaged);
  }
  if (version > ProtectedBackup.formatVersion) {
    return refuse(ProtectedBackupRefusal.newerVersion);
  }
  final kdf = decoded['kdf'];
  final cipher = decoded['cipher'];
  final ciphertext = decoded['ciphertext'];
  if (kdf is! Map<String, Object?> ||
      cipher is! Map<String, Object?> ||
      ciphertext is! String) {
    return refuse(ProtectedBackupRefusal.damaged);
  }
  if (kdf['name'] != ProtectedBackup._kdfName ||
      cipher['name'] != ProtectedBackup._cipherName) {
    // An algorithm this build does not know is a later build's choice.
    return refuse(ProtectedBackupRefusal.newerVersion);
  }
  final iterations = kdf['iterations'];
  if (iterations is! int ||
      iterations < 1 ||
      iterations > ProtectedBackup.maxIterations) {
    return refuse(ProtectedBackupRefusal.damaged);
  }

  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List sealed;
  try {
    salt = base64.decode(kdf['salt']! as String);
    nonce = base64.decode(cipher['nonce']! as String);
    sealed = base64.decode(ciphertext);
  } on Object {
    return refuse(ProtectedBackupRefusal.damaged);
  }
  if (salt.length != ProtectedBackup._saltBytes ||
      nonce.length != ProtectedBackup._nonceBytes ||
      sealed.length < ProtectedBackup._tagBits ~/ 8) {
    return refuse(ProtectedBackupRefusal.damaged);
  }

  final Uint8List plain;
  try {
    plain = _cipher(
      forEncryption: false,
      key: _key(passphrase, salt, iterations),
      nonce: nonce,
      version: version,
    ).process(sealed);
  } on InvalidCipherTextException {
    return refuse(ProtectedBackupRefusal.wrongPassphrase);
  }
  try {
    return Ok<String, ProtectedBackupRefusal>(utf8.decode(plain));
  } on FormatException {
    return refuse(ProtectedBackupRefusal.damaged);
  }
}
