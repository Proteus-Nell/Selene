/// Medicine reference model, and the search over it.
///
/// The shape of the medicines index the generator writes into
/// `app/assets/medicines`, and the search the lookup runs against it. Reading
/// the bundle off the assets is `medicine_bundle.dart`'s job; everything here
/// is pure, so it can run in a background isolate and in a plain test.
///
/// Includes:
///     - MedicineType: Prescription or over the counter.
///     - MedicineLabel: Which label stands for a drug.
///     - MedicineEntry: One drug, as the index describes it.
///     - MedicineSection: One section of a label, as published.
///     - MedicineMatch: A drug a search found, and the brand it was found by.
///     - MedicineSearch: What a search found.
///     - MedicineIndex: Every drug, and the search over them.
///     - MedicineBundleException: The bundle contradicts itself.
///     - foldForSearch: The form both a query and a name are compared in.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:period_tracker/core/date_utils.dart';

/// The bundle format this code reads. The generator's `BUNDLE_SCHEMA_VERSION`.
const int medicinesBundleSchemaVersion = 1;

/// Whether a drug needs a prescription in the US.
enum MedicineType {
  /// Prescription only. Its label is the professional one.
  prescription('rx'),

  /// Over the counter. Its label is the Drug Facts panel on the box.
  overTheCounter('otc');

  const MedicineType(this.wireName);

  /// How the bundle writes it.
  final String wireName;

  /// Return the type the bundle names.
  ///
  /// Args:
  ///     wireName (String): `rx` or `otc`.
  ///
  /// Returns:
  ///     MedicineType: The matching type.
  ///
  /// Throws:
  ///     MedicineBundleException: For anything else.
  static MedicineType fromWireName(String wireName) => switch (wireName) {
    'rx' => prescription,
    'otc' => overTheCounter,
    _ => throw MedicineBundleException('unknown type "$wireName"'),
  };
}

/// The one label that stands for a drug, out of every label filed for it.
///
/// Attributes:
///     setId (String): openFDA's identifier for the label across versions.
///     manufacturer (String): Who filed it.
///     effectiveTime (String): Its version date, as `YYYYMMDD`.
@immutable
final class MedicineLabel {
  /// Creates a label reference.
  ///
  /// Args:
  ///     setId (String): openFDA's identifier for the label.
  ///     manufacturer (String): Who filed it.
  ///     effectiveTime (String): Its version date, as `YYYYMMDD`.
  const MedicineLabel({
    required this.setId,
    required this.manufacturer,
    required this.effectiveTime,
  });

  /// openFDA's identifier for the label, the same across its versions.
  final String setId;

  /// Who filed the label.
  final String manufacturer;

  /// The label version's date, as `YYYYMMDD`.
  final String effectiveTime;

  /// The version date, or null when [effectiveTime] is not a real one.
  CivilDate? get effectiveDate {
    if (!RegExp(r'^\d{8}$').hasMatch(effectiveTime)) return null;
    final year = int.parse(effectiveTime.substring(0, 4));
    final month = int.parse(effectiveTime.substring(4, 6));
    final day = int.parse(effectiveTime.substring(6, 8));
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > CivilDate.daysInMonth(year, month)) return null;
    return CivilDate(year, month, day);
  }
}

/// One drug, as the index describes it.
///
/// A drug here is what it contains, how it is taken, and whether it needs a
/// prescription (ADR-0012), so one name can head several entries: ibuprofen
/// tablets over the counter, on prescription, and as an injection.
///
/// Attributes:
///     key (String): Stable identifier. Never shown.
///     name (String): The generic name, as the chosen label gives it.
///     brands (`List<String>`): Every brand name filed for the drug.
///     substances (`List<String>`): Its active substances.
///     routes (`List<String>`): How it is taken, in openFDA's words.
///     type (MedicineType): Prescription or over the counter.
///     labels (int): How many labels were filed for it.
///     chunk (int): Which text chunk holds its sections.
///     line (int): Which line of that chunk.
///     label (MedicineLabel): The label shown for it.
@immutable
final class MedicineEntry {
  /// Creates an entry.
  ///
  /// Args:
  ///     key (String): Stable identifier.
  ///     name (String): The generic name.
  ///     brands (`List<String>`): Brand names.
  ///     substances (`List<String>`): Active substances.
  ///     routes (`List<String>`): Routes, in openFDA's words.
  ///     type (MedicineType): Prescription or over the counter.
  ///     labels (int): How many labels were filed for it.
  ///     chunk (int): Which text chunk holds its sections.
  ///     line (int): Which line of that chunk.
  ///     label (MedicineLabel): The label shown for it.
  const MedicineEntry({
    required this.key,
    required this.name,
    required this.brands,
    required this.substances,
    required this.routes,
    required this.type,
    required this.labels,
    required this.chunk,
    required this.line,
    required this.label,
  });

