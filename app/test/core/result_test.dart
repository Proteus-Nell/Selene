import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracker/core/result.dart';

/// Stand-in domain error for these tests.
enum _Failure { tooShort, notFound }

void main() {
  group('Ok', () {
    const ok = Ok<int, _Failure>(7);

    test('reports success', () {
      expect(ok.isOk, isTrue);
      expect(ok.isErr, isFalse);
    });

    test('exposes its value', () {
      expect(ok.valueOrNull, 7);
      expect(ok.errorOrNull, isNull);
      expect(ok.valueOr(99), 7);
    });

    test('map transforms the value', () {
      expect(ok.map((v) => v * 2), const Ok<int, _Failure>(14));
    });

    test('mapError leaves it untouched', () {
      expect(ok.mapError((e) => e.name), const Ok<int, String>(7));
    });

    test('fold takes the ok branch', () {
      expect(ok.fold((v) => 'v$v', (e) => 'e$e'), 'v7');
    });

    test('andThen chains', () {
      expect(
        ok.andThen((v) => Ok<String, _Failure>('got $v')),
        const Ok<String, _Failure>('got 7'),
      );
      expect(
        ok.andThen((v) => const Err<String, _Failure>(_Failure.notFound)),
        const Err<String, _Failure>(_Failure.notFound),
      );
    });
  });

  group('Err', () {
    const err = Err<int, _Failure>(_Failure.tooShort);

    test('reports failure', () {
      expect(err.isOk, isFalse);
      expect(err.isErr, isTrue);
    });

    test('exposes its error', () {
      expect(err.valueOrNull, isNull);
      expect(err.errorOrNull, _Failure.tooShort);
      expect(err.valueOr(99), 99);
    });

    test('map is a no-op that preserves the error', () {
      expect(
        err.map((v) => v * 2),
        const Err<int, _Failure>(_Failure.tooShort),
      );
    });

    test('mapError transforms the error', () {
      expect(err.mapError((e) => e.name), const Err<int, String>('tooShort'));
    });

    test('fold takes the err branch', () {
      expect(err.fold((v) => 'v$v', (e) => 'e${e.name}'), 'etooShort');
    });

    test('andThen short-circuits without running the callback', () {
      var ran = false;
      final result = err.andThen<String>((v) {
        ran = true;
        return Ok<String, _Failure>('$v');
      });
      expect(ran, isFalse);
      expect(result, const Err<String, _Failure>(_Failure.tooShort));
    });
  });

  group('exhaustiveness', () {
    test('a switch over Result needs no default clause', () {
      // This compiles only because Result is sealed. If a third subclass were
      // added, every switch like this becomes a compile error rather than
      // silently falling through, which is the reason for the sealed type.
      String describe(Result<int, _Failure> r) => switch (r) {
        Ok<int, _Failure>(:final value) => 'ok $value',
        Err<int, _Failure>(:final error) => 'err ${error.name}',
      };

      expect(describe(const Ok<int, _Failure>(1)), 'ok 1');
      expect(
        describe(const Err<int, _Failure>(_Failure.notFound)),
        'err notFound',
      );
    });
  });

  group('equality', () {
    test('is by value', () {
      expect(const Ok<int, _Failure>(1), const Ok<int, _Failure>(1));
      expect(const Ok<int, _Failure>(1), isNot(const Ok<int, _Failure>(2)));
      expect(
        const Err<int, _Failure>(_Failure.tooShort),
        const Err<int, _Failure>(_Failure.tooShort),
      );
      expect(
        const Ok<int, _Failure>(1),
        isNot(const Err<int, _Failure>(_Failure.tooShort)),
      );
    });

    test('hashCode agrees with equality', () {
      expect(
        const Ok<int, _Failure>(1).hashCode,
        const Ok<int, _Failure>(1).hashCode,
      );
    });
  });
}
