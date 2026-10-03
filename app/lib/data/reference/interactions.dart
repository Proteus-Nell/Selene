/// What medicines' labels say about each other.
///
/// The interaction checker's matching (ADR-0014). Two medicines are compared
/// by what their US labels print and by nothing else: whether they share an
/// ingredient or an FDA class, and where either label's safety sections name
/// the other. There is no severity, no verdict, and no list of interactions
/// written for this app. A pair the labels say nothing about is reported as
/// exactly that, and never as safe together: labels leave interactions out,
/// and they name many medicines only by a class or an abbreviation that this
/// matching does not know.
///
/// Pure, so it can run in a background isolate and in a plain test.
///
/// Includes:
///     - mentionSections: The sections searched, in the order quoted from.
///     - LabelMention: Where one label names another medicine.
///     - InteractionPair: What two medicines' labels say about each other.
///     - checkInteractions: Every pair in a list of medicines.
///     - comparePair: One pair.
///     - _Name: A name to look for, and the pattern that finds it.
///     - _names: The names worth looking for.
///     - _passage: The sentence around a mention.
library;

import 'package:meta/meta.dart';
import 'package:period_tracker/data/reference/medicine.dart';

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
///         or one of its FDA classes.
///     isClass (bool): Whether [name] is a class rather than a substance.
///     passage (String): The sentence around it, as the label prints it.
///     start (int): Where the mention starts in [passage].
///     end (int): Where it ends.
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
  const LabelMention({
    required this.section,
    required this.name,
    required this.isClass,
    required this.passage,
    required this.start,
    required this.end,
  });

  /// The section it is in, by openFDA's field name.
  final String section;

  /// The name found: a match term ("naproxen"), or a class as the FDA names
  /// it ("Nonsteroidal Anti-inflammatory Drug").
  final String name;

  /// Whether [name] is an FDA class rather than a substance.
  final bool isClass;

  /// The sentence around the mention, as the label prints it. Cut short, and
  /// marked with an ellipsis, where the sentence runs on.
  final String passage;

  /// Where the mention starts in [passage].
  final int start;

  /// Where it ends.
  final int end;

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
  const InteractionPair({
    required this.first,
    required this.second,
    required this.sharedSubstances,
    required this.sharedClasses,
    required this.firstMentions,
    required this.secondMentions,
  });

  /// One medicine.
  final MedicineEntry first;

  /// The other.
  final MedicineEntry second;

  /// Ingredients both contain, by the name a label would use: "naproxen".
  final List<String> sharedSubstances;

  /// FDA classes both are in: "Nonsteroidal Anti-inflammatory Drug".
  final List<String> sharedClasses;

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
      firstMentions.isNotEmpty ||
      secondMentions.isNotEmpty;

  @override
  String toString() => 'InteractionPair(${first.key}, ${second.key})';
}

/// Compare every pair in a list of medicines.
///
/// Args:
///     medicines (`List<MedicineEntry>`): The medicines, in the order the
///         reader added them.
///     sections (`Map<String, List<MedicineSection>>`): Each one's label
///         sections, by key.
///
/// Returns:
///     `List<InteractionPair>`: One per pair, in the order the medicines were
///     given: the first with each later one, then the second, and so on.
List<InteractionPair> checkInteractions(
  List<MedicineEntry> medicines,
  Map<String, List<MedicineSection>> sections,
) => <InteractionPair>[
  for (var i = 0; i < medicines.length; i++)
    for (var j = i + 1; j < medicines.length; j++)
      comparePair(
        medicines[i],
        medicines[j],
        firstSections: sections[medicines[i].key] ?? const <MedicineSection>[],
        secondSections: sections[medicines[j].key] ?? const <MedicineSection>[],
      ),
];

