/// Interaction checker.
///
/// Compares two or more medicines by what their US labels say, a pair at a
/// time (ADR-0014): an ingredient both contain, an FDA drug class or a group
/// both are in (ADR-0021), and each place one label names the other, quoted
/// as the label prints it. A herbal supplement is compared with each medicine
/// by NCCIH's fact sheet on it and the medicine's label (ADR-0023). It never
/// concludes that a combination is safe, and says so wherever it finds
/// nothing.
///
/// Includes:
///     - InteractionCheckerScreen: The list, and what its labels say.
///     - InteractionPairCard: One pair, and what connects it.
///     - SupplementPairCard: A herb and a medicine, and what connects them.
///     - ConditionPairScreen: A recorded kind of contraception and a
///       medicine, and what the medicine's label says.
///     - interactionReasons: What connects a pair, a sentence each.
///     - conditionReasons: What connects a kind and a medicine, likewise.
///     - supplementReasons: What a herb and a medicine share, likewise.
///     - conditionKindName: A kind of contraception, in a sentence.
///     - searchPairOnline: The browser hand-off for a pair.
///     - searchConditionOnline: The same, for a kind and a medicine.
///     - searchSupplementOnline: The same, for a herb and a medicine.
///     - _Mention: One quoted passage, with the name set apart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/reference/interactions.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicine_groups.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/data/reference/supplement.dart';
import 'package:period_tracker/data/reference/supplement_bundle.dart';
import 'package:period_tracker/data/reference/supplements_bundled.dart';
import 'package:period_tracker/domain/models/condition.dart';
import 'package:period_tracker/features/common/snack.dart';
import 'package:period_tracker/features/lookup/browser_handoff.dart';
import 'package:period_tracker/features/lookup/medicine_picker.dart';
import 'package:period_tracker/features/lookup/medicine_screen.dart';
import 'package:period_tracker/features/lookup/supplement_picker.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Checker screen: a list of medicines and herbs, and what their labels and
/// fact sheets say about each other.
///
/// The list lives on this screen only and is gone when the reader leaves it.
/// Medicines kept between visits are recorded under Conditions and
/// medication, which says so, rather than here.
///
/// Attributes:
///     initial (`List<MedicineEntry>`): The medicines the list starts with.
///     initialSupplements (`List<Supplement>`): The herbs it starts with.
class InteractionCheckerScreen extends ConsumerStatefulWidget {
  /// Creates the checker.
  ///
  /// Args:
  ///     initial (`List<MedicineEntry>`): The medicines to start with: the
  ///         one whose page the checker was opened from, if any. Defaults to
  ///         none.
  ///     initialSupplements (`List<Supplement>`): The herbs to start with,
  ///         likewise. Defaults to none.
  const InteractionCheckerScreen({
    this.initial = const <MedicineEntry>[],
    this.initialSupplements = const <Supplement>[],
    super.key,
  });

  /// The medicines the list starts with.
  final List<MedicineEntry> initial;

  /// The herbs the list starts with.
  final List<Supplement> initialSupplements;

  /// The most medicines and herbs compared at once: forty-five pairs at
  /// most.
  static const int limit = 10;

  @override
  ConsumerState<InteractionCheckerScreen> createState() =>
      _InteractionCheckerScreenState();
}

/// What a comparison found: the medicine pairs, and each herb with each
/// medicine.
typedef _Comparison = (List<InteractionPair>, List<SupplementPair>);

