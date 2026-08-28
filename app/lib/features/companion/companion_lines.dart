import 'package:period_tracker/l10n/app_localizations.dart';

/// Everything the companion is capable of saying (AND-37).
///
/// **This enum is the whole vocabulary.** There is no network permission and no
/// model on the device: nothing is generated, nothing is fetched, and no
/// sentence is ever assembled out of parts. The companion looks at what the
/// user logged, walks the ordered rule list in
/// `companion_rules.dart`, and picks one of these. Adding a
/// thirteenth thing it can say means adding a member here, which
/// `companion_lines_test.dart` fails on until the new sentence is written out
/// in the test's own literal list — so every word this thing can utter is
/// readable in one place, and a line cannot arrive without somebody reading it.
///
/// The voice is `docs/PLAN.md` 6.3 and is enforced by
/// `companion_copy_test.dart` rather than reviewed: no euphemism, no forced
/// positivity, no praise for logging, no diagnosis, no second person at all,
/// and no digit anywhere. The last two are absolutes for the reason AND-35 and
/// AND-36 give — a judgement call about whether *this* "you" is a claim about
/// the reader's body is exactly what a hurried edit gets wrong, and a number
/// here would be a streak, a score or a threshold.
///
/// [carriesHealthClaim] splits the set in two, and the split is the point.
/// Lines that make a claim about bodies are cited in
/// `docs/COMPANION_SOURCES.md` and `companion_sources_test.dart` fails if one
/// is not. Lines that make no claim — an offer to open the log, a statement
/// about what the app itself is doing — are recorded there as claim-free, so
/// that the absence of a citation is a decision rather than an oversight.
enum CompanionLine {
  /// The logs, prediction or conditions have not loaded yet.
  stillReading(carriesHealthClaim: false),

  /// A recorded pregnancy is suppressing the prediction.
  predictionPaused(carriesHealthClaim: false),

  /// Heavy flow logged on several recent days.
  heavyBleeding(carriesHealthClaim: true),

  /// Cramps recorded for today.
  cramps(carriesHealthClaim: true),

  /// Disturbed sleep recorded for today.
  sleep(carriesHealthClaim: true),

  /// Low energy recorded for today.
  lowEnergy(carriesHealthClaim: true),

  /// Today falls inside a logged bleeding episode.
  periodToday(carriesHealthClaim: true),

  /// The predicted window has passed with no period logged.
  overdue(carriesHealthClaim: false),

  /// Nothing logged for several days.
  nothingLoggedRecently(carriesHealthClaim: false),

  /// Nothing logged, ever.
  noLogsYet(carriesHealthClaim: false),

  /// Logs exist but no prediction can be made from them yet.
  noPredictionYet(carriesHealthClaim: false),

  /// Today already has an entry.
  todayLogged(carriesHealthClaim: false),

  /// Nothing above applied.
  nothingToPointAt(carriesHealthClaim: false);

  const CompanionLine({required this.carriesHealthClaim});

  /// Whether this line says something about bodies that needs a source.
  ///
  /// True means there is a row for it in `docs/COMPANION_SOURCES.md`. False
  /// means the line is about the user's own data or about the app's own
  /// behaviour, and the sources file says so explicitly rather than leaving it
  /// out.
  final bool carriesHealthClaim;
}

/// Resolves a [CompanionLine] to the sentence it stands for.
extension CompanionLineText on CompanionLine {
  /// The one sentence this line is, in [l10n].
  ///
  /// An exhaustive switch rather than a name-to-key lookup: a member added to
  /// the enum stops this compiling, which is a better place to find out than a
  /// missing string at runtime.
  String text(AppLocalizations l10n) => switch (this) {
    CompanionLine.stillReading => l10n.companionLineStillReading,
    CompanionLine.predictionPaused => l10n.companionLinePredictionPaused,
    CompanionLine.heavyBleeding => l10n.companionLineHeavyBleeding,
    CompanionLine.cramps => l10n.companionLineCramps,
    CompanionLine.sleep => l10n.companionLineSleep,
    CompanionLine.lowEnergy => l10n.companionLineLowEnergy,
    CompanionLine.periodToday => l10n.companionLinePeriodToday,
    CompanionLine.overdue => l10n.companionLineOverdue,
    CompanionLine.nothingLoggedRecently =>
      l10n.companionLineNothingLoggedRecently,
    CompanionLine.noLogsYet => l10n.companionLineNoLogsYet,
    CompanionLine.noPredictionYet => l10n.companionLineNoPredictionYet,
    CompanionLine.todayLogged => l10n.companionLineTodayLogged,
    CompanionLine.nothingToPointAt => l10n.companionLineNothingToPointAt,
  };

  /// The ARB key this line reads, for the guards that scan the ARB by name.
  String get arbKey =>
      'companionLine${name[0].toUpperCase()}${name.substring(1)}';
}
