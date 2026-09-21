/// Curated hygiene reference entries.
///
/// The menstrual hygiene entries the lookup screen shows, hand-written rather
/// than fetched: tampons, cups and pads are FDA devices rather than drugs, so
/// the openFDA generator cannot reach them. The text itself lives in the ARB
/// file, keyed by each entry's key.
///
/// Includes:
///     - HygieneUrgency: How urgently an entry should be read.
///     - HygieneEntry: One entry and the words that find it.
///     - bundledHygieneEntries: The entries, in screen order.
library;

import 'package:meta/meta.dart';

/// Hygiene urgency: how urgently an entry's content should be read.
enum HygieneUrgency {
  /// Ordinary reference reading.
  reference,

  /// Symptoms that need medical attention now.
  ///
  /// Exactly one entry carries this, and it is rendered differently from
  /// everything else on the screen. A page where the urgent thing looks like
  /// the rest of the page is a page where the urgent thing is not found.
  urgent,
}

/// Hygiene entry: one curated entry about a menstrual hygiene product.
///
/// **Hand-written, not fetched.** Tampons, cups and pads are FDA *devices*
/// rather than drugs, so they are not in `/drug/label` and the openFDA
/// generator cannot reach them (ADR-0009). The app labels these as curated
/// rather than as a regulator's own text, because the distinction is real: the
/// medicines entries are a dated snapshot of someone else's words, and these
/// are ours.
///
/// Every claim here is recorded with its source in `docs/HYGIENE_SOURCES.md`,
/// and `hygiene_copy_test.dart` fails the build if this file makes a claim
/// that file does not cover.
///
/// Attributes:
///     key (String): Stable identifier, and the l10n key stem. Never shown.
///     urgency (HygieneUrgency): How the entry should be rendered.
///     searchTerms (`List<String>`): Extra words that match it in the lookup.
///         Defaults to empty.
@immutable
final class HygieneEntry {
  /// Creates an entry.
  ///
  /// Args:
  ///     key (String): Stable identifier, and the l10n key stem.
  ///     urgency (HygieneUrgency): How the entry should be rendered.
  ///     searchTerms (`List<String>`, optional): Extra matching words.
  ///         Defaults to empty.
  const HygieneEntry({
    required this.key,
    required this.urgency,
    this.searchTerms = const <String>[],
  });

  /// Stable identifier, and the l10n key stem. Never shown.
  final String key;

  /// How the entry should be rendered.
  final HygieneUrgency urgency;

  /// Extra words that should match this entry in the lookup.
  ///
  /// Someone looking for "TSS" will not type "toxic shock syndrome", and
  /// someone worried about a fever will type "fever". A search that only
  /// matches the title is a search that fails the person in the most hurry.
  final List<String> searchTerms;

  @override
  bool operator ==(Object other) => other is HygieneEntry && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'HygieneEntry($key)';
}

/// The curated hygiene entries, in the order the screen shows them.
///
/// TSS is first, deliberately. It is the only thing on this page anyone might
/// need within the hour.
const List<HygieneEntry> bundledHygieneEntries = <HygieneEntry>[
  HygieneEntry(
    key: 'tss',
    urgency: HygieneUrgency.urgent,
    searchTerms: <String>[
      'tss',
      'toxic shock',
      'toxic shock syndrome',
      'fever',
      'rash',
      'sick',
      'ill',
    ],
  ),
  HygieneEntry(
    key: 'tampons',
    urgency: HygieneUrgency.reference,
    searchTerms: <String>['tampon', 'tampons', 'absorbency'],
  ),
  HygieneEntry(
    key: 'cups',
    urgency: HygieneUrgency.reference,
    searchTerms: <String>['cup', 'cups', 'menstrual cup', 'moon cup'],
  ),
  HygieneEntry(
    key: 'external',
    urgency: HygieneUrgency.reference,
    searchTerms: <String>[
      'pad',
      'pads',
      'towel',
      'towels',
      'period underwear',
      'period pants',
    ],
  ),
];
