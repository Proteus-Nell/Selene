/// Interaction checker.
///
/// Compares two or more medicines by what their US labels say, a pair at a
/// time (ADR-0014): an ingredient both contain, an FDA drug class both are in,
/// and each place one label names the other, quoted as the label prints it.
/// It never concludes that a combination is safe, and says so wherever it
/// finds nothing.
///
/// Includes:
///     - InteractionCheckerScreen: The list, and what its labels say.
///     - InteractionPairCard: One pair, and what connects it.
///     - interactionReasons: What connects a pair, a sentence each.
///     - searchPairOnline: The browser hand-off for a pair.
///     - _Mention: One quoted passage, with the name set apart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/reference/interactions.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/features/common/snack.dart';
import 'package:period_tracker/features/lookup/browser_handoff.dart';
import 'package:period_tracker/features/lookup/medicine_picker.dart';
import 'package:period_tracker/features/lookup/medicine_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Checker screen: a list of medicines, and what their labels say about each
/// other.
///
/// The list lives on this screen only and is gone when the reader leaves it.
/// Medicines kept between visits are recorded under Conditions and
/// medication, which says so, rather than here.
///
/// Attributes:
///     initial (`List<MedicineEntry>`): The medicines the list starts with.
class InteractionCheckerScreen extends ConsumerStatefulWidget {
  /// Creates the checker.
  ///
  /// Args:
  ///     initial (`List<MedicineEntry>`): The medicines to start with: the
  ///         one whose page the checker was opened from, if any. Defaults to
  ///         none.
  const InteractionCheckerScreen({
    this.initial = const <MedicineEntry>[],
    super.key,
  });

  /// The medicines the list starts with.
  final List<MedicineEntry> initial;

  /// The most medicines compared at once: forty-five pairs.
  static const int limit = 10;

  @override
  ConsumerState<InteractionCheckerScreen> createState() =>
      _InteractionCheckerScreenState();
}

/// State for [InteractionCheckerScreen]: the list, and the comparison of it.
///
/// Attributes:
///     _medicines (`List<MedicineEntry>`): The list, in the order added.
///     _pairs (`Future<List<InteractionPair>>?`): The comparison of it, or
///         null while it holds fewer than two.
class _InteractionCheckerScreenState
    extends ConsumerState<InteractionCheckerScreen> {
  /// The list, in the order added.
  late final List<MedicineEntry> _medicines = <MedicineEntry>[
    ...widget.initial,
  ];

  /// The comparison of the list, or null while it holds fewer than two.
  Future<List<InteractionPair>>? _pairs;

  @override
  void initState() {
    super.initState();
    _compare();
  }

  /// Start comparing the list as it now stands.
  void _compare() {
    _pairs = _medicines.length < 2
        ? null
        : ref
              .read(medicineBundleProvider)
              .interactions(List<MedicineEntry>.of(_medicines));
  }

  /// Pick a medicine and add it, unless the list is full or holds it already.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the medicine is added, or once the
  ///     reason it was not has been shown.
  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    if (_medicines.length >= InteractionCheckerScreen.limit) {
      showAppSnackBar(
        context,
        l10n.checkerFull(InteractionCheckerScreen.limit),
      );
      return;
    }
    final picked = await pickMedicine(context);
    if (picked == null || !mounted) return;
    if (_medicines.contains(picked)) {
      showAppSnackBar(context, l10n.checkerAlreadyAdded(picked.name));
      return;
    }
    setState(() {
      _medicines.add(picked);
      _compare();
    });
  }

  /// Take [medicine] off the list.
  void _remove(MedicineEntry medicine) => setState(() {
    _medicines.remove(medicine);
    _compare();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    // Watched so the bundle, and the chunk it last opened, outlive each
    // comparison: the next one usually reads the same labels again.
    ref.watch(medicineBundleProvider);
    final pairs = _pairs;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkerTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Text(l10n.checkerIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            // The theme gives cards no margin; in a list, cards with no gap
            // between them read as one block.
            for (final medicine in _medicines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    title: Text(medicine.name),
                    subtitle: Text(medicineKind(l10n, medicine)),
                    trailing: IconButton(
                      onPressed: () => _remove(medicine),
                      icon: const Icon(Icons.close),
                      tooltip: l10n.checkerRemove(medicine.name),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: Text(l10n.checkerAdd),
              ),
            ),
            const SizedBox(height: 16),
            if (pairs == null)
              Text(l10n.checkerNeedTwo, style: theme.textTheme.bodyMedium)
            else
              FutureBuilder<List<InteractionPair>>(
                future: pairs,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      l10n.checkerFailed,
                      style: theme.textTheme.bodyMedium,
                    );
                  }
                  final found = snapshot.data;
                  if (found == null) {
                    return LinearProgressIndicator(
                      semanticsLabel: l10n.checkerLoading,
                    );
                  }
                  final unconnected = found.where((pair) => !pair.connected);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // What the labels connect first, so the pairs that need
                      // reading are not below a list of pairs that do not.
                      for (final pair in <InteractionPair>[
                        ...found.where((pair) => pair.connected),
                        ...unconnected,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InteractionPairCard(pair: pair),
                        ),
                      if (unconnected.isNotEmpty)
                        Text(
                          l10n.checkerNothingFoundNote,
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 24),
            Text(l10n.checkerAskPharmacist, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(l10n.lookupMedicinesUsOnly, style: small),
            const SizedBox(height: 8),
            Text(medicinesDisclaimer, style: small),
          ],
        ),
      ),
    );
  }
}

