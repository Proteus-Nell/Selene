/// What medicines' labels say about each other.
///
/// The interaction checker's matching (ADR-0014). Two medicines are compared
/// by what their US labels print and by nothing else: whether they share an
/// ingredient, an FDA class or a group, and where either label's safety
/// sections name the other. There is no severity, no verdict, and no list of
/// interactions written for this app. A pair the labels say nothing about is
/// reported as exactly that, and never as safe together: labels leave
/// interactions out, and they name many medicines by a group or an
/// abbreviation that this matching does not know.
///
/// A group is one of the sourced table's (ADR-0021): "NSAIDs", "combined
/// hormonal contraceptives". The table says which drugs each covers, so a
/// label that names the group names them. A recorded kind of contraception
/// is compared the same way, as what every product of its kind shares.
///
/// A herb is compared with a medicine by NCCIH's fact sheet on it and the
/// medicine's label (ADR-0023): where the label names the herb, where the
/// sheet's safety section names the medicine, its class or a group it is in,
/// and whether the medicine lists the herb among its own ingredients.
///
/// Pure, so it can run in a background isolate and in a plain test.
///
/// Includes:
///     - mentionSections: The sections searched, in the order quoted from.
///     - LabelMention: Where one label names another medicine.
///     - InteractionPair: What two medicines' labels say about each other.
///     - ConditionPair: What a medicine's label says about a recorded kind
///       of contraception.
///     - SupplementPair: What a herb's fact sheet and a medicine's label say
///       about each other.
///     - checkInteractions: Every pair in a list of medicines.
///     - comparePair: One pair.
///     - checkConditions: Every recorded kind of contraception with every
///       medicine.
///     - compareCondition: One of those.
///     - checkSupplements: Every herb with every medicine.
///     - compareSupplement: One of those.
///     - _Side: One side of a comparison, as the matching sees it.
///     - _Name: A name to look for, and the pattern that finds it.
///     - _names: The names worth looking for.
///     - _passage: The sentence around a mention.
library;

import 'package:meta/meta.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_groups.dart';
import 'package:period_tracker/data/reference/supplement.dart';

/// The sections searched for mentions of another medicine, most telling
/// first: where a mention is found in more than one, the first is quoted.
///
/// A label's interactions section, and the Drug Facts lines that say not to
/// combine, come first. Uses, dosing-free population notes and the like are
/// not searched at all: "indicated for use with" is not a warning.
const List<String> mentionSections = <String>[
  'drug_interactions',
  'ask_doctor_or_pharmacist',
  'do_not_use',
  'contraindications',
  'boxed_warning',
  'warnings_and_cautions',
  'warnings',
  'precautions',
  'ask_doctor',
  'when_using',
  'stop_use',
];

/// How many characters of a sentence are kept either side of a mention.
///
/// Interactions sections are often tables flattened into one long run with no
/// full stop in it, which would otherwise be quoted whole.
const int _reach = 200;

/// Where one medicine's label names another.
///
/// Attributes:
///     section (String): The section it is in, by openFDA's field name.
///     name (String): The name found: one of the other medicine's match terms,
///         one of its FDA classes, or the name of a group it is in.
///     isClass (bool): Whether [name] is a class rather than a substance.
///     group (MedicineGroup?): The group, when [name] is one.
///     passage (String): The sentence around it, as the label prints it.
///     start (int): Where the mention starts in [passage].
///     end (int): Where it ends.
///     leadIn (String?): The line a list item hangs from, in a fact sheet.
@immutable
final class LabelMention {
  /// Creates a mention.
  ///
  /// Args:
  ///     section (String): The section, by openFDA's field name.
  ///     name (String): The name found.
  ///     isClass (bool): Whether [name] is a class.
  ///     passage (String): The sentence around it.
  ///     start (int): Where the mention starts in [passage].
  ///     end (int): Where it ends.
  ///     group (MedicineGroup?, optional): The group [name] is, if it is one.
  ///         Defaults to null.
  ///     leadIn (String?, optional): The line [passage] hangs from, where it
  ///         is an item in a fact sheet's list. Defaults to null.
  const LabelMention({
    required this.section,
    required this.name,
    required this.isClass,
    required this.passage,
    required this.start,
    required this.end,
    this.group,
    this.leadIn,
  });

  /// The section it is in: openFDA's field name for a label's, and the
  /// heading itself for a fact sheet's, "What Do We Know About Safety?".
  final String section;

  /// The name found: a match term ("naproxen"), a class as the FDA names it
  /// ("Nonsteroidal Anti-inflammatory Drug"), or a group's name ("NSAIDs").
  final String name;

