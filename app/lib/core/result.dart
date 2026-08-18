import 'package:meta/meta.dart';

/// The outcome of an operation that can fail: either an [Ok] carrying a value
/// or an [Err] carrying an error.
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

  /// The value if this is an [Ok], otherwise [fallback].
  T valueOr(T fallback) => switch (this) {
    Ok<T, E>(:final value) => value,
    Err<T, E>() => fallback,
  };

  /// Collapses both cases into a single value.
  R fold<R>(R Function(T value) onOk, R Function(E error) onErr) =>
      switch (this) {
        Ok<T, E>(:final value) => onOk(value),
        Err<T, E>(:final error) => onErr(error),
      };

  /// Applies [transform] to the value, leaving an [Err] untouched.
  Result<R, E> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T, E>(:final value) => Ok<R, E>(transform(value)),
    Err<T, E>(:final error) => Err<R, E>(error),
  };

  /// Applies [transform] to the error, leaving an [Ok] untouched.
  Result<T, F> mapError<F>(F Function(E error) transform) => switch (this) {
    Ok<T, E>(:final value) => Ok<T, F>(value),
    Err<T, E>(:final error) => Err<T, F>(transform(error)),
  };

  /// Chains another fallible operation onto a successful result.
  Result<R, E> andThen<R>(Result<R, E> Function(T value) next) =>
      switch (this) {
        Ok<T, E>(:final value) => next(value),
        Err<T, E>(:final error) => Err<R, E>(error),
      };
}

/// A successful [Result] carrying a [value].
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

/// A failed [Result] carrying an [error].
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
