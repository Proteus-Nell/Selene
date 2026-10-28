/// PBKDF2 with HMAC-SHA256.
///
/// The key derivation behind a protected backup (ADR-0019). Written here rather
/// than taken from a library because the libraries recompute HMAC's two padded
/// key blocks on every one of the 600,000 iterations, which is half the work,
/// and on a phone that is the difference between a pause and a wait. The two
/// blocks are hashed once, and each iteration then costs exactly two SHA-256
/// compressions.
///
/// It is the standard construction (RFC 8018), checked against the RFC 7914
/// test vectors and against pointycastle's own PBKDF2 in `pbkdf2_test.dart`,
/// so a backup it seals can be opened by any other implementation.
///
/// Includes:
///     - pbkdf2HmacSha256: The derivation.
library;

import 'dart:typed_data';

/// SHA-256's round constants.
const List<int> _k = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

/// SHA-256's initial hash value.
const List<int> _initial = <int>[
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

const int _mask = 0xffffffff;

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

/// One SHA-256 compression of the 16 words in [w] into [state].
///
/// [w] is a 64-word schedule buffer whose first 16 words hold the block; the
/// rest are overwritten.
void _compress(Uint32List state, Uint32List w) {
  for (var t = 16; t < 64; t++) {
    final w15 = w[t - 15];
    final w2 = w[t - 2];
    final s0 = _rotr(w15, 7) ^ _rotr(w15, 18) ^ (w15 >> 3);
    final s1 = _rotr(w2, 17) ^ _rotr(w2, 19) ^ (w2 >> 10);
    w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & _mask;
  }
  var a = state[0];
  var b = state[1];
  var c = state[2];
  var d = state[3];
  var e = state[4];
  var f = state[5];
  var g = state[6];
  var h = state[7];
  for (var t = 0; t < 64; t++) {
    final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
    final ch = (e & f) ^ (~e & _mask & g);
    final t1 = (h + s1 + ch + _k[t] + w[t]) & _mask;
    final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
    final maj = (a & b) ^ (a & c) ^ (b & c);
    final t2 = (s0 + maj) & _mask;
    h = g;
    g = f;
    f = e;
    e = (d + t1) & _mask;
    d = c;
    c = b;
    b = a;
    a = (t1 + t2) & _mask;
  }
  state[0] = (state[0] + a) & _mask;
  state[1] = (state[1] + b) & _mask;
  state[2] = (state[2] + c) & _mask;
  state[3] = (state[3] + d) & _mask;
  state[4] = (state[4] + e) & _mask;
  state[5] = (state[5] + f) & _mask;
  state[6] = (state[6] + g) & _mask;
  state[7] = (state[7] + h) & _mask;
}

/// Hash [message] in full with SHA-256, for keys and salts of any length.
Uint8List _sha256(List<int> message) {
  final length = message.length;
  final padded = Uint8List(((length + 9 + 63) ~/ 64) * 64)
    ..setRange(0, length, message);
  padded[length] = 0x80;
  final bits = length * 8;
  for (var i = 0; i < 8; i++) {
    padded[padded.length - 1 - i] = (bits >> (8 * i)) & 0xff;
  }
  final state = Uint32List.fromList(_initial);
  final w = Uint32List(64);
  for (var offset = 0; offset < padded.length; offset += 64) {
    for (var i = 0; i < 16; i++) {
      final j = offset + 4 * i;
      w[i] =
          (padded[j] << 24) |
          (padded[j + 1] << 16) |
          (padded[j + 2] << 8) |
          padded[j + 3];
    }
    _compress(state, w);
  }
  return _bytes(state);
}

Uint8List _bytes(Uint32List words) {
  final out = Uint8List(words.length * 4);
  for (var i = 0; i < words.length; i++) {
    out[4 * i] = words[i] >> 24;
    out[4 * i + 1] = (words[i] >> 16) & 0xff;
    out[4 * i + 2] = (words[i] >> 8) & 0xff;
    out[4 * i + 3] = words[i] & 0xff;
  }
  return out;
}

/// The SHA-256 state after one 64-byte block, which is a padded HMAC key.
Uint32List _stateAfter(Uint8List block) {
  final state = Uint32List.fromList(_initial);
  final w = Uint32List(64);
  for (var i = 0; i < 16; i++) {
    w[i] =
        (block[4 * i] << 24) |
        (block[4 * i + 1] << 16) |
        (block[4 * i + 2] << 8) |
        block[4 * i + 3];
  }
  _compress(state, w);
  return state;
}

/// HMAC-SHA256 of a 32-byte [digest], continuing from the pad states.
///
/// The message is always one SHA-256 output, so after the 64-byte pad block
/// each hash has exactly one more block to process: the 32 bytes, the 0x80
/// marker, and a length of 96 bytes. Writes the result back into [digest].
void _hmacOfDigest(
  Uint32List inner,
  Uint32List outer,
  Uint32List digest,
  Uint32List state,
  Uint32List w,
) {
  for (var pass = 0; pass < 2; pass++) {
    state.setAll(0, pass == 0 ? inner : outer);
    w
      ..setAll(0, digest)
      ..[8] = 0x80000000;
    for (var i = 9; i < 15; i++) {
      w[i] = 0;
    }
    w[15] = (64 + 32) * 8;
    _compress(state, w);
    digest.setAll(0, state);
  }
}

/// Derive [length] bytes from [password] and [salt] with PBKDF2-HMAC-SHA256.
///
/// Args:
///     password (`List<int>`): The passphrase, as UTF-8.
///     salt (`List<int>`): Random, and stored beside what is sealed.
///     iterations (int): At least 1.
///     length (int): Bytes wanted, at least 1.
///
/// Returns:
///     Uint8List: The derived key.
///
/// Throws:
///     ArgumentError: For an iteration count or a length below 1.
Uint8List pbkdf2HmacSha256(
  List<int> password,
  List<int> salt, {
  required int iterations,
  required int length,
}) {
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations', 'must be at least 1');
  }
  if (length < 1) throw ArgumentError.value(length, 'length', 'must be >= 1');

  final key = Uint8List(64)
    ..setAll(0, password.length > 64 ? _sha256(password) : password);
  final ipad = Uint8List(64);
  final opad = Uint8List(64);
  for (var i = 0; i < 64; i++) {
    ipad[i] = key[i] ^ 0x36;
    opad[i] = key[i] ^ 0x5c;
  }
  final inner = _stateAfter(ipad);
  final outer = _stateAfter(opad);

  final out = Uint8List(length);
  final digest = Uint32List(8);
  final total = Uint32List(8);
  final state = Uint32List(8);
  final w = Uint32List(64);
  for (var block = 1, written = 0; written < length; block++) {
    // U1 = HMAC(password, salt || INT(block)), hashed in full once.
    final first = _sha256(<int>[
      ...ipad,
      ...salt,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ]);
    final u1 = _sha256(<int>[...opad, ...first]);
    for (var i = 0; i < 8; i++) {
      digest[i] =
          (u1[4 * i] << 24) |
          (u1[4 * i + 1] << 16) |
          (u1[4 * i + 2] << 8) |
          u1[4 * i + 3];
    }
    total.setAll(0, digest);
    for (var round = 1; round < iterations; round++) {
      _hmacOfDigest(inner, outer, digest, state, w);
      for (var i = 0; i < 8; i++) {
        total[i] ^= digest[i];
      }
    }
    final bytes = _bytes(total);
    final take = length - written < 32 ? length - written : 32;
    out.setRange(written, written + take, bytes);
    written += take;
  }
  return out;
}