  /// Read one row of the index.
  ///
  /// Args:
  ///     row (`Map<String, Object?>`): The row, as the generator writes it.
  ///
  /// Returns:
  ///     MedicineEntry: The entry.
  factory MedicineEntry.fromJson(Map<String, Object?> row) {
    final label = row['label']! as Map<String, Object?>;
    return MedicineEntry(
      key: row['key']! as String,
      name: row['name']! as String,
      brands: _strings(row['brands']),
      substances: _strings(row['substances']),
      routes: _strings(row['routes']),
      type: MedicineType.fromWireName(row['type']! as String),
      labels: row['labels']! as int,
      chunk: row['chunk']! as int,
      line: row['line']! as int,
      label: MedicineLabel(
        setId: label['set_id']! as String,
        manufacturer: label['manufacturer']! as String,
        effectiveTime: label['effective_time']! as String,
      ),
    );
  }

  /// Stable identifier. Never shown; used to find an entry from code.
  final String key;

  /// The generic name, as the chosen label gives it.
  final String name;

  /// Every brand name filed for this drug, in alphabetical order.
  final List<String> brands;

  /// The active substances.
  final List<String> substances;

  /// How it is taken, in openFDA's words. Empty for a few kits.
  final List<String> routes;

  /// Prescription or over the counter.
  final MedicineType type;

  /// How many labels were filed for this drug.
  final int labels;

  /// Which text chunk holds this drug's sections.
  final int chunk;

  /// Which line of that chunk.
  final int line;

  /// The label shown for this drug.
  final MedicineLabel label;

  @override
  bool operator ==(Object other) => other is MedicineEntry && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'MedicineEntry($key)';
}

/// One section of a label, as published.
///
/// Attributes:
///     name (String): openFDA's field name for it.
///     text (String): Its text, paragraphs separated by a blank line.
@immutable
final class MedicineSection {
  /// Creates a section.
  ///
  /// Args:
  ///     name (String): openFDA's field name for it.
  ///     text (String): Its text.
  const MedicineSection({required this.name, required this.text});

  /// Read a section from a drug's record.
  ///
  /// Args:
  ///     pair (Object?): The section, as `[name, text]`.
  ///
  /// Returns:
  ///     MedicineSection: The section.
  factory MedicineSection.fromJson(Object? pair) {
    final values = pair! as List<Object?>;
    return MedicineSection(
      name: values[0]! as String,
      text: values[1]! as String,
    );
  }

  /// openFDA's field name for the section, such as `boxed_warning`.
  final String name;

  /// The section's text. Nothing in it is reworded, reordered or cut.
  final String text;

  /// The text's paragraphs, in order.
  List<String> get paragraphs => text.split('\n\n');

  @override
  bool operator ==(Object other) =>
      other is MedicineSection && other.name == name && other.text == text;

  @override
  int get hashCode => Object.hash(name, text);
}

/// A drug a search found.
///
/// Attributes:
///     entry (MedicineEntry): The drug.
///     brand (String?): The brand name it was found by, when it was one.
@immutable
final class MedicineMatch {
  /// Creates a match.
  ///
  /// Args:
  ///     entry (MedicineEntry): The drug.
  ///     brand (String?): The brand name it was found by, if any.
  const MedicineMatch(this.entry, {this.brand});

  /// The drug.
  final MedicineEntry entry;

  /// The brand name the drug was found by, or null when it was found by its
  /// own name or a substance. Shown first, so the reader can see why a drug
  /// they did not type is in the list.
  final String? brand;
}

/// What a search found.
///
/// Attributes:
///     matches (`List<MedicineMatch>`): The best matches, best first.
///     total (int): How many drugs matched in all.
@immutable
final class MedicineSearch {
  /// Creates a result.
  ///
  /// Args:
  ///     matches (`List<MedicineMatch>`): The best matches, best first.
  ///     total (int): How many drugs matched in all.
  const MedicineSearch(this.matches, this.total);

  /// Nothing found.
  static const MedicineSearch none = MedicineSearch(<MedicineMatch>[], 0);

  /// The best matches, best first, up to the limit asked for.
  final List<MedicineMatch> matches;

  /// How many drugs matched in all, including those past the limit.
  final int total;
}