  /// Whether [name] is an FDA class rather than a substance.
  final bool isClass;

  /// The group, when the label names the other medicine by one: the words
  /// it printed are one of the group's phrases. Null for a name or a class.
  final MedicineGroup? group;

  /// The sentence around the mention, as the label prints it. Cut short, and
  /// marked with an ellipsis, where the sentence runs on.
  final String passage;

  /// Where the mention starts in [passage].
  final int start;

  /// Where it ends.
  final int end;

  /// The line [passage] hangs from, where it is an item in a fact sheet's
  /// list: "St. John's wort can weaken the effects of many medicines ...
  /// such as:", above "Birth control pills". Null for a label's passage, which
  /// is a sentence of its own.
  final String? leadIn;

  @override
  String toString() => 'LabelMention($section: $name)';
}

/// What two medicines' labels say about each other.
///
/// Attributes:
///     first (MedicineEntry): One medicine.
///     second (MedicineEntry): The other.
///     sharedSubstances (`List<String>`): Ingredients both contain.
///     sharedClasses (`List<String>`): FDA classes both are in.
///     sharedGroups (`List<MedicineGroup>`): Groups both are in.
///     firstMentions (`List<LabelMention>`): Where [first]'s label names
///         [second].
///     secondMentions (`List<LabelMention>`): Where [second]'s label names
///         [first].
@immutable
final class InteractionPair {
  /// Creates a pair.
  ///
  /// Args:
  ///     first (MedicineEntry): One medicine.
  ///     second (MedicineEntry): The other.
  ///     sharedSubstances (`List<String>`): Ingredients both contain.
  ///     sharedClasses (`List<String>`): FDA classes both are in.
  ///     firstMentions (`List<LabelMention>`): Where [first]'s label names
  ///         [second].
  ///     secondMentions (`List<LabelMention>`): Where [second]'s label names
  ///         [first].
  ///     sharedGroups (`List<MedicineGroup>`, optional): Groups both are in.
  ///         Defaults to none.
  const InteractionPair({
    required this.first,
    required this.second,
    required this.sharedSubstances,
    required this.sharedClasses,
    required this.firstMentions,
    required this.secondMentions,
    this.sharedGroups = const <MedicineGroup>[],
  });

  /// One medicine.
  final MedicineEntry first;

  /// The other.
  final MedicineEntry second;

  /// Ingredients both contain, by the name a label would use: "naproxen".
  final List<String> sharedSubstances;

  /// FDA classes both are in: "Nonsteroidal Anti-inflammatory Drug".
  final List<String> sharedClasses;

  /// Groups both are in, the narrowest of them: two combined pills are
  /// combined oral contraceptives, and saying they are hormonal ones too
  /// would add nothing. A group whose FDA class both are in is left out, as
  /// [sharedClasses] has said it.
  final List<MedicineGroup> sharedGroups;

  /// Where [first]'s label names [second], most telling section first.
  final List<LabelMention> firstMentions;

  /// Where [second]'s label names [first], most telling section first.
  final List<LabelMention> secondMentions;

  /// Whether the labels connect the two in any of these ways.
  ///
  /// **False never means safe together.** It means neither label names the
  /// other in a way this matching can find, and nothing more.
  bool get connected =>
      sharedSubstances.isNotEmpty ||
      sharedClasses.isNotEmpty ||
      sharedGroups.isNotEmpty ||
      firstMentions.isNotEmpty ||
      secondMentions.isNotEmpty;

  @override
  String toString() => 'InteractionPair(${first.key}, ${second.key})';
}

/// What a recorded medicine's label says about a recorded kind of
/// contraception.
///
/// The condition has no label of its own, so only the medicine's is read.
///
/// Attributes:
///     condition (ConditionKind): The kind of contraception, and what it
///         counts as.
///     medicine (MedicineEntry): The medicine.
///     sharedSubstances (`List<String>`): Ingredients both contain.
///     sharedGroups (`List<MedicineGroup>`): Groups both are in.
///     mentions (`List<LabelMention>`): Where the medicine's label names
///         the condition's kind.
@immutable
final class ConditionPair {
  /// Creates a pair.
  ///
  /// Args:
  ///     condition (ConditionKind): The kind of contraception.
  ///     medicine (MedicineEntry): The medicine.
  ///     sharedSubstances (`List<String>`): Ingredients both contain.
  ///     sharedGroups (`List<MedicineGroup>`): Groups both are in.
  ///     mentions (`List<LabelMention>`): Where the medicine's label names
  ///         it.
  const ConditionPair({
    required this.condition,
    required this.medicine,
    required this.sharedSubstances,
    required this.sharedGroups,
    required this.mentions,
  });