/// One pair, and what connects it: shared ingredients and classes, and each
/// passage where one label names the other.
///
/// Attributes:
///     pair (InteractionPair): The pair.
class InteractionPairCard extends StatelessWidget {
  /// Creates the card.
  ///
  /// Args:
  ///     pair (InteractionPair): The pair.
  const InteractionPairCard({required this.pair, super.key});

  /// The pair.
  final InteractionPair pair;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.checkerPairTitle(pair.first.name, pair.second.name),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (!pair.connected) Text(l10n.checkerNothingFoundPair),
            for (final reason in interactionReasons(l10n, pair, quotes: true))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(reason),
              ),
            for (final mention in pair.firstMentions)
              _Mention(mention: mention, own: pair.first, other: pair.second),
            for (final mention in pair.secondMentions)
              _Mention(mention: mention, own: pair.second, other: pair.first),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => searchPairOnline(context, pair),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.checkerSearchOnline),
            ),
          ],
        ),
      ),
    );
  }
}

/// Say what connects a pair, a sentence each.
///
/// Args:
///     l10n (AppLocalizations): The translations.
///     pair (InteractionPair): The pair.
///     quotes (bool): Whether the passages are shown with the sentences, as
///         the checker shows them. When they are, only what is shared is said
///         here, and each mention is said above its passage instead.
///
/// Returns:
///     `List<String>`: The ingredients both contain, the classes both are in,
///     and, unless [quotes], each name one label gives the other. Empty for a
///     pair the labels do not connect.
List<String> interactionReasons(
  AppLocalizations l10n,
  InteractionPair pair, {
  bool quotes = false,
}) => <String>[
  if (pair.sharedSubstances.isNotEmpty)
    l10n.checkerSharedSubstance(pair.sharedSubstances.join(', ')),
  if (pair.sharedClasses.isNotEmpty)
    l10n.checkerSharedClass(
      pair.sharedClasses.length,
      pair.sharedClasses.join(', '),
    ),
  if (!quotes) ...<String>[
    for (final mention in pair.firstMentions)
      _mentionSentence(
        l10n,
        mention,
        own: pair.first,
        other: pair.second,
        short: true,
      ),
    for (final mention in pair.secondMentions)
      _mentionSentence(
        l10n,
        mention,
        own: pair.second,
        other: pair.first,
        short: true,
      ),
  ],
];

/// The sentence that introduces a mention: which label, which words, and,
/// above a quoted passage, where in the label.
///
/// [short] leaves out where, for a reason with no passage under it.
String _mentionSentence(
  AppLocalizations l10n,
  LabelMention mention, {
  required MedicineEntry own,
  required MedicineEntry other,
  bool short = false,
}) {
  // The words as the label prints them, on one line: a match can run over a
  // line break, "Naproxen\nsodium".
  final words = mention.passage
      .substring(mention.start, mention.end)
      .replaceAll(RegExp(r'\s+'), ' ');
  if (short) {
    return mention.isClass
        ? l10n.checkerMentionsClassShort(own.name, words, other.name)
        : l10n.checkerMentionsNameShort(own.name, words);
  }
  final section = medicineSectionHeading(l10n, mention.section);
  return mention.isClass
      ? l10n.checkerMentionsClass(own.name, words, other.name, section)
      : l10n.checkerMentionsName(own.name, words, section);
}

/// Hand a pair off to a browser, after confirming.
///
/// The same hand-off as Look something up's: the browser makes the request,
/// and the search words are named back before it does (ADR-0009).
///
/// Args:
///     context (BuildContext): Where the confirmation is shown.
///     pair (InteractionPair): The pair to search for.
///
/// Returns:
///     `Future<void>`: Completes once the browser has opened, the reader has
///     declined, or the failure has been reported.
Future<void> searchPairOnline(BuildContext context, InteractionPair pair) =>
    BrowserHandoff.offer(
      context,
      term: AppLocalizations.of(context).checkerSearchTerm(
        pair.first.name.toLowerCase(),
        pair.second.name.toLowerCase(),
      ),
    );

/// One passage where a label names the other medicine, with the name set
/// apart from the words around it.
///
/// Attributes:
///     mention (LabelMention): The passage, and where the name is in it.
///     own (MedicineEntry): Whose label it is from.
///     other (MedicineEntry): Who it names.
class _Mention extends StatelessWidget {
  /// Creates the passage.
  const _Mention({
    required this.mention,
    required this.own,
    required this.other,
  });

  /// The passage, and where the name is in it.
  final LabelMention mention;

  /// Whose label it is from.
  final MedicineEntry own;

  /// Who it names.
  final MedicineEntry other;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final passage = mention.passage;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_mentionSentence(l10n, mention, own: own, other: other)),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 3,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    TextSpan(text: passage.substring(0, mention.start)),
                    TextSpan(
                      text: passage.substring(mention.start, mention.end),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: passage.substring(mention.end)),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