/// The bundle disagrees with itself, or with the code reading it.
///
/// Attributes:
///     message (String): What was wrong.
final class MedicineBundleException implements Exception {
  /// Creates the exception.
  ///
  /// Args:
  ///     message (String): What was wrong.
  const MedicineBundleException(this.message);

  /// What was wrong.
  final String message;

  @override
  String toString() => 'MedicineBundleException: $message';
}

/// Every drug in the reference, and the search over them.
///
/// Built once per visit to the lookup, in a background isolate: the index is
/// 3 MB of JSON. Every name a drug can be found by is folded up front into one
/// buffer, a line per name, so that a search is a single pass over 1.6 MB
/// rather than a string comparison per name.
///
/// Attributes:
///     entries (`List<MedicineEntry>`): Every drug, in key order.
///     exportDate (String): The date of the openFDA export.
///     jurisdiction (String): Where the labelling applies.
///     disclaimer (String): The notice openFDA asks to travel with the data.
///     chunkCount (int): How many text chunks the bundle has.
final class MedicineIndex {
  MedicineIndex._(
    this._text,
    this._starts,
    this._substancesAt,
    this._brandsAt, {
    required this.entries,
    required this.exportDate,
    required this.jurisdiction,
    required this.disclaimer,
    required this.chunkCount,
  });

  /// Build the index from its decoded JSON.
  ///
  /// Args:
  ///     json (`Map<String, Object?>`): The index, as the generator writes it.
  ///
  /// Returns:
  ///     MedicineIndex: The index, ready to search.
  ///
  /// Throws:
  ///     MedicineBundleException: When the index is of a schema this code
  ///         does not read.
  factory MedicineIndex.fromJson(Map<String, Object?> json) {
    final version = json['schema_version'];
    if (version != medicinesBundleSchemaVersion) {
      throw MedicineBundleException('schema_version $version is not read');
    }
    final entries = List<MedicineEntry>.unmodifiable(<MedicineEntry>[
      for (final row in json['entries']! as List<Object?>)
        MedicineEntry.fromJson(row! as Map<String, Object?>),
    ]);

    // Each drug is a newline, then its name, its substances and its brands,
    // each folded and each followed by a newline. A folded query holds no
    // newline, so no match can run from one name into the next, and a match
    // with a newline on both sides is a whole name.
    final text = BytesBuilder(copy: false);
    final starts = Int32List(entries.length + 1);
    final substancesAt = Int32List(entries.length);
    final brandsAt = Int32List(entries.length);
    void add(String name) {
      text
        ..add(utf8.encode(foldForSearch(name)))
        ..addByte(_newline);
    }

    for (final (i, entry) in entries.indexed) {
      starts[i] = text.length;
      text.addByte(_newline);
      add(entry.name);
      substancesAt[i] = text.length;
      entry.substances.forEach(add);
      brandsAt[i] = text.length;
      entry.brands.forEach(add);
    }
    starts[entries.length] = text.length;

    return MedicineIndex._(
      text.takeBytes(),
      starts,
      substancesAt,
      brandsAt,
      entries: entries,
      exportDate: json['export_date']! as String,
      jurisdiction: json['jurisdiction']! as String,
      disclaimer: json['disclaimer']! as String,
      chunkCount: json['chunks']! as int,
    );
  }

  /// Decompress, decode and build the index from the bundle's file.
  ///
  /// Args:
  ///     compressed (`List<int>`): The contents of `index.json.zlib`.
  factory MedicineIndex.decode(List<int> compressed) => MedicineIndex.fromJson(
    utf8.decoder.fuse(json.decoder).convert(zlib.decode(compressed))!
        as Map<String, Object?>,
  );

  /// Every drug, in key order.
  final List<MedicineEntry> entries;

  /// The date of the openFDA export, as `YYYY-MM-DD`.
  final String exportDate;

  /// Where the labelling applies.
  final String jurisdiction;

  /// The notice openFDA asks to travel with the data.
  final String disclaimer;

  /// How many text chunks the bundle has.
  final int chunkCount;

  /// Every drug's folded names, a line each, drug after drug.
  final Uint8List _text;

  /// Where each drug's names begin in [_text], and then where they end.
  final Int32List _starts;

  /// Where each drug's substances begin in [_text].
  final Int32List _substancesAt;

  /// Where each drug's brands begin in [_text].
  final Int32List _brandsAt;

