/// The Student-t distribution function and its inverse, in plain arithmetic.
///
/// The model's predictive distribution is a Student-t on log cycle length. Its
/// five fixed quantiles ship as a table ([ModelPriors.quantiles]). Moving a
/// window forward once a period is late needs quantiles at levels nobody can
/// list in advance, because they depend on how many days have passed, so this
/// file computes them.
///
/// A port of `research/src/cyclecore/models/student_t.py`, step for step, and
/// pinned to it by `artifacts/golden/conditioned_cases_v1.json`. Every
/// operation is one both runtimes have: `+ - * /`, `log`, `exp`, `sin` and
/// `sqrt`. The Python side is held to SciPy by its own tests.
///
/// Includes:
///     - StudentT: The distribution function and its inverse.
library;

import 'dart:math' as math;

import 'package:period_tracker/domain/predict/priors.dart';

/// Student-t: the distribution function, its inverse, and the two special
/// functions they rest on.
abstract final class StudentT {
  static const double _lanczosG = 7;

  /// Lanczos coefficients for g = 7, n = 9: about 15 correct digits for
  /// x >= 0.5.
  static const List<double> _lanczos = <double>[
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];

  static const int _cfMaxTerms = 300;
  static const double _cfEpsilon = 1e-15;
  static const double _cfTiny = 1e-300;
  static const int _bisectionSteps = 200;

  /// The natural log of the gamma function, by the Lanczos approximation.
  ///
  /// Args:
  ///     x (double): A positive number.
  ///
  /// Returns:
  ///     double: ln Γ(x).
  ///
  /// Throws:
  ///     ArgumentError: When [x] is not positive.
  static double logGamma(double x) {
    if (x <= 0) {
      throw ArgumentError.value(x, 'x', 'logGamma needs a positive argument');
    }
    if (x < 0.5) {
      // Reflection, Γ(x) Γ(1 - x) = π / sin(πx), keeps the series where it is
      // accurate.
      return math.log(math.pi / math.sin(math.pi * x)) - logGamma(1.0 - x);
    }
    final shifted = x - 1.0;
    var total = _lanczos[0];
    for (var i = 1; i < _lanczos.length; i++) {
      total += _lanczos[i] / (shifted + i);
    }
    final t = shifted + _lanczosG + 0.5;
    return 0.5 * math.log(2.0 * math.pi) +
        (shifted + 0.5) * math.log(t) -
        t +
        math.log(total);
  }

  /// The continued fraction for the incomplete beta function.
  ///
  /// The modified Lentz method, as in Numerical Recipes' `betacf`.
  static double _betaContinuedFraction(double x, double a, double b) {
    final qab = a + b;
    final qap = a + 1.0;
    final qam = a - 1.0;
    var c = 1.0;
    var d = 1.0 - qab * x / qap;
    if (d.abs() < _cfTiny) d = _cfTiny;
    d = 1.0 / d;
    var h = d;
    for (var term = 1; term <= _cfMaxTerms; term++) {
      final m = term.toDouble();
      final m2 = 2.0 * m;
      var aa = m * (b - m) * x / ((qam + m2) * (a + m2));
      d = 1.0 + aa * d;
      if (d.abs() < _cfTiny) d = _cfTiny;
      c = 1.0 + aa / c;
      if (c.abs() < _cfTiny) c = _cfTiny;
      d = 1.0 / d;
      h *= d * c;
      aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
      d = 1.0 + aa * d;
      if (d.abs() < _cfTiny) d = _cfTiny;
      c = 1.0 + aa / c;
      if (c.abs() < _cfTiny) c = _cfTiny;
      d = 1.0 / d;
      final delta = d * c;
      h *= delta;
      if ((delta - 1.0).abs() < _cfEpsilon) break;
    }
    return h;
  }

  /// The regularized incomplete beta function I_x(a, b).
  ///
  /// Args:
  ///     x (double): Where to evaluate it, from 0 to 1.
  ///     a (double): The first shape parameter, positive.
  ///     b (double): The second shape parameter, positive.
  ///
  /// Returns:
  ///     double: I_x(a, b), from 0 to 1.
  static double incompleteBeta(double x, double a, double b) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    // `log(1 - x)` rather than a log1p, which Dart does not have: the two
    // runtimes have to take the same steps.
    final front = math.exp(
      logGamma(a + b) -
          logGamma(a) -
          logGamma(b) +
          a * math.log(x) +
          b * math.log(1.0 - x),
    );
    if (x < (a + 1.0) / (a + b + 2.0)) {
      return front * _betaContinuedFraction(x, a, b) / a;
    }
    return 1.0 - front * _betaContinuedFraction(1.0 - x, b, a) / b;
  }

  /// The Student-t distribution function.
  ///
  /// Args:
  ///     t (double): The point, in standard units.
  ///     df (double): Degrees of freedom, positive.
  ///
  /// Returns:
  ///     double: P(T <= t) for a standard Student-t with [df] degrees of
  ///     freedom.
  static double cdf(double t, double df) {
    final tail = 0.5 * incompleteBeta(df / (df + t * t), 0.5 * df, 0.5);
    return t > 0 ? 1.0 - tail : tail;
  }

  /// The Student-t quantile at level [p], by bisection on [cdf].
  ///
  /// Bisection rather than Newton's method: slower, but it cannot leave its
  /// bracket, and it takes the same path in both runtimes.
  ///
  /// Args:
  ///     p (double): The level, strictly between 0 and 1.
  ///     df (double): Degrees of freedom, positive.
  ///
  /// Returns:
  ///     double: The t at which `cdf(t, df)` is [p].
  ///
  /// Throws:
  ///     ArgumentError: When [p] is not strictly between 0 and 1.
  static double ppf(double p, double df) {
    if (!(p > 0 && p < 1)) {
      throw ArgumentError.value(
        p,
        'p',
        'ppf needs a level strictly between 0 and 1',
      );
    }
    if (p == 0.5) return 0;
    var lo = -1.0;
    var hi = 1.0;
    while (cdf(lo, df) > p) {
      lo *= 2.0;
    }
    while (cdf(hi, df) < p) {
      hi *= 2.0;
    }
    for (var step = 0; step < _bisectionSteps; step++) {
      final mid = 0.5 * (lo + hi);
      if (mid == lo || mid == hi) break;
      if (cdf(mid, df) < p) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return 0.5 * (lo + hi);
  }
}