/// State for [InteractionCheckerScreen]: the list, and the comparison of it.
///
/// Attributes:
///     _medicines (`List<MedicineEntry>`): The medicines, in the order added.
///     _supplements (`List<Supplement>`): The herbs, in the order added.
///     _comparison (`Future<_Comparison>?`): The comparison of the list, or
///         null while it holds nothing to compare.
class _InteractionCheckerScreenState
    extends ConsumerState<InteractionCheckerScreen> {
  /// The medicines, in the order added.
  late final List<MedicineEntry> _medicines = <MedicineEntry>[
    ...widget.initial,
  ];

  /// The herbs, in the order added.
  late final List<Supplement> _supplements = <Supplement>[
    ...widget.initialSupplements,
  ];

  /// The comparison of the list, or null while it holds neither two
  /// medicines nor a herb and a medicine.
  Future<_Comparison>? _comparison;

  @override
  void initState() {
    super.initState();
    _compare();
  }

  /// Start comparing the list as it now stands.
  void _compare() {
    final bundle = ref.read(medicineBundleProvider);
    final medicines = List<MedicineEntry>.of(_medicines);
    final herbs = List<Supplement>.of(_supplements);
    final pairs = medicines.length < 2 ? null : bundle.interactions(medicines);
    final herbPairs = herbs.isEmpty || medicines.isEmpty
        ? null
        : bundle.supplements(herbs, medicines);
    _comparison = pairs == null && herbPairs == null
        ? null
        : _both(pairs, herbPairs);
  }

  /// Wait for both comparisons, either of which may not have been started.
  ///
  /// Through [Future.wait], so that a failure in one is reported, and one in
  /// the other is not left unhandled.
  static Future<_Comparison> _both(
    Future<List<InteractionPair>>? pairs,
    Future<List<SupplementPair>>? herbPairs,
  ) async {
    final found = await Future.wait<Object>(<Future<Object>>[
      pairs ?? Future<List<InteractionPair>>.value(const <InteractionPair>[]),
      herbPairs ?? Future<List<SupplementPair>>.value(const <SupplementPair>[]),
    ]);
    return (
      found[0] as List<InteractionPair>,
      found[1] as List<SupplementPair>,
    );
  }

  /// Whether the list holds as many as it may.
  bool get _full =>
      _medicines.length + _supplements.length >= InteractionCheckerScreen.limit;

  /// Pick a medicine and add it, unless the list is full or holds it already.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the medicine is added, or once the
  ///     reason it was not has been shown.
  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    if (_full) {
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

  /// Pick a herb and add it, as [_add] adds a medicine.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the herb is added, or once the reason
  ///     it was not has been shown.
  Future<void> _addSupplement() async {
    final l10n = AppLocalizations.of(context);
    if (_full) {
      showAppSnackBar(
        context,
        l10n.checkerFull(InteractionCheckerScreen.limit),
      );
      return;
    }
    final picked = await pickSupplement(context);
    if (picked == null || !mounted) return;
    if (_supplements.contains(picked)) {
      showAppSnackBar(context, l10n.checkerAlreadyAdded(picked.name));
      return;
    }
    setState(() {
      _supplements.add(picked);
      _compare();
    });
  }

  /// Take [medicine] off the list.
  void _remove(MedicineEntry medicine) => setState(() {
    _medicines.remove(medicine);
    _compare();
  });

  /// Take [supplement] off the list.
  void _removeSupplement(Supplement supplement) => setState(() {
    _supplements.remove(supplement);
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
    // Only with a herb on the list, whose page says whose words it quotes.
    final herbs = _supplements.isEmpty
        ? null
        : ref.watch(supplementsProvider).valueOrNull;
    final comparison = _comparison;

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
            for (final supplement in _supplements)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    title: Text(supplement.name),
                    subtitle: Text(l10n.checkerSupplementKind),
                    trailing: IconButton(
                      onPressed: () => _removeSupplement(supplement),
                      icon: const Icon(Icons.close),
                      tooltip: l10n.checkerRemove(supplement.name),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.checkerAdd),
                  ),
                  if (supplementsCount > 0)
                    OutlinedButton.icon(
                      onPressed: _addSupplement,
                      icon: const Icon(Icons.eco_outlined),
                      label: Text(l10n.checkerAddSupplement),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (comparison == null)
              Text(
                _supplements.isNotEmpty && _medicines.isEmpty
                    ? l10n.checkerNeedMedicine
                    : l10n.checkerNeedTwo,
                style: theme.textTheme.bodyMedium,
              )
            else
              FutureBuilder<_Comparison>(
                future: comparison,
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
                  final (pairs, herbPairs) = found;
                  final unconnected = pairs.where((pair) => !pair.connected);
                  final unconnectedHerbs = herbPairs.where(
                    (pair) => !pair.connected,
                  );
                  Widget spaced(Widget card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // What the labels connect first, so the pairs that need
                      // reading are not below a list of pairs that do not.
                      for (final pair in pairs.where((pair) => pair.connected))
                        spaced(InteractionPairCard(pair: pair)),
                      for (final pair in herbPairs.where(
                        (pair) => pair.connected,
                      ))
                        spaced(SupplementPairCard(pair: pair)),
                      for (final pair in unconnected)
                        spaced(InteractionPairCard(pair: pair)),
                      for (final pair in unconnectedHerbs)
                        spaced(SupplementPairCard(pair: pair)),
                      if (unconnected.isNotEmpty)
                        Text(
                          l10n.checkerNothingFoundNote,
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (unconnectedHerbs.isNotEmpty) ...<Widget>[
                        if (unconnected.isNotEmpty) const SizedBox(height: 8),
                        Text(
                          l10n.checkerNothingFoundSheetNote,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (_supplements.length > 1) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          l10n.checkerHerbsNotCompared,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
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
            if (herbs != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(herbs.disclaimer, style: small),
            ],
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
              _Mention(
                mention: mention,
                medicine: pair.first.name,
                other: pair.second.name,
              ),
            for (final mention in pair.secondMentions)
              _Mention(
                mention: mention,
                medicine: pair.second.name,
                other: pair.first.name,
              ),
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

/// A herb and a medicine, and what connects them: the herb among the
/// medicine's own ingredients, and each passage where the label names the
/// herb or the herb's fact sheet names the medicine.
///
/// Attributes:
///     pair (SupplementPair): The herb and the medicine.
class SupplementPairCard extends StatelessWidget {
  /// Creates the card.
  ///
  /// Args:
  ///     pair (SupplementPair): The herb and the medicine.
  const SupplementPairCard({required this.pair, super.key});

  /// The herb and the medicine.
  final SupplementPair pair;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final herb = pair.supplement.name;
    final medicine = pair.medicine.name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.checkerPairTitle(herb, medicine),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (!pair.connected) Text(l10n.checkerNothingFoundSupplementPair),
            for (final reason in supplementReasons(l10n, pair))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(reason),
              ),
            for (final mention in pair.labelMentions)
              _Mention(mention: mention, medicine: medicine, other: herb),
            for (final mention in pair.sheetMentions)
              _Mention(
                mention: mention,
                medicine: herb,
                other: medicine,
                sheet: true,
              ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => searchSupplementOnline(context, pair),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.checkerSearchOnline),
            ),
          ],
        ),
      ),
    );
  }
}

/// Say what a herb and a medicine share, a sentence each.
///
/// Each passage is said above itself, as the checker shows them, so this is
/// only what is not a passage.
///
/// Args:
///     l10n (AppLocalizations): The translations.
///     pair (SupplementPair): The herb and the medicine.
///
/// Returns:
///     `List<String>`: The herb among the medicine's own ingredients, if it
///     is one. Empty otherwise.
List<String> supplementReasons(AppLocalizations l10n, SupplementPair pair) =>
    <String>[
      if (pair.ingredients.isNotEmpty)
        l10n.checkerSupplementIngredient(
          pair.medicine.name,
          pair.supplement.name,
          pair.ingredients.join(', '),
        ),
    ];

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
///     `List<String>`: The ingredients both contain, the classes and groups
///     both are in, and, unless [quotes], each name one label gives the
///     other. Empty for a pair the labels do not connect.
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
  if (pair.sharedGroups.isNotEmpty)
    l10n.checkerSharedGroup(_groupNames(pair.sharedGroups)),
  if (!quotes) ...<String>[
    for (final mention in pair.firstMentions)
      _mentionSentence(
        l10n,
        mention,
        medicine: pair.first.name,
        other: pair.second.name,
        short: true,
      ),
    for (final mention in pair.secondMentions)
      _mentionSentence(
        l10n,
        mention,
        medicine: pair.second.name,
        other: pair.first.name,
        short: true,
      ),
  ],
];

/// Say what connects a recorded kind of contraception and a medicine, a
/// sentence each.
///
/// Args:
///     l10n (AppLocalizations): The translations.
///     pair (ConditionPair): The kind and the medicine.
///     quotes (bool): Whether the passages are shown with the sentences, as
///         for [interactionReasons].
///
/// Returns:
///     `List<String>`: What both contain and are in, and, unless [quotes],
///     each way the medicine's label names the kind. Empty for a pair the
///     label does not connect.
List<String> conditionReasons(
  AppLocalizations l10n,
  ConditionPair pair, {
  bool quotes = false,
}) => <String>[
  if (pair.sharedSubstances.isNotEmpty)
    l10n.checkerSharedSubstance(pair.sharedSubstances.join(', ')),
  if (pair.sharedGroups.isNotEmpty)
    l10n.checkerSharedGroup(_groupNames(pair.sharedGroups)),
  if (!quotes)
    for (final mention in pair.mentions)
      _mentionSentence(
        l10n,
        mention,
        medicine: pair.medicine.name,
        other: conditionKindName(l10n, pair.condition.condition),
        kind: true,
        short: true,
      ),
];

/// Name a recorded kind of contraception in a sentence, in the plural:
/// "combined pills", as in "a group that includes combined pills".
///
/// Args:
///     l10n (AppLocalizations): The translations.
///     condition (Condition): The kind.
///
/// Returns:
///     String: Its name. A condition that is not a kind of contraception has
///     none, and is named as the conditions list names it.
String conditionKindName(AppLocalizations l10n, Condition condition) =>
    switch (condition) {
      Condition.hormonalContraceptionCombined => l10n.conditionKindCombined,
      Condition.hormonalContraceptionProgestogen =>
        l10n.conditionKindProgestogen,
      Condition.hormonalIud => l10n.conditionKindIud,
      Condition.contraceptiveImplant => l10n.conditionKindImplant,
      _ => condition.name,
    };

/// [groups] by name, one after another: "NSAIDs, triptans".
String _groupNames(List<MedicineGroup> groups) =>
    groups.map((group) => group.name).join(', ');

/// The sentence that introduces a mention: which label, which words, and,
/// above a quoted passage, where in the label.
///
/// [short] leaves out where, for a reason with no passage under it. [kind]
/// says [other] is a recorded kind of contraception, named in the plural: an
/// ingredient is then one every product of it contains. [sheet] says the
/// passage is from NCCIH's fact sheet on [medicine], a herb, rather than
/// from a label, and is never short: it is always shown with its passage.
String _mentionSentence(
  AppLocalizations l10n,
  LabelMention mention, {
  required String medicine,
  required String other,
  bool kind = false,
  bool short = false,
  bool sheet = false,
}) {
  // The words as the label prints them, on one line: a match can run over a
  // line break, "Naproxen\nsodium".
  final words = mention.passage
      .substring(mention.start, mention.end)
      .replaceAll(RegExp(r'\s+'), ' ');
  if (sheet) {
    // A fact sheet's section is named by its own heading.
    final section = mention.section;
    if (mention.group != null) {
      return l10n.checkerSheetMentionsGroup(medicine, words, other, section);
    }
    if (mention.isClass) {
      return l10n.checkerSheetMentionsClass(medicine, words, other, section);
    }
    return l10n.checkerSheetMentionsName(medicine, words, section);
  }
  if (short) {
    if (mention.group != null) {
      return l10n.checkerMentionsGroupShort(medicine, words, other);
    }
    if (mention.isClass) {
      return l10n.checkerMentionsClassShort(medicine, words, other);
    }
    return kind
        ? l10n.checkerMentionsKindName(medicine, words, other)
        : l10n.checkerMentionsNameShort(medicine, words);
  }
  final section = medicineSectionHeading(l10n, mention.section);
  if (mention.group != null) {
    return l10n.checkerMentionsGroup(medicine, words, other, section);
  }
  if (mention.isClass) {
    return l10n.checkerMentionsClass(medicine, words, other, section);
  }
  return kind
      ? l10n.checkerMentionsKindNameFrom(medicine, words, other, section)
      : l10n.checkerMentionsName(medicine, words, section);
}

/// Say where a group's list of medicines comes from: each source by its
/// title and who published it.
String _groupSources(AppLocalizations l10n, MedicineGroup group) =>
    l10n.checkerGroupSources(
      group.name,
      group.sources
          .map((source) => '“${source.title}”, ${source.publisher}')
          .join('; '),
    );

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

/// Hand a herb and a medicine off to a browser, after confirming, as
/// [searchPairOnline] does a pair.
///
/// Args:
///     context (BuildContext): Where the confirmation is shown.
///     pair (SupplementPair): The herb and the medicine.
///
/// Returns:
///     `Future<void>`: Completes once the browser has opened, the reader has
///     declined, or the failure has been reported.
Future<void> searchSupplementOnline(
  BuildContext context,
  SupplementPair pair,
) => BrowserHandoff.offer(
  context,
  term: AppLocalizations.of(context).checkerSearchTerm(
    pair.supplement.name.toLowerCase(),
    pair.medicine.name.toLowerCase(),
  ),
);

/// Hand a recorded kind of contraception and a medicine off to a browser,
/// after confirming, as [searchPairOnline] does a pair.
///
/// Args:
///     context (BuildContext): Where the confirmation is shown.
///     pair (ConditionPair): The kind and the medicine.
///     label (String): The kind, as the conditions list names it.
///
/// Returns:
///     `Future<void>`: Completes once the browser has opened, the reader has
///     declined, or the failure has been reported.
Future<void> searchConditionOnline(
  BuildContext context,
  ConditionPair pair, {
  required String label,
}) => BrowserHandoff.offer(
  context,
  term: AppLocalizations.of(
    context,
  ).checkerSearchTerm(label.toLowerCase(), pair.medicine.name.toLowerCase()),
);

/// A recorded kind of contraception and a medicine, and every passage where
/// the medicine's label names the kind: what "What the label says" opens.
///
/// The kind has no label of its own, so this shows the one there is.
///
/// Attributes:
///     pair (ConditionPair): The kind and the medicine.
///     label (String): The kind, as the conditions list names it.
class ConditionPairScreen extends StatelessWidget {
  /// Creates the screen.
  ///
  /// Args:
  ///     pair (ConditionPair): The kind and the medicine.
  ///     label (String): The kind, as the conditions list names it.
  const ConditionPairScreen({
    required this.pair,
    required this.label,
    super.key,
  });

  /// The kind and the medicine.
  final ConditionPair pair;

  /// The kind, as the conditions list names it: "Combined pill".
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final kind = conditionKindName(l10n, pair.condition.condition);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.checkerPairTitle(label, pair.medicine.name)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Text(
              l10n.conditionsConflictKind(kind),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (!pair.connected) Text(l10n.checkerNothingFoundPair),
                    for (final reason in conditionReasons(
                      l10n,
                      pair,
                      quotes: true,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(reason),
                      ),
                    for (final mention in pair.mentions)
                      _Mention(
                        mention: mention,
                        medicine: pair.medicine.name,
                        other: kind,
                        kind: true,
                      ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () =>
                          searchConditionOnline(context, pair, label: label),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.checkerSearchOnline),
                    ),
                  ],
                ),
              ),
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