  /// The kind of contraception, and what it counts as.
  final ConditionKind condition;

  /// The medicine.
  final MedicineEntry medicine;

  /// Ingredients both contain: the hormonal IUD's levonorgestrel, in an
  /// emergency pill.
  final List<String> sharedSubstances;

  /// Groups both are in, the narrowest of them.
  final List<MedicineGroup> sharedGroups;

  /// Where the medicine's label names the condition's kind, by an
  /// ingredient every product of it contains or a group they are all in.
  final List<LabelMention> mentions;

  /// Whether the label connects the two in any of these ways.
  ///
  /// **False never means safe together**, as for [InteractionPair.connected].
  bool get connected =>
      sharedSubstances.isNotEmpty ||
      sharedGroups.isNotEmpty ||
      mentions.isNotEmpty;

  @override
  String toString() =>
      'ConditionPair(${condition.condition.name}, ${medicine.key})';
}

/// What a herb's fact sheet and a medicine's label say about each other.
///
/// Attributes:
///     supplement (Supplement): The herb.
///     medicine (MedicineEntry): The medicine.
///     ingredients (`List<String>`): The medicine's own ingredients that are
///         the herb.
///     labelMentions (`List<LabelMention>`): Where the medicine's label names
///         the herb.
///     sheetMentions (`List<LabelMention>`): Where the herb's fact sheet names
///         the medicine, or a class or group it is in.
@immutable
final class SupplementPair {
  /// Creates a pair.
  ///
  /// Args:
  ///     supplement (Supplement): The herb.
  ///     medicine (MedicineEntry): The medicine.
  ///     ingredients (`List<String>`): The medicine's ingredients that are the
  ///         herb.
  ///     labelMentions (`List<LabelMention>`): Where the label names the herb.
  ///     sheetMentions (`List<LabelMention>`): Where the fact sheet names the
  ///         medicine.
  const SupplementPair({
    required this.supplement,
    required this.medicine,
    required this.ingredients,
    required this.labelMentions,
    required this.sheetMentions,
  });

  /// The herb.
  final Supplement supplement;

  /// The medicine.
  final MedicineEntry medicine;

  /// The medicine's own ingredients that are the herb, as its label names
  /// them: "hypericum perforatum", in a remedy that lists it.
  final List<String> ingredients;

  /// Where the medicine's label names the herb, by any of its names: at most
  /// one, from the most telling section.
  final List<LabelMention> labelMentions;

  /// Where the herb's fact sheet names the medicine, a class it is in or a
  /// group it is in. Only its safety section is read (ADR-0023).
  final List<LabelMention> sheetMentions;

  /// Whether the label and the fact sheet connect the two in any of these
  /// ways.
  ///
  /// **False never means safe together**, as for [InteractionPair.connected]:
  /// a fact sheet names only some of the medicines a herb interacts with, and
  /// many only by a kind, "some antidepressants".
  bool get connected =>
      ingredients.isNotEmpty ||
      labelMentions.isNotEmpty ||
      sheetMentions.isNotEmpty;

  @override
  String toString() => 'SupplementPair(${supplement.key}, ${medicine.key})';
}

/// Compare every pair in a list of medicines.
///
/// Args:
///     medicines (`List<MedicineEntry>`): The medicines, in the order the
///         reader added them.
///     sections (`Map<String, List<MedicineSection>>`): Each one's label
///         sections, by key.
///     groups (MedicineGroups): The group table, or [MedicineGroups.none].
///
/// Returns:
///     `List<InteractionPair>`: One per pair, in the order the medicines were
///     given: the first with each later one, then the second, and so on.
List<InteractionPair> checkInteractions(
  List<MedicineEntry> medicines,
  Map<String, List<MedicineSection>> sections, {
  required MedicineGroups groups,
}) => <InteractionPair>[
  for (var i = 0; i < medicines.length; i++)
    for (var j = i + 1; j < medicines.length; j++)
      comparePair(
        medicines[i],
        medicines[j],
        firstSections: sections[medicines[i].key] ?? const <MedicineSection>[],
        secondSections: sections[medicines[j].key] ?? const <MedicineSection>[],
        groups: groups,
      ),
];

