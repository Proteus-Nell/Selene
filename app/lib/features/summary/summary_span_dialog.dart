/// The question asked before a summary is made: how far back.
///
/// Also where the summary says what it holds, before anything is written,
/// including the one thing it never holds: intercourse (ADR-0024).
///
/// Includes:
///     - showSummarySpanDialog: Asks, and returns the span chosen.
///     - summarySpanLabel: A span, in words.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/data/summary/cycle_summary.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Ask how far back a summary should reach.
///
/// Args:
///     context (BuildContext): What to show the question over.
///
/// Returns:
///     `Future<SummarySpan?>`: The span chosen, or null when the reader went
///     back without choosing.
Future<SummarySpan?> showSummarySpanDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<SummarySpan>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(l10n.summarySpanTitle),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(l10n.summarySpanBody),
        ),
        for (final span in SummarySpan.values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(span),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(summarySpanLabel(l10n, span)),
          ),
      ],
    ),
  );
}

/// [span], as the question offers it.
String summarySpanLabel(AppLocalizations l10n, SummarySpan span) =>
    switch (span) {
      SummarySpan.threeMonths => l10n.summarySpanThreeMonths,
      SummarySpan.sixMonths => l10n.summarySpanSixMonths,
      SummarySpan.twelveMonths => l10n.summarySpanYear,
      SummarySpan.everything => l10n.summarySpanEverything,
    };
