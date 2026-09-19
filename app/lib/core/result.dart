/// Result type for fallible operations.
///
/// Carries success and failure as values rather than as thrown exceptions, so
/// that an expected failure has to be handled at the call site instead of
/// escaping through a `catch`. Domain code returns these; the storage layer
/// still throws.
///
/// Includes:
///     - Result: Sealed base type, with the combinators every case shares.
///     - Ok: The success case, carrying a value.
///     - Err: The failure case, carrying an error.
library;

import 'package:meta/meta.dart';

/// Result of an operation that can fail: either an [Ok] carrying a value or an
/// [Err] carrying an error.
///
/// Domain code returns failures as values rather than throwing. The reason is
/// specific to this app: several expected outcomes are not exceptional at all.
/// "not enough history to predict" and "cycles too irregular to predict" are
/// legitimate states the UI must render, and modelling them as exceptions makes
/// it easy to swallow them in a `catch` and show a confident wrong number
/// instead. See `docs/PLAN.md` 5.5.
///
/// Exceptions stay reserved for genuine programming errors and for the storage
/// layer, where failure really is exceptional.
@immutable
sealed class Result<T, E> {
  /// Const constructor for subclasses.
  const Result();

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T, E>;

  /// Whether this is an [Err].
  bool get isErr => this is Err<T, E>;

  /// The value if this is an [Ok], otherwise null.
  T? get valueOrNull => switch (this) {
    Ok<T, E>(:final value) => value,
    Err<T, E>() => null,
  };

  /// The error if this is an [Err], otherwise null.
  E? get errorOrNull => switch (this) {
    Ok<T, E>() => null,
    Err<T, E>(:final error) => error,
  };

  /// Return the value, or [fallback] if this is an [Err].
  ///
  /// Args:
  ///     fallback (T): What to return in the failure case.
  ///
  /// Returns:
  ///     T: The carried value, or [fallback].
  T valueOr(T fallback) => switch (this) {
    Ok<T, E>(:final value) => value,
    Err<T, E>() => fallback,
  };

  /// Collapse both cases into a single value.
  ///
  /// Args:
  ///     onOk (R Function(T)): Applied to the value of an [Ok].
  ///     onErr (R Function(E)): Applied to the error of an [Err].
  ///
  /// Returns:
  ///     R: Whatever the branch that ran returned.
  R fold<R>(R Function(T value) onOk, R Function(E error) onErr) =>
      switch (this) {
        Ok<T, E>(:final value) => onOk(value),
        Err<T, E>(:final error) => onErr(error),
      };

  /// Apply [transform] to the value, leaving an [Err] untouched.
  ///
  /// Args:
  ///     transform (R Function(T)): Applied only in the [Ok] case.
  ///
  /// Returns:
  ///     `Result<R, E>`: The transformed success, or the original failure.
  Result<R, E> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T, E>(:final value) => Ok<R, E>(transform(value)),
    Err<T, E>(:final error) => Err<R, E>(error),
  };

  /// Apply [transform] to the error, leaving an [Ok] untouched.
  ///
  /// Args:
  ///     transform (F Function(E)): Applied only in the [Err] case.
  ///
  /// Returns:
  ///     `Result<T, F>`: The original success, or the transformed failure.
  Result<T, F> mapError<F>(F Function(E error) transform) => switch (this) {
    Ok<T, E>(:final value) => Ok<T, F>(value),
    Err<T, E>(:final error) => Err<T, F>(transform(error)),
  };

  /// Chain another fallible operation onto a success.
  ///
  /// The first [Err] in a chain short-circuits the rest, which is what makes
  /// a sequence of these readable without nesting.
  ///
  /// Args:
  ///     next (`Result<R, E> Function(T)`): Runs only in the [Ok] case.
  ///
  /// Returns:
  ///     `Result<R, E>`: The result of [next], or the original failure.
  Result<R, E> andThen<R>(Result<R, E> Function(T value) next) =>
      switch (this) {
        Ok<T, E>(:final value) => next(value),
        Err<T, E>(:final error) => Err<R, E>(error),
      };
}

/// Successful result, carrying a value.
///
/// Attributes:
///     value (T): The value the operation produced.
@immutable
final class Ok<T, E> extends Result<T, E> {
  /// Wraps [value] as a success.
  const Ok(this.value);

  /// The successful value.
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, E> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T, E>, value);

  @override
  String toString() => 'Ok($value)';
}

/// Failed result, carrying an error.
///
/// Attributes:
///     error (E): What went wrong.
@immutable
final class Err<T, E> extends Result<T, E> {
  /// Wraps [error] as a failure.
  const Err(this.error);

  /// The failure.
  final E error;

  @override
  bool operator ==(Object other) => other is Err<T, E> && other.error == error;

  @override
  int get hashCode => Object.hash(Err<T, E>, error);

  @override
  String toString() => 'Err($error)';
}