/// Compare two medicines.
///
/// Steps:
///     1. Ingredients both contain, by match term or by name.
///     2. FDA classes both are in.
///     3. Groups both are in.
///     4. Where each label names the other, by match term, by class or by
///        group. What the two share is left out of this step: a label naming
///        its own ingredient is talking about itself, and steps 1 to 3 have
///        said it already.
///
/// Args:
///     first (MedicineEntry): One medicine.
///     second (MedicineEntry): The other.
///     firstSections (`List<MedicineSection>`): [first]'s label.
///     secondSections (`List<MedicineSection>`): [second]'s label.
///     groups (MedicineGroups): The group table, or [MedicineGroups.none].
///
/// Returns:
///     InteractionPair: What was found.
InteractionPair comparePair(
  MedicineEntry first,
  MedicineEntry second, {
  required List<MedicineSection> firstSections,
  required List<MedicineSection> secondSections,
  required MedicineGroups groups,
}) {
  final a = _Side.medicine(first, groups);
  final b = _Side.medicine(second, groups);
  final shared = a.names.intersection(b.names);
  final sharedClasses = a.classes.toSet().intersection(b.classes.toSet());
  final sharedGroups = a.groups.intersection(b.groups);
  return InteractionPair(
    first: first,
    second: second,
    sharedSubstances: _mostSpecific(shared),
    sharedClasses: sharedClasses.toList()..sort(),
    sharedGroups: _narrowest(groups, sharedGroups, besides: sharedClasses),
    firstMentions: _mentions(
      own: a,
      sections: firstSections,
      other: b,
      skip: shared,
      skipClasses: sharedClasses,
      skipGroups: sharedGroups,
      table: groups,
    ),
    secondMentions: _mentions(
      own: b,
      sections: secondSections,
      other: a,
      skip: shared,
      skipClasses: sharedClasses,
      skipGroups: sharedGroups,
      table: groups,
    ),
  );
}

/// Compare each recorded kind of contraception with each recorded medicine.
///
/// A kind with one of its own products among the medicines is left out
/// altogether: somebody who records the combined pill and their pill's name
/// has recorded one thing twice, and the medicine, with its own label, stands
/// for it in the medicine pairs.
///
/// Args:
///     conditions (`List<ConditionKind>`): The kinds recorded, in the order
///         they were recorded.
///     medicines (`List<MedicineEntry>`): The medicines, in the order added.
///     sections (`Map<String, List<MedicineSection>>`): Each medicine's label
///         sections, by key.
///     groups (MedicineGroups): The group table the kinds come from.
///
/// Returns:
///     `List<ConditionPair>`: One per kind and medicine, kind by kind.
List<ConditionPair> checkConditions(
  List<ConditionKind> conditions,
  List<MedicineEntry> medicines,
  Map<String, List<MedicineSection>> sections, {
  required MedicineGroups groups,
}) => <ConditionPair>[
  for (final condition in conditions)
    if (!medicines.any(condition.isKind))
      for (final medicine in medicines)
        compareCondition(
          condition,
          medicine,
          sections: sections[medicine.key] ?? const <MedicineSection>[],
          groups: groups,
        ),
];

/// Compare a recorded kind of contraception with a medicine.
///
/// As [comparePair], with the condition counting as what every product of
/// its kind shares, and with only the medicine's label to read.
///
/// Args:
///     condition (ConditionKind): The kind of contraception.
///     medicine (MedicineEntry): The medicine.
///     sections (`List<MedicineSection>`): The medicine's label.
///     groups (MedicineGroups): The group table the kind comes from.
///
/// Returns:
///     ConditionPair: What was found.
ConditionPair compareCondition(
  ConditionKind condition,
  MedicineEntry medicine, {
  required List<MedicineSection> sections,
  required MedicineGroups groups,
}) {
  final own = _Side.medicine(medicine, groups);
  final kind = _Side.condition(condition);
  final shared = own.names.intersection(kind.names);
  final sharedGroups = own.groups.intersection(kind.groups);
  return ConditionPair(
    condition: condition,
    medicine: medicine,
    sharedSubstances: _mostSpecific(shared),
    sharedGroups: _narrowest(groups, sharedGroups, besides: const <String>{}),
    mentions: _mentions(
      own: own,
      sections: sections,
      other: kind,
      skip: shared,
      skipClasses: const <String>{},
      skipGroups: sharedGroups,
      table: groups,
    ),
  );
}