/// Compare two medicines.
///
/// Steps:
///     1. Ingredients both contain, by match term or by name.
///     2. FDA classes both are in.
///     3. Where each label names the other, by match term or by class. What
///        the two share is left out of this step: a label naming its own
///        ingredient is talking about itself, and step 1 has said it already.
///
/// Args:
///     first (MedicineEntry): One medicine.
///     second (MedicineEntry): The other.
///     firstSections (`List<MedicineSection>`): [first]'s label.
///     secondSections (`List<MedicineSection>`): [second]'s label.
///
/// Returns:
///     InteractionPair: What was found.
InteractionPair comparePair(
  MedicineEntry first,
  MedicineEntry second, {
  required List<MedicineSection> firstSections,
  required List<MedicineSection> secondSections,
}) {
  final firstNames = _ownNames(first);
  final secondNames = _ownNames(second);
  final shared = firstNames.intersection(secondNames);
  final sharedClasses = first.classes.toSet().intersection(
    second.classes.toSet(),
  );
  return InteractionPair(
    first: first,
    second: second,
    sharedSubstances: _mostSpecific(shared),
    sharedClasses: sharedClasses.toList()..sort(),
    firstMentions: _mentions(
      own: first,
      sections: firstSections,
      other: second,
      skip: shared,
      skipClasses: sharedClasses,
    ),
    secondMentions: _mentions(
      own: second,
      sections: secondSections,
      other: first,
      skip: shared,
      skipClasses: sharedClasses,
    ),
  );
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

/// Where [own]'s label names [other].
///
/// An occurrence inside one of [own]'s own names is not a mention:
/// "estradiol" inside "ethinyl estradiol", on a pill's label, is the pill
/// talking about itself.
///
/// Args:
///     own (MedicineEntry): Whose label is read.
///     sections (`List<MedicineSection>`): That label.
///     other (MedicineEntry): Who is looked for in it.
///     skip (`Set<String>`): Names the two share, not looked for.
///     skipClasses (`Set<String>`): Classes the two share, not looked for.
///
/// Returns:
///     `List<LabelMention>`: At most one per name looked for, from the most
///     telling section it is in, most telling first.
List<LabelMention> _mentions({
  required MedicineEntry own,
  required List<MedicineSection> sections,
  required MedicineEntry other,
  required Set<String> skip,
  required Set<String> skipClasses,
}) {
  final wanted = <_Name>[
    ..._names(other.terms.where((term) => !skip.contains(term))),
    ..._names(
      other.classes.where((name) => !skipClasses.contains(name)),
      isClass: true,
    ),
  ];
  if (wanted.isEmpty) return const <LabelMention>[];
  final mine = <_Name>[
    ..._names(_ownNames(own)),
    ..._names(own.classes, isClass: true),
  ];
  final byName = {for (final section in sections) section.name: section.text};

  final found = <LabelMention>[];
  final remaining = wanted.toList();
  for (final section in mentionSections) {
    final text = byName[section];
    if (text == null || remaining.isEmpty) continue;
    List<(int, int)>? ownSpans;
    for (final name in remaining.toList()) {
      for (final match in name.pattern.allMatches(text)) {
        ownSpans ??= <(int, int)>[
          for (final mineName in mine)
            for (final span in mineName.pattern.allMatches(text))
              (span.start, span.end),
        ];
        final inside = ownSpans.any(
          (span) =>
              span.$1 <= match.start &&
              match.end <= span.$2 &&
              span.$2 - span.$1 > match.end - match.start,
        );
        if (inside) continue;
        found.add(_passage(text, section, name, match.start, match.end));
        remaining.remove(name);
        break;
      }
    }
  }
  return found;
}

/// The sentence around a mention, cut short where it runs on.
///
/// Args:
///     text (String): The section's text.
///     section (String): The section's name.
///     name (_Name): What was found.
///     start (int): Where in [text] it starts.
///     end (int): Where it ends.
///
/// Returns:
///     LabelMention: The mention, with its passage.
LabelMention _passage(
  String text,
  String section,
  _Name name,
  int start,
  int end,
) {
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
  return LabelMention(
    section: section,
    name: name.name,
    isClass: name.isClass,
    passage: '$head${raw.trim()}$tail',
    start: head.length + start - from - lead,
    end: head.length + end - from - lead,
  );
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
    : pattern = RegExp(
        '(?<![A-Za-z0-9])'
        '${_words(name).map(RegExp.escape).join('[^A-Za-z0-9]+')}'
        '${isClass ? '(?:s|es)?' : ''}'
        '(?![A-Za-z0-9])',
        caseSensitive: false,
      );

  /// The name as the index gives it.
  final String name;

  /// Whether it is a class.
  final bool isClass;

  /// What finds it.
  final RegExp pattern;
}
