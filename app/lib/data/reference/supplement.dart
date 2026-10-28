/// Herbal supplements reference model, and the search over it.
///
/// The shape of the reference `tools/scripts/gen_supplements.py` writes into
/// `app/assets/supplements`: NCCIH's Herbs at a Glance fact sheets, which are
/// in the public domain, carried as NCCIH wrote them (ADR-0023). Reading it
/// off the assets is `supplement_bundle.dart`'s job; everything here is pure,
/// so it can run in a background isolate and in a plain test.
///
/// Includes:
///     - supplementSafetyHeading: The section the interaction checker reads.
///     - SupplementBlock: One paragraph or list item of a fact sheet.
///     - SupplementSection: One section of a fact sheet, under its heading.
///     - Supplement: One herb, and its fact sheet.
///     - SupplementMatch: A herb a search found, and the name it was found by.
///     - SupplementReference: Every herb, and the search over them.
library;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:period_tracker/data/reference/medicine.dart';

/// The reference format this code reads: the generator's `SCHEMA_VERSION`.
const int supplementsSchemaVersion = 1;

/// The heading of the section that says what is known about a herb's safety,
/// and so which medicines it interacts with. Every fact sheet has it, and the
/// interaction checker reads it and no other section (ADR-0023).
const String supplementSafetyHeading = 'What Do We Know About Safety?';

/// What starts a list item, by how deep it is nested: the disc, circle and
/// square the pages draw. The generator's `MARKS`.
const List<String> _marks = <String>['• ', '◦ ', '▪ '];

/// One paragraph or list item of a fact sheet.
///
/// Attributes:
///     text (String): What it says, as the page prints it.
///     depth (int): 0 for a paragraph, 1 for a list item, 2 for an item in a
///         list inside another, and so on.
@immutable
final class SupplementBlock {
  /// Creates a block.
  ///
  /// Args:
  ///     text (String): What it says.
  ///     depth (int, optional): How deep in lists it is. Defaults to 0, a
  ///         paragraph.
  const SupplementBlock({required this.text, this.depth = 0});

  /// Read a block as the generator writes it: the mark the page draws for a
  /// list item, if it is one, and then its text.
  factory SupplementBlock.parse(String block) {
    for (final (i, mark) in _marks.indexed) {
      if (block.startsWith(mark)) {
        return SupplementBlock(
          text: block.substring(mark.length),
          depth: i + 1,
        );
      }
    }
    return SupplementBlock(text: block);
  }

  /// What it says, as the page prints it, without its mark.
  final String text;

  /// How deep in lists it is: 0 for a paragraph.
  final int depth;

  @override
  bool operator ==(Object other) =>
      other is SupplementBlock && other.text == text && other.depth == depth;

  @override
  int get hashCode => Object.hash(text, depth);
}

/// One section of a fact sheet, under its heading.
///
/// Attributes:
///     heading (String): Its heading, as the page gives it: "What Do We Know
///         About Safety?"
///     blocks (`List<SupplementBlock>`): Its paragraphs and list items.
@immutable
final class SupplementSection {
  /// Creates a section.
  ///
  /// Args:
  ///     heading (String): Its heading.
  ///     blocks (`List<SupplementBlock>`): Its paragraphs and list items.
  const SupplementSection({required this.heading, required this.blocks});

  /// Read a section as the generator writes it: `[heading, [block, ...]]`.
  factory SupplementSection.fromJson(Object? pair) {
    final values = pair! as List<Object?>;
    return SupplementSection(
      heading: values[0]! as String,
      blocks: List<SupplementBlock>.unmodifiable(<SupplementBlock>[
        for (final block in values[1]! as List<Object?>)
          SupplementBlock.parse(block! as String),
      ]),
    );
  }

  /// Its heading, as the page gives it.
  final String heading;

  /// Its paragraphs and list items, in order.
  final List<SupplementBlock> blocks;

  /// The section as the interaction checker reads it: each block on a line
  /// of its own, without its mark, so that no quoted sentence runs from one
  /// into the next.
  String get text => blocks.map((block) => block.text).join('\n');