/// Compare each herb with each medicine.
///
/// Herbs are not compared with each other: no fact sheet's safety section
/// names another of the herbs, and two herbs have no label between them.
///
/// Args:
///     supplements (`List<Supplement>`): The herbs, in the order added.
///     medicines (`List<MedicineEntry>`): The medicines, in the order added.
///     sections (`Map<String, List<MedicineSection>>`): Each medicine's label
///         sections, by key.
///     groups (MedicineGroups): The group table, or [MedicineGroups.none].
///
/// Returns:
///     `List<SupplementPair>`: One per herb and medicine, herb by herb.
List<SupplementPair> checkSupplements(
  List<Supplement> supplements,
  List<MedicineEntry> medicines,
  Map<String, List<MedicineSection>> sections, {
  required MedicineGroups groups,
}) => <SupplementPair>[
  for (final supplement in supplements)
    for (final medicine in medicines)
      compareSupplement(
        supplement,
        medicine,
        sections: sections[medicine.key] ?? const <MedicineSection>[],
        groups: groups,
      ),
];

/// Compare a herb with a medicine.
///
/// Steps:
///     1. The medicine's own ingredients that are the herb: one whose name
///        starts with any of the herb's, "hawthorn leaf with flower".
///     2. Where the medicine's label names the herb, by any of its names, as
///        [comparePair] looks for a medicine's. Not for a medicine that
///        contains it: that label is talking about itself.
///     3. Where the herb's safety section names the medicine, a class it is
///        in or a group it is in. The herb's own names are not looked for
///        there, though a medicine that contains it goes by them.
///
/// Args:
///     supplement (Supplement): The herb.
///     medicine (MedicineEntry): The medicine.
///     sections (`List<MedicineSection>`): The medicine's label.
///     groups (MedicineGroups): The group table, or [MedicineGroups.none].
///
/// Returns:
///     SupplementPair: What was found.
SupplementPair compareSupplement(
  Supplement supplement,
  MedicineEntry medicine, {
  required List<MedicineSection> sections,
  required MedicineGroups groups,
}) {
  final own = _Side.medicine(medicine, groups);
  final herb = _Side.supplement(supplement);
  final herbNames = <String>{
    for (final term in supplement.terms) _words(term).join(' '),
  }..remove('');
  bool isHerb(String name) {
    final words = _words(name).join(' ');
    return herbNames.any(
      (herbName) => words == herbName || words.startsWith('$herbName '),
    );
  }

  // As the label prints them, in lower case: "st. john's wort".
  final ingredients = <String>{
    for (final substance in medicine.substances)
      if (isHerb(substance)) substance.toLowerCase(),
  }.toList()..sort();
  final safety = supplement.safety;
  return SupplementPair(
    supplement: supplement,
    medicine: medicine,
    ingredients: ingredients,
    labelMentions: ingredients.isNotEmpty
        ? const <LabelMention>[]
        : _mentions(
            own: own,
            sections: sections,
            other: herb,
            skip: const <String>{},
            skipClasses: const <String>{},
            skipGroups: const <MedicineGroup>{},
            table: groups,
          ),
    sheetMentions: safety == null
        ? const <LabelMention>[]
        : _mentions(
            own: herb,
            sections: <MedicineSection>[
              MedicineSection(name: safety.heading, text: safety.text),
            ],
            searched: <String>[safety.heading],
            other: own,
            skip: <String>{
              for (final term in medicine.terms)
                if (isHerb(term)) term,
            },
            skipClasses: const <String>{},
            skipGroups: const <MedicineGroup>{},
            table: groups,
            leadIn: (_, offset) => safety.leadIn(offset),
          ),
  );
}

/// One side of a comparison, as the matching sees it: a medicine, a
/// recorded kind of contraception counting as what its products share, or a
/// herb.
///
/// Attributes:
///     terms (`List<String>`): What another label would call it.
///     names (`Set<String>`): Every name its ingredients go by.
///     classes (`List<String>`): The FDA classes it is in.
///     groups (`Set<MedicineGroup>`): The groups it is in.
///     one (String?): The name to look for [terms] under as one, for a side
///         that is one thing by many names: a herb.
final class _Side {
  /// A medicine.
  _Side.medicine(MedicineEntry entry, MedicineGroups table)
    : terms = entry.terms,
      names = _ownNames(entry),
      classes = entry.classes,
      groups = table.of(entry).toSet(),
      one = null;

  /// A recorded kind of contraception. It is in no FDA class of its own.
  _Side.condition(ConditionKind kind)
    : terms = kind.names,
      names = kind.names.toSet(),
      classes = const <String>[],
      groups = kind.groups.toSet(),
      one = null;

  /// A herb, by every name NCCIH gives it. It is in no class and no group.
  _Side.supplement(Supplement supplement)
    : terms = supplement.terms,
      names = supplement.terms.toSet(),
      classes = const <String>[],
      groups = const <MedicineGroup>{},
      one = supplement.name;

  /// What another label would call it.
  final List<String> terms;