/// One passage where a label names the other medicine, or a fact sheet
/// names a medicine, with the name set apart from the words around it.
///
/// Attributes:
///     mention (LabelMention): The passage, and where the name is in it.
///     medicine (String): Whose label it is from, or whose fact sheet.
///     other (String): Who it names.
///     kind (bool): Whether [other] is a recorded kind of contraception.
///     sheet (bool): Whether the passage is from a herb's fact sheet.
class _Mention extends StatelessWidget {
  /// Creates the passage.
  const _Mention({
    required this.mention,
    required this.medicine,
    required this.other,
    this.kind = false,
    this.sheet = false,
  });

  /// The passage, and where the name is in it.
  final LabelMention mention;

  /// Whose label it is from, by name, or the herb whose fact sheet it is.
  final String medicine;

  /// Who it names, by name.
  final String other;

  /// Whether [other] is a recorded kind of contraception, in the plural.
  final bool kind;

  /// Whether the passage is from NCCIH's fact sheet on [medicine].
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final passage = mention.passage;
    final group = mention.group;
    final leadIn = mention.leadIn;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _mentionSentence(
              l10n,
              mention,
              medicine: medicine,
              other: other,
              kind: kind,
              sheet: sheet,
            ),
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // A list item quoted alone would not say why it is listed:
                  // the line it hangs from does.
                  if (leadIn != null) ...<Widget>[
                    Text(
                      leadIn,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text.rich(
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
                ],
              ),
            ),
          ),
          // Which medicines a group takes in is the table's, not the
          // label's, so where the table had it from is said with it.
          if (group != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(_groupSources(l10n, group), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