  /// The line a list item hangs from, for the item at [offset] in [text].
  ///
  /// A list in a fact sheet is often a run of names under a line that says
  /// what they are: "St. John's wort can weaken the effects of many
  /// medicines ... such as:", then "Birth control pills". The item alone
  /// would not say why it is there.
  ///
  /// Args:
  ///     offset (int): Where in [text] something was found.
  ///
  /// Returns:
  ///     String?: The nearest line above the item, less deep in the lists
  ///     than it is, when that line ends with a colon. Null for a paragraph,
  ///     an item under no such line, or an offset past the end.
  String? leadIn(int offset) {
    var start = 0;
    for (final (i, block) in blocks.indexed) {
      final end = start + block.text.length;
      if (offset <= end) {
        if (block.depth == 0) return null;
        for (var j = i - 1; j >= 0; j--) {
          final above = blocks[j];
          if (above.depth < block.depth) {
            return above.text.trimRight().endsWith(':') ? above.text : null;
          }
        }
        return null;
      }
      // The line break after it.
      start = end + 1;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SupplementSection &&
      other.heading == heading &&
      _sameBlocks(other.blocks, blocks);

  @override
  int get hashCode => Object.hash(heading, Object.hashAll(blocks));
}

/// Whether two lists of blocks hold the same blocks in the same order.
bool _sameBlocks(List<SupplementBlock> a, List<SupplementBlock> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One herb, and its fact sheet.
///
/// Attributes:
///     key (String): NCCIH's address for the page: "st-johns-wort". Never
///         shown.
///     name (String): The page's title: "St. John's Wort".
///     commonNames (`List<String>`): Its common names, as the page lists
///         them.
///     latinNames (`List<String>`): Its Latin names, likewise.
///     terms (`List<String>`): The names a medicine's label could print it
///         by, in lower case: what the interaction checker looks for.
///     sections (`List<SupplementSection>`): The fact sheet, from its
///         background to "Keep in Mind".
///     updated (String): When NCCIH last updated it, as the page says:
///         "May 2025".
///     url (String): Where the page is.
@immutable
final class Supplement {
  /// Creates a herb.
  const Supplement({
    required this.key,
    required this.name,
    required this.commonNames,
    required this.latinNames,
    required this.terms,
    required this.sections,
    required this.updated,
    required this.url,
  });

  /// Read a herb from the reference.
  ///
  /// Args:
  ///     json (`Map<String, Object?>`): The herb, as the generator writes it.
  ///
  /// Returns:
  ///     Supplement: The herb.
  factory Supplement.fromJson(Map<String, Object?> json) => Supplement(
    key: json['key']! as String,
    name: json['name']! as String,
    commonNames: _strings(json['common_names']),
    latinNames: _strings(json['latin_names']),
    terms: _strings(json['match']),
    sections: List<SupplementSection>.unmodifiable(<SupplementSection>[
      for (final section in json['sections']! as List<Object?>)
        SupplementSection.fromJson(section),
    ]),
    updated: json['updated']! as String,
    url: json['url']! as String,
  );

  /// NCCIH's address for the page, and the herb's identity here.
  final String key;

  /// The page's title.
  final String name;

  /// Its common names, as the page lists them, notes and all: "uña de gato
  /// (not to be confused with cat's foot ...)".
  final List<String> commonNames;

  /// Its Latin names, as the page lists them.
  final List<String> latinNames;

  /// The names a medicine's label could print it by, in lower case, without
  /// the page's notes and abbreviations: "st. john's wort", "hypericum
  /// perforatum".
  final List<String> terms;

  /// The fact sheet, in the page's order.
  final List<SupplementSection> sections;

  /// When NCCIH last updated the page, in its words.
  final String updated;

  /// Where the page is. Shown, never opened: the app has no internet access
  /// (ADR-0004).
  final String url;

  /// The section on what is known about its safety, which every fact sheet
  /// has. Null only for a reference built wrong.
  SupplementSection? get safety {
    for (final section in sections) {
      if (section.heading == supplementSafetyHeading) return section;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is Supplement && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'Supplement($key)';
}

/// A herb a search found.
///
/// Attributes:
///     supplement (Supplement): The herb.
///     alias (String?): The name it was found by, when it was not its own:
///         "Klamath weed", for St. John's wort.
@immutable
final class SupplementMatch {
  /// Creates a match.
  const SupplementMatch(this.supplement, {this.alias});

  /// The herb.
  final Supplement supplement;

  /// The common or Latin name it was found by, when the search did not find
  /// its title.
  final String? alias;
}

/// Every herb in the reference, and the search over them.
///
/// Attributes:
///     herbs (`List<Supplement>`): The herbs, in A to Z order.
///     source (String): Whose fact sheets these are.
///     publicDomain (String): The pages' own statement that they are in the
///         public domain.
///     disclaimer (String): NCCIH's note that they are not medical advice.
///     fetched (String): When the pages were read, `YYYY-MM-DD`.
///     indexUrl (String): Where NCCIH lists them.
@immutable
final class SupplementReference {
  /// Creates a reference.
  const SupplementReference({
    required this.herbs,
    required this.source,
    required this.publicDomain,
    required this.disclaimer,
    required this.fetched,
    required this.indexUrl,
  });

  /// Read the reference the generator writes.
  ///
  /// Args:
  ///     source (String): The reference, as JSON.
  ///
  /// Returns:
  ///     SupplementReference: Every herb, in A to Z order by title.
  ///
  /// Throws:
  ///     FormatException: For a reference in a format this code does not
  ///         read.
  factory SupplementReference.decode(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    if (json['schema_version'] != supplementsSchemaVersion) {
      throw FormatException(
        'supplements schema ${json['schema_version']} is not '
        '$supplementsSchemaVersion',
      );
    }
    final herbs = <Supplement>[
      for (final herb in json['herbs']! as List<Object?>)
        Supplement.fromJson(herb! as Map<String, Object?>),
    ]..sort((a, b) => _fold(a.name).compareTo(_fold(b.name)));
    return SupplementReference(
      herbs: List<Supplement>.unmodifiable(herbs),
      source: json['source']! as String,
      publicDomain: json['public_domain']! as String,
      disclaimer: json['disclaimer']! as String,
      fetched: json['fetched']! as String,
      indexUrl: json['index_url']! as String,
    );
  }

  /// The herbs, in A to Z order by title.
  final List<Supplement> herbs;

  /// Whose fact sheets these are.
  final String source;

  /// The pages' own statement that they are in the public domain.
  final String publicDomain;

  /// NCCIH's note, printed on every page, that the pages are not medical
  /// advice.
  final String disclaimer;

  /// When the pages were read, `YYYY-MM-DD`.
  final String fetched;

  /// Where NCCIH lists them.
  final String indexUrl;

  /// The herb whose key is [key], or null.
  Supplement? byKey(String key) {
    for (final herb in herbs) {
      if (herb.key == key) return herb;
    }
    return null;
  }

  /// Find the herbs one of whose names has a word starting with [query].
  ///
  /// Best first: a herb whose title starts with the query, then one with a
  /// word of its title that does, then one with another name that starts
  /// with it, then one with a word of another name that does, each in A to
  /// Z order. Case, punctuation and apostrophes are ignored: "st johns"
  /// finds St. John's wort.
  ///
  /// Args:
  ///     query (String): What has been typed.
  ///
  /// Returns:
  ///     `List<SupplementMatch>`: The herbs found, best first. Empty for a
  ///     query with no letter or digit in it.
  List<SupplementMatch> search(String query) {
    final folded = _fold(query);
    if (folded.isEmpty) return const <SupplementMatch>[];
    final ranked = <(int, int, SupplementMatch)>[];
    for (final (i, herb) in herbs.indexed) {
      final title = _fold(herb.name);
      final inTitle = _rank(title, folded);
      if (inTitle != null) {
        ranked.add((inTitle, i, SupplementMatch(herb)));
        continue;
      }
      (int, String)? best;
      for (final name in <String>[...herb.commonNames, ...herb.latinNames]) {
        final rank = _rank(_fold(name), folded);
        if (rank != null && (best == null || rank < best.$1)) {
          best = (rank, name);
        }
      }
      if (best != null) {
        ranked.add((2 + best.$1, i, SupplementMatch(herb, alias: best.$2)));
      }
    }
    ranked.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    return <SupplementMatch>[for (final (_, _, match) in ranked) match];
  }
}

/// How well [query] matches [name]: 0 when it starts it, 1 when it starts
/// one of its later words, and null when it does neither.
int? _rank(String name, String query) {
  if (name.startsWith(query)) return 0;
  if (name.contains(' $query')) return 1;
  return null;
}

/// [text] as a search compares it: without apostrophes, so that "John's",
/// "John’s" and "Johns" are one word, and then folded as the medicines
/// search folds it.
String _fold(String text) =>
    foldForSearch(text.replaceAll(RegExp("['’‘]"), ''));

/// Read a list of strings from decoded JSON.
List<String> _strings(Object? value) => List<String>.unmodifiable(<String>[
  for (final item in value! as List<Object?>) item! as String,
]);