  /// Every name its ingredients go by.
  final Set<String> names;

  /// The FDA classes it is in.
  final List<String> classes;

  /// The groups it is in.
  final Set<MedicineGroup> groups;

  /// The name [terms] are looked for under as one, so that a label printing
  /// "St. John's Wort (Hypericum perforatum)" is found to name the herb once
  /// rather than twice. Null for a side whose terms are each a name of its
  /// own: a medicine's ingredients.
  final String? one;
}

/// Every name [entry]'s ingredients go by: its match terms, and its
/// substances' own names in the same form.
///
/// The names as well as the terms, so that two drugs which contain the same
/// thing are found to, even where no other label could name it.
Set<String> _ownNames(MedicineEntry entry) => <String>{
  ...entry.terms,
  for (final substance in entry.substances) _words(substance).join(' '),
}..remove('');

/// [names] without any that another of them starts with: "naproxen sodium"
/// rather than both it and "naproxen", sorted.
List<String> _mostSpecific(Set<String> names) =>
    names
        .where(
          (name) => !names.any(
            (other) => other != name && other.startsWith('$name '),
          ),
        )
        .toList()
      ..sort();

/// The narrowest of [shared], in the table's order.
///
/// Leaves out a group with a narrower one inside it, and one whose FDA class
/// is among [besides], the classes the two are already said to share.
List<MedicineGroup> _narrowest(
  MedicineGroups table,
  Set<MedicineGroup> shared, {
  required Set<String> besides,
}) => <MedicineGroup>[
  for (final group in table.groups)
    if (shared.contains(group) &&
        !group.classes.any(besides.contains) &&
        !shared.any(
          (other) =>
              other != group &&
              other.members.length < group.members.length &&
              group.members.containsAll(other.members),
        ))
      group,
];

/// Where [own]'s label names [other].
///
/// An occurrence inside one of [own]'s own names is not a mention:
/// "estradiol" inside "ethinyl estradiol", on a pill's label, is the pill
/// talking about itself.
///
/// A group is held to three rules more, because its phrases are common words
/// that labels qualify:
///   - one straight after "non" is not one: "non-hormonal contraception";
///   - nor is one inside a longer group phrase: "hormonal contraceptives" in
///     "combined hormonal contraceptives" names only the combined ones;
///   - nor is one in a sentence already quoted: "nonsteroidal
///     anti-inflammatory drugs (NSAIDs)" is quoted once, by its class.
///
/// Args:
///     own (_Side): Whose label is read.
///     sections (`List<MedicineSection>`): That label.
///     other (_Side): Who is looked for in it.
///     skip (`Set<String>`): Names the two share, not looked for.
///     skipClasses (`Set<String>`): Classes the two share, not looked for.
///     skipGroups (`Set<MedicineGroup>`): Groups the two share, not looked
///         for.
///     table (MedicineGroups): Every group, for their phrases.
///     searched (`List<String>`, optional): The sections read, most telling
///         first. Defaults to [mentionSections], a label's.
///     leadIn (`String? Function(String, int)?`, optional): The line a
///         mention at an offset in a section hangs from, for a fact sheet's
///         lists. Defaults to null, for a label.
///
/// Returns:
///     `List<LabelMention>`: At most one per name, class and group looked for,
///     from the most telling section it is in, most telling first.
List<LabelMention> _mentions({
  required _Side own,
  required List<MedicineSection> sections,
  required _Side other,
  required Set<String> skip,
  required Set<String> skipClasses,
  required Set<MedicineGroup> skipGroups,
  required MedicineGroups table,
  List<String> searched = mentionSections,
  String? Function(String section, int offset)? leadIn,
}) {
  final terms = other.terms.where((term) => !skip.contains(term));
  final one = other.one;
  final wanted = <_Name>[
    if (one == null)
      ..._names(terms)
    else if (terms.any((term) => _words(term).isNotEmpty))
      _Name.any(one, terms),
    ..._names(
      other.classes.where((name) => !skipClasses.contains(name)),
      isClass: true,
    ),
  ];
  final groups = <MedicineGroup>[
    for (final group in table.groups)
      if (other.groups.contains(group) && !skipGroups.contains(group)) group,
  ];
  if (wanted.isEmpty && groups.isEmpty) return const <LabelMention>[];
  final mine = <_Name>[
    ..._names(own.names),
    ..._names(own.classes, isClass: true),
  ];
  final byName = {for (final section in sections) section.name: section.text};

  final found = <LabelMention>[];
  final remaining = wanted.toList();
  final remainingGroups = groups.toList();
  for (final section in searched) {
    final text = byName[section];
    if (text == null || (remaining.isEmpty && remainingGroups.isEmpty)) {
      continue;
    }
    List<(int, int)>? ownSpans;
    List<(int, int)> mineIn() => ownSpans ??= <(int, int)>[
      for (final mineName in mine)
        for (final span in mineName.pattern.allMatches(text))
          (span.start, span.end),
    ];
    bool insideOwn(Match match) => mineIn().any(
      (span) =>
          span.$1 <= match.start &&
          match.end <= span.$2 &&
          span.$2 - span.$1 > match.end - match.start,
    );
    // The sentences quoted from this section so far, as ranges of [text].
    final quoted = <(int, int)>[];
    for (final name in remaining.toList()) {
      for (final match in name.pattern.allMatches(text)) {
        if (insideOwn(match)) continue;
        final (mention, from, to) = _passage(
          text,
          section,
          name.name,
          match.start,
          match.end,
          isClass: name.isClass,
          leadIn: leadIn?.call(section, match.start),
        );
        found.add(mention);
        quoted.add((from, to));
        remaining.remove(name);
        break;
      }
    }
    if (remainingGroups.isEmpty) continue;
    List<(int, int)>? phraseSpans;
    for (final group in remainingGroups.toList()) {
      for (final match in _groupPattern(group).allMatches(text)) {
        if (_afterNon(text, match.start) || insideOwn(match)) continue;
        phraseSpans ??= <(int, int)>[
          for (final any in table.groups)
            for (final span in _groupPattern(any).allMatches(text))
              (span.start, span.end),
        ];
        final insideLonger = phraseSpans.any(
          (span) =>
              span.$1 <= match.start &&
              match.end <= span.$2 &&
              span.$2 - span.$1 > match.end - match.start,
        );
        if (insideLonger) continue;
        final (mention, from, to) = _passage(
          text,
          section,
          group.name,
          match.start,
          match.end,
          group: group,
          leadIn: leadIn?.call(section, match.start),
        );
        if (quoted.any((range) => range.$1 < to && from < range.$2)) continue;
        found.add(mention);
        quoted.add((from, to));
        remainingGroups.remove(group);
        break;
      }
    }
  }
  return found;
}