  /// Find the drugs whose names, substances or brands match [query].
  ///
  /// A name matches when it:
  ///
  ///     0. Is the query: "advil" for "Advil".
  ///     1. Starts with it: "advil" for "Advil PM".
  ///     2. Has a word that starts with it: "pm" for "Advil PM".
  ///     3. Contains it, for a query of three characters or more. Any
  ///        shorter, and nearly every drug would.
  ///     4. Has, among all the drug's names, a word starting with each word
  ///        of the query: "levonorgestrel ethinyl". A word of one or two
  ///        characters has to match a whole word, or "b" would find
  ///        thousands.
  ///
  /// Names that are or start with the query come first. Within that, and
  /// within the rest, a drug's own name comes before a substance, and a
  /// substance before a brand: "zinc" lists zinc and zinc oxide before the
  /// thirty-ingredient multivitamins that contain zinc. Then by how close the
  /// match was, then by how many labels the drug had, which puts the form
  /// most widely sold first, then by the shortest name.
  ///
  /// Args:
  ///     query (String): What was typed. Case and punctuation are ignored.
  ///     limit (int): The most matches to return.
  ///
  /// Returns:
  ///     MedicineSearch: The best [limit] matches and how many there were.
  ///     Nothing for a query with no letters or digits in it.
  MedicineSearch search(String query, {int limit = 25}) {
    final folded = foldForSearch(query);
    if (folded.isEmpty) return MedicineSearch.none;

    final rank = Int32List(entries.length)..fillRange(0, entries.length, _no);
    final at = Int32List(entries.length);
    _scanWhole(Uint8List.fromList(utf8.encode(folded)), rank, at);
    // Each word is another pass over the text, so a pasted paragraph is cut
    // to its first few words rather than costing a pass for every one.
    final words = folded.split(' ').toSet().take(_maxWords).toList();
    if (words.length > 1) _scanWords(words, rank, at);

    final hits = <(int, int)>[
      for (var i = 0; i < entries.length; i++)
        if (rank[i] != _no) (rank[i], i),
    ]..sort(_compare);
    return MedicineSearch(<MedicineMatch>[
      for (final (rank, i) in hits.take(limit))
        MedicineMatch(
          entries[i],
          brand: _field(rank) == 2 ? _brandAt(i, at[i]) : null,
        ),
    ], hits.length);
  }

  /// Rank every drug by its best match for the query as a whole: tiers 0 to
  /// 3 of [search].
  void _scanWhole(Uint8List query, Int32List rank, Int32List at) {
    final anywhere = query.length >= 3;
    _scan(query, wordStartsOnly: !anywhere, (entry, start, before, after) {
      final int tier;
      if (before == _newline) {
        tier = after == _newline ? 0 : 1;
      } else if (before == _space) {
        tier = 2;
      } else {
        tier = 3;
      }
      final score = _score(tier, _fieldOf(entry, start));
      if (score < rank[entry]) {
        rank[entry] = score;
        at[entry] = start;
      }
    });
  }

  /// Rank, at tier 4 of [search], every drug not already ranked that has a
  /// word starting with each of [words].
  ///
  /// The longest word is looked for first, across every drug. It is usually
  /// the rarest, and the others are then looked for only in the drugs it was
  /// found in.
  void _scanWords(List<String> words, Int32List rank, Int32List at) {
    final ordered = <String>[...words]
      ..sort((a, b) => b.length.compareTo(a.length));
    final position = Int32List(entries.length);
    var found = <int>[];
    for (final (w, word) in ordered.indexed) {
      final query = Uint8List.fromList(utf8.encode(word));
      final whole = word.length < 3;
      bool counts(int before, int after) =>
          !whole || after == _newline || after == _space;
      if (w == 0) {
        _scan(query, wordStartsOnly: true, (entry, start, before, after) {
          // A drug's matches come one after another, so a repeat is the last.
          if (!counts(before, after) || found.lastOrNull == entry) return;
          found.add(entry);
          position[entry] = start;
        });
        continue;
      }
      final still = <int>[];
      for (final entry in found) {
        var matched = false;
        _scan(
          query,
          wordStartsOnly: true,
          from: _starts[entry] + 1,
          to: _starts[entry + 1],
          entry: entry,
          (_, _, before, after) => matched = matched || counts(before, after),
        );
        if (matched) still.add(entry);
      }
      found = still;
    }
    for (final entry in found) {
      if (rank[entry] != _no) continue;
      rank[entry] = _score(4, _fieldOf(entry, position[entry]));
      at[entry] = position[entry];
    }
  }

