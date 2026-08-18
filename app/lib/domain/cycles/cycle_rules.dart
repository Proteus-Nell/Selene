/// Every tunable threshold used by segmentation, validation and feature
/// derivation, in one place.
///
/// These are deliberately centralised rather than scattered as literals. They
/// are judgement calls about human physiology, not arbitrary constants, so each
/// one carries its reasoning. The Dart side has no config framework by design
/// (`docs/PLAN.md` 5.2), so this class is the single place to change behaviour.
abstract final class CycleRules {
  /// Largest gap, in days, that can appear *inside* one bleeding episode.
  ///
  /// A period commonly has a lighter day in the middle that goes unlogged or is
  /// recorded as spotting. With a value of 1, bleeding on days 1, 2, 4, 5 is one
  /// episode; bleeding on days 1, 2 then 6 is two candidate episodes, which the
  /// [minDaysBetweenEpisodes] rule then merges anyway.
  static const int maxGapWithinEpisodeDays = 1;

  /// Minimum days between two bleeding episode starts for them to be treated as
  /// separate cycles.
  ///
  /// Bleeding that resumes within this window is the same period returning, not
  /// a new cycle. Without this rule a stop-start period would produce a
  /// spurious cycle of a few days, which then has to be rejected downstream as
  /// an outlier. Better not to create it in the first place.
  static const int minDaysBetweenEpisodes = 10;

  /// Shortest cycle length treated as plausible.
  ///
  /// Below this is almost always a mis-logged start or spotting recorded as a
  /// period rather than a real cycle. See `docs/PLAN.md` 5.5.
  static const int minPlausibleCycleDays = 15;

  /// Longest cycle length treated as plausible.
  ///
  /// Above this is far more likely to be a missed log than a real cycle,
  /// although it does genuinely happen in perimenopause and with PCOS, which is
  /// why such a cycle is flagged for confirmation rather than discarded.
  static const int maxPlausibleCycleDays = 90;

  /// Completed cycles needed before outlier detection is attempted.
  ///
  /// With fewer than this, there is no stable notion of "unusual for this
  /// person", and flagging would mostly produce false positives on people whose
  /// cycles are simply variable.
  static const int minCyclesForOutlierDetection = 4;

  /// Modified z-score above which a plausible cycle is flagged as an outlier
  /// against the user's own history.
  ///
  /// 3.5 is the conventional threshold for the median/MAD modified z-score. It
  /// is deliberately conservative: a false flag asks the user a needless
  /// question, which erodes trust faster than a missed flag costs accuracy.
  static const double outlierModifiedZThreshold = 3.5;

  /// Scale factor making the median absolute deviation a consistent estimator
  /// of the standard deviation for normally distributed data.
  ///
  /// 1 / 0.6745. Used by the modified z-score.
  static const double madToSigma = 1.4826;

  /// Days without any log, with a cycle in progress, after which the app should
  /// stop extrapolating and say it has lost track.
  ///
  /// Silently predicting from stale data is worse than admitting the gap: it
  /// produces a confident wrong answer. See `docs/PLAN.md` 5.5.
  static const int lostTrackAfterDays = 60;

  /// Upper bound on median absolute deviation, in days, for cycles to count as
  /// regular.
  static const double regularMadDays = 2;

  /// Upper bound on median absolute deviation, in days, for cycles to count as
  /// variable rather than irregular.
  static const double variableMadDays = 5;
}