/// Whether the word at [start] follows "non" and a hyphen or a space, as in
/// "non-hormonal contraception" or "non NSAID analgesics".
bool _afterNon(String text, int start) {
  if (start < 4) return false;
  final before = text.substring(start - 4, start).toLowerCase();
  if (before != 'non-' && before != 'non ') return false;
  return start == 4 || !_isLetter(text.codeUnitAt(start - 5));
}

/// The sentence around a mention, cut short where it runs on.
///
/// Args:
///     text (String): The section's text.
///     section (String): The section's name.
///     name (String): What was found: a term, a class or a group's name.
///     start (int): Where in [text] it starts.
///     end (int): Where it ends.
///     isClass (bool, optional): Whether [name] is a class. Defaults to
///         false.
///     group (MedicineGroup?, optional): The group [name] is, if it is one.
///         Defaults to null.
///     leadIn (String?, optional): The line the passage hangs from, in a
///         fact sheet's list. Defaults to null.
///
/// Returns:
///     `(LabelMention, int, int)`: The mention, with its passage, and where in
///     [text] the passage starts and ends.
(LabelMention, int, int) _passage(
  String text,
  String section,
  String name,
  int start,
  int end, {
  bool isClass = false,
  MedicineGroup? group,
  String? leadIn,
}) {
  // Back to where the sentence starts, or as far as the reach allows.
  var from = start;
  while (from > 0 && !_endsSentence(text, from - 1) && start - from < _reach) {
    from--;
  }
  final cutHead = from > 0 && !_endsSentence(text, from - 1);
  // On to where it ends, likewise.
  var to = end;
  while (to < text.length && !_endsSentence(text, to) && to - end < _reach) {
    to++;
  }
  final cutTail = to < text.length && !_endsSentence(text, to);
  // Keep the full stop that ends the sentence; a line break needs no keeping.
  if (!cutTail && to < text.length && text[to] != '\n') to++;
  // Where the cut is ours, it falls between words rather than through one.
  if (cutHead) {
    final space = text.indexOf(' ', from);
    if (space != -1 && space < start) from = space + 1;
  }
  if (cutTail) {
    final space = text.lastIndexOf(' ', to);
    if (space >= end) to = space;
  }

  final raw = text.substring(from, to);
  final lead = raw.length - raw.trimLeft().length;
  final head = cutHead ? '…' : '';
  final tail = cutTail ? '…' : '';
  final mention = LabelMention(
    section: section,
    name: name,
    isClass: isClass,
    group: group,
    passage: '$head${raw.trim()}$tail',
    start: head.length + start - from - lead,
    end: head.length + end - from - lead,
    leadIn: leadIn,
  );
  return (mention, from, to);
}