  /// Call [onMatch] for every place [query] occurs in [_text], in order.
  ///
  /// One pass over the bytes, with no allocation per match. String.indexOf
  /// over the same text took three times as long.
  ///
  /// Args:
  ///     query (Uint8List): The folded query, as UTF-8.
  ///     onMatch (Function): Given the drug, where the match starts, and the
  ///         bytes either side of it.
  ///     wordStartsOnly (bool): Skip matches that do not start a name or a
  ///         word, without calling [onMatch] for them.
  ///     from (int): Where to start. Never 0: the text's first byte is a
  ///         newline, which no query starts with.
  ///     to (int?): Where to stop, or the end of the text.
  ///     entry (int): The drug [from] falls in.
  void _scan(
    Uint8List query,
    void Function(int entry, int start, int before, int after) onMatch, {
    required bool wordStartsOnly,
    int from = 1,
    int? to,
    int entry = 0,
  }) {
    final text = _text;
    final starts = _starts;
    final head = query[0];
    final last = (to ?? text.length) - query.length;
    var current = entry;
    outer:
    for (var i = from; i <= last; i++) {
      if (text[i] != head) continue;
      final before = text[i - 1];
      if (wordStartsOnly && before != _newline && before != _space) continue;
      for (var k = 1; k < query.length; k++) {
        if (text[i + k] != query[k]) continue outer;
      }
      while (starts[current + 1] <= i) {
        current++;
      }
      onMatch(current, i, before, text[i + query.length]);
    }
  }

  /// Order two ranked drugs, better first.
  int _compare((int, int) a, (int, int) b) {
    var order = a.$1.compareTo(b.$1);
    if (order != 0) return order;
    final first = entries[a.$2];
    final second = entries[b.$2];
    order = second.labels.compareTo(first.labels);
    if (order != 0) return order;
    order = first.name.length.compareTo(second.name.length);
    if (order != 0) return order;
    order = first.name.compareTo(second.name);
    if (order != 0) return order;
    return first.key.compareTo(second.key);
  }

  /// Which kind of name a position falls in: 0 for the drug's own, 1 for a
  /// substance, 2 for a brand.
  int _fieldOf(int entry, int position) {
    if (position < _substancesAt[entry]) return 0;
    if (position < _brandsAt[entry]) return 1;
    return 2;
  }

  /// The brand a drug was found by, from where in [_text] it matched.
  String _brandAt(int entry, int position) {
    var brand = 0;
    for (var i = _brandsAt[entry]; i < position; i++) {
      if (_text[i] == _newline) brand++;
    }
    return entries[entry].brands[brand];
  }

  /// A drug's rank, lower first, from its tier and which kind of name
  /// matched. Tiers 0 and 1 lead whichever kind of name it was.
  static int _score(int tier, int field) =>
      (tier <= 1 ? 0 : 100) + field * 10 + tier;

  /// Which kind of name a rank came from.
  static int _field(int score) => (score % 100) ~/ 10;

  /// The rank of a drug that did not match.
  static const int _no = 1 << 30;

  /// The most words of a query matched one by one, at tier 4.
  static const int _maxWords = 6;

  static const int _newline = 0x0A;
  static const int _space = 0x20;
}

/// Return [text] in the form searches compare: lower case, every run of
/// anything but letters and digits made one space, and the word "and" taken
/// out.
///
/// "Advil PM", "ADVIL-PM" and "advil pm" all fold to "advil pm", so neither
/// the reader nor the label has to get case or punctuation right. Labels name
/// one combination "X AND Y", "X/Y" and "X, Y", so "and" is folded out with
/// the slash and the comma, and all three read "x y".
///
/// Args:
///     text (String): A name or a query.
///
/// Returns:
///     String: The folded text, with no space at either end.
String foldForSearch(String text) {
  final folded = StringBuffer();
  final word = StringBuffer();
  void endWord() {
    if (word.isEmpty) return;
    final done = word.toString();
    word.clear();
    if (done == 'and') return;
    if (folded.isNotEmpty) folded.writeCharCode(0x20);
    folded.write(done);
  }

  for (final unit in text.toLowerCase().codeUnits) {
    final keep =
        (unit >= 0x61 && unit <= 0x7A) ||
        (unit >= 0x30 && unit <= 0x39) ||
        unit > 0x7F;
    if (keep) {
      word.writeCharCode(unit);
    } else {
      endWord();
    }
  }
  endWord();
  return folded.toString();
}

/// Read a list of strings from decoded JSON.
List<String> _strings(Object? value) => List<String>.unmodifiable(<String>[
  for (final item in value! as List<Object?>) item! as String,
]);