/// Whether the character at [i] ends a sentence: a line break, or a full stop,
/// question or exclamation mark followed by a space or the end.
///
/// Not a full stop after a word of one or two letters, nor one followed by a
/// lower-case word: "St. John's wort" and "e.g. aspirin" run on, and cutting
/// them there would quote half a name.
bool _endsSentence(String text, int i) {
  final char = text[i];
  if (char == '\n') return true;
  if (char != '.' && char != '?' && char != '!') return false;
  final next = i + 1;
  if (next < text.length && text[next] != ' ' && text[next] != '\n') {
    return false;
  }
  if (char != '.') return true;
  var word = i;
  while (word > 0 && _isLetter(text.codeUnitAt(word - 1))) {
    word--;
  }
  if (i - word == 1 || i - word == 2) return false;
  var after = next;
  while (after < text.length && text[after] == ' ') {
    after++;
  }
  return after >= text.length || !_isLower(text.codeUnitAt(after));
}

/// Whether [unit] is an ASCII letter.
bool _isLetter(int unit) => _isLower(unit) || (unit >= 0x41 && unit <= 0x5A);

/// Whether [unit] is an ASCII lower-case letter.
bool _isLower(int unit) => unit >= 0x61 && unit <= 0x7A;

/// The lower-case words of [text].
List<String> _words(String text) => <String>[
  for (final match in RegExp('[a-z0-9]+').allMatches(text.toLowerCase()))
    match[0]!,
];

/// A [_Name] for each of [names] that has a word in it.
///
/// One with none would match the empty string, and so every label there is.
Iterable<_Name> _names(Iterable<String> names, {bool isClass = false}) => names
    .where((name) => _words(name).isNotEmpty)
    .map((name) => _Name(name, isClass: isClass));

/// A name to look for in a label, and the pattern that finds it.
///
/// The name's words in order, with anything but a letter or digit between
/// them, and neither a letter nor a digit either side: "naproxen" is found in
/// "Naproxen," and in "naproxen-containing", but not in "naproxenate". A
/// class may be plural, "Nonsteroidal anti-inflammatory drugs".
final class _Name {
  /// Builds the pattern for [name].
  _Name(this.name, {required this.isClass})
    : pattern = _pattern(<String>[name], plural: isClass);

  /// Builds one pattern for all of [phrases], found under [name]: a herb, by
  /// any of the names NCCIH gives it.
  _Name.any(this.name, Iterable<String> phrases)
    : isClass = false,
      pattern = _pattern(phrases, plural: false);

  /// The name as the index gives it, or the herb's.
  final String name;

  /// Whether it is a class.
  final bool isClass;

  /// What finds it.
  final RegExp pattern;
}

/// What finds any of [group]'s phrases: each phrase's words in order, as
/// [_Name] finds a name, and a plural allowed, as for a class.
///
/// The longest phrase first, so that where two start at the same word the
/// longer is what is found.
RegExp _groupPattern(MedicineGroup group) =>
    _groupPatterns[group] ??= _pattern(group.phrases, plural: true);

/// [_groupPattern]'s, made once for each group.
final Expando<RegExp> _groupPatterns = Expando<RegExp>('group patterns');

/// What finds any of [phrases]: each one's words in order, with anything but
/// a letter or digit between them, and neither a letter nor a digit either
/// side. The longest first, so that where two start at the same word the
/// longer is what is found.
///
/// Args:
///     phrases (`Iterable<String>`): What to find. Each must have a word in
///         it: one with none would match the empty string.
///     plural (bool): Whether a plural is found too, "NSAIDs".
///
/// Returns:
///     RegExp: The pattern, ignoring case.
RegExp _pattern(Iterable<String> phrases, {required bool plural}) {
  final alternatives = <String>[
    for (final phrase in phrases)
      if (_words(phrase).isNotEmpty)
        _words(phrase).map(RegExp.escape).join('[^A-Za-z0-9]+'),
  ]..sort((a, b) => b.length.compareTo(a.length));
  return RegExp(
    '(?<![A-Za-z0-9])(?:${alternatives.join('|')})'
    '${plural ? '(?:s|es)?' : ''}(?![A-Za-z0-9])',
    caseSensitive: false,
  );
}
