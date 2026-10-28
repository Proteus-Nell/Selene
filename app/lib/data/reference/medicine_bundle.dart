/// Medicines bundle reader.
///
/// Reads the medicines reference out of the app's own assets, where
/// `tools/scripts/gen_medicines.py` put it: a compressed index of every drug,
/// and the label text in compressed chunks of about a megabyte. The phone
/// makes no request for any of it (ADR-0004, ADR-0012).
///
/// Includes:
///     - MedicineRunner: Where decompression and decoding run.
///     - MedicineBundle: Loads the index, one drug's sections, and what
///       several drugs' labels, and herbs' fact sheets, say about each other.
///     - medicineBundleProvider: The bundle, read from the app's assets.
///     - medicineIndexProvider: Every drug, once loaded.
///     - medicineSectionsProvider: One drug's label sections.
///     - medicineGuideProvider: The safety sections of its Medication Guide.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/reference/interactions.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_groups.dart';
import 'package:period_tracker/data/reference/supplement.dart';

/// Runs a task and returns its result: in a background isolate in the app,
/// and in place in a widget test, whose fake clock never sees an isolate
/// finish.
typedef MedicineRunner = Future<T> Function<T>(FutureOr<T> Function() task);

/// Reads the medicines reference out of an asset bundle.
///
/// The index loads once per visit to the lookup. A drug's sections load when
/// it is opened, from the one chunk that holds them, and the last chunk opened
/// is kept: drugs next to each other in the A-Z share one, and the next drug
/// opened is often a neighbour.
///
/// Attributes:
///     directory (String): Where the bundle sits among the assets.
class MedicineBundle {
  /// Creates a reader.
  ///
  /// Args:
  ///     assets (AssetBundle): Where the files are read from.
  ///     run (MedicineRunner): Where decompression and decoding run. A
  ///         background isolate by default, so a 3 MB index never stalls a
  ///         frame.
  ///     directory (String): Where the bundle sits among the assets.
  ///     groups (MedicineGroups?): The group names matched on labels.
  ///         Defaults to the table the app ships (ADR-0021).
  MedicineBundle(
    this._assets, {
    MedicineRunner run = Isolate.run,
    this.directory = 'assets/medicines',
    MedicineGroups? groups,
  }) : _runner = run,
       groups = groups ?? MedicineGroups.bundled;

  /// Where the files are read from.
  final AssetBundle _assets;

  /// Where decompression and decoding run.
  final MedicineRunner _runner;

  /// Where the bundle sits among the assets.
  final String directory;

  /// The group names matched on labels.
  final MedicineGroups groups;

  /// The number of the chunk last opened, and the chunk.
  (int, Future<_Chunk>)? _last;

  /// Load and build the index.
  ///
  /// Returns:
  ///     `Future<MedicineIndex>`: Every drug, ready to search.
  Future<MedicineIndex> index() async {
    final bytes = await _bytes('$directory/index.json.zlib');
    return _decodeIndex(_runner, bytes);
  }

  /// Load one drug's label sections.
  ///
  /// Args:
  ///     entry (MedicineEntry): The drug, as the index describes it.
  ///
  /// Returns:
  ///     `Future<List<MedicineSection>>`: Its sections, in the order the
  ///     label is read.
  ///
  /// Throws:
  ///     MedicineBundleException: When the line the index points at belongs
  ///         to another drug. The index and the chunks came from different
  ///         builds, and showing the text anyway would show another drug's
  ///         warnings under this one's name.
  Future<List<MedicineSection>> sections(MedicineEntry entry) async {
    final record = await _record(entry);
    return List<MedicineSection>.unmodifiable(<MedicineSection>[
      for (final pair in record['sections']! as List<Object?>)
        MedicineSection.fromJson(pair),
    ]);
  }

  /// Load the safety sections of one drug's Medication Guide.
  ///
  /// From the same label as [sections], and the same line of the bundle.
  ///
  /// Args:
  ///     entry (MedicineEntry): The drug, as the index describes it.
  ///
  /// Returns:
  ///     `Future<List<GuideSection>>`: The guide's safety sections, in its
  ///     order. Empty for a drug with no guide, or one whose guide could not
  ///     be carried without its dosing (ADR-0022).
  ///
  /// Throws:
  ///     MedicineBundleException: As [sections] does.
  Future<List<GuideSection>> guide(MedicineEntry entry) async {
    final record = await _record(entry);
    return List<GuideSection>.unmodifiable(<GuideSection>[
      for (final pair in record['guide'] as List<Object?>? ?? const <Object?>[])
        GuideSection.fromJson(pair),
    ]);
  }

  /// Read the line the index points [entry] at, and check it is its own.
  Future<Map<String, Object?>> _record(MedicineEntry entry) async {
    final chunk = await _chunk(entry.chunk);
    if (entry.line >= chunk.lineCount) {
      throw MedicineBundleException(
        '${entry.key} points past the end of chunk ${entry.chunk}',
      );
    }
    final record =
        utf8.decoder.fuse(json.decoder).convert(chunk.line(entry.line))!
            as Map<String, Object?>;
    if (record['key'] != entry.key) {
      throw MedicineBundleException(
        '${entry.key} points at the text of ${record['key']}',
      );
    }
    return record;
  }

  /// Compare what several drugs' labels say about each other.
  ///
  /// Each label is read in turn, and the comparing runs where decoding does,
  /// off the UI thread: a pair is a few regular expressions over two labels,
  /// and a list of eight medicines is twenty-eight pairs.
  ///
  /// Args:
  ///     medicines (`List<MedicineEntry>`): The drugs, in the order they were
  ///         added.
  ///
  /// Returns:
  ///     `Future<List<InteractionPair>>`: One per pair, as
  ///     [checkInteractions] orders them.
  ///
  /// Throws:
  ///     MedicineBundleException: When a drug's line holds another drug's
  ///         text, as [sections] does.
  Future<List<InteractionPair>> interactions(
    List<MedicineEntry> medicines,
  ) async {
    final labels = <String, List<MedicineSection>>{
      for (final medicine in medicines) medicine.key: await sections(medicine),
    };
    return _check(_runner, medicines, labels, groups);
  }

  /// Compare recorded kinds of contraception with several drugs' labels.
  ///
  /// As [interactions], for [checkConditions]: each kind counts as what its
  /// products share, and a kind one of the drugs is a product of is left out.
  ///
  /// Args:
  ///     conditions (`List<ConditionKind>`): The kinds recorded.
  ///     medicines (`List<MedicineEntry>`): The drugs, in the order added.
  ///
  /// Returns:
  ///     `Future<List<ConditionPair>>`: One per kind and drug.
  ///
  /// Throws:
  ///     MedicineBundleException: When a drug's line holds another drug's
  ///         text, as [sections] does.
  Future<List<ConditionPair>> conditions(
    List<ConditionKind> conditions,
    List<MedicineEntry> medicines,
  ) async {
    if (conditions.isEmpty || medicines.isEmpty) return <ConditionPair>[];
    final labels = <String, List<MedicineSection>>{
      for (final medicine in medicines) medicine.key: await sections(medicine),
    };
    return _checkConditions(_runner, conditions, medicines, labels, groups);
  }

  /// Compare herbs' fact sheets with several drugs' labels.
  ///
  /// As [interactions], for [checkSupplements]: each herb with each drug, and
  /// no herb with another.
  ///
  /// Args:
  ///     supplements (`List<Supplement>`): The herbs, in the order added.
  ///     medicines (`List<MedicineEntry>`): The drugs, in the order added.
  ///
  /// Returns:
  ///     `Future<List<SupplementPair>>`: One per herb and drug.
  ///
  /// Throws:
  ///     MedicineBundleException: When a drug's line holds another drug's
  ///         text, as [sections] does.
  Future<List<SupplementPair>> supplements(
    List<Supplement> supplements,
    List<MedicineEntry> medicines,
  ) async {
    if (supplements.isEmpty || medicines.isEmpty) return <SupplementPair>[];
    final labels = <String, List<MedicineSection>>{
      for (final medicine in medicines) medicine.key: await sections(medicine),
    };
    return _checkSupplements(_runner, supplements, medicines, labels, groups);
  }

  /// Return chunk [number], decompressed, from the cache when it was the last
  /// one opened.
  Future<_Chunk> _chunk(int number) {
    final last = _last;
    if (last != null && last.$1 == number) return last.$2;
    final loading = _loadChunk(number);
    _last = (number, loading);
    // A chunk that failed to load is not kept, so the next attempt reads it
    // again rather than repeating the failure.
    unawaited(
      loading.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_last?.$2, loading)) _last = null;
        },
      ),
    );
    return loading;
  }

  /// Read and decompress chunk [number].
  Future<_Chunk> _loadChunk(int number) async {
    final name = 'labels-${number.toString().padLeft(3, '0')}.jsonl.zlib';
    final bytes = await _bytes('$directory/$name');
    return _decodeChunk(_runner, bytes);
  }

  /// Read an asset's bytes.
  Future<Uint8List> _bytes(String key) async =>
      Uint8List.sublistView(await _assets.load(key));

  // Static, so the closures sent to another isolate capture the bytes and
  // nothing else. A closure made inside an instance method can carry `this`,
  // and with it an AssetBundle, which cannot be sent.

  /// Build the index from its compressed bytes, through [run].
  static Future<MedicineIndex> _decodeIndex(
    MedicineRunner run,
    Uint8List bytes,
  ) => run(() => MedicineIndex.decode(bytes));

  /// Decompress a chunk and find its lines, through [run].
  static Future<_Chunk> _decodeChunk(MedicineRunner run, Uint8List bytes) =>
      run(() => _Chunk.decode(bytes));

  /// Compare every pair of [medicines], through [run].
  static Future<List<InteractionPair>> _check(
    MedicineRunner run,
    List<MedicineEntry> medicines,
    Map<String, List<MedicineSection>> labels,
    MedicineGroups groups,
  ) => run(() => checkInteractions(medicines, labels, groups: groups));

  /// Compare every kind in [conditions] with every one of [medicines],
  /// through [run].
  static Future<List<ConditionPair>> _checkConditions(
    MedicineRunner run,
    List<ConditionKind> conditions,
    List<MedicineEntry> medicines,
    Map<String, List<MedicineSection>> labels,
    MedicineGroups groups,
  ) => run(
    () => checkConditions(conditions, medicines, labels, groups: groups),
  );

  /// Compare every herb in [supplements] with every one of [medicines],
  /// through [run].
  static Future<List<SupplementPair>> _checkSupplements(
    MedicineRunner run,
    List<Supplement> supplements,
    List<MedicineEntry> medicines,
    Map<String, List<MedicineSection>> labels,
    MedicineGroups groups,
  ) => run(
    () => checkSupplements(supplements, medicines, labels, groups: groups),
  );
}

/// One decompressed chunk of label text, and where each of its lines starts.
final class _Chunk {
  _Chunk(this._bytes, this._starts);

  /// Decompress a chunk and find its lines.
  ///
  /// UTF-8 never puts a newline byte inside a character, and JSON escapes the
  /// newlines inside its strings, so every newline byte ends a record.
  factory _Chunk.decode(Uint8List compressed) {
    final decoded = zlib.decode(compressed);
    final bytes = decoded is Uint8List ? decoded : Uint8List.fromList(decoded);
    final starts = <int>[0];
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0x0A) starts.add(i + 1);
    }
    // One past the end, as though a last newline followed the last record.
    starts.add(bytes.length + 1);
    return _Chunk(bytes, Int32List.fromList(starts));
  }

  /// The decompressed text.
  final Uint8List _bytes;

  /// Where each line starts, and then one past the end.
  final Int32List _starts;

  /// How many lines the chunk holds.
  int get lineCount => _starts.length - 1;

  /// The bytes of line [number], without its newline.
  Uint8List line(int number) =>
      Uint8List.sublistView(_bytes, _starts[number], _starts[number + 1] - 1);
}

/// The medicines bundle, read from the app's own assets.
///
/// Overridden in widget tests with a bundle that decodes in place.
final AutoDisposeProvider<MedicineBundle> medicineBundleProvider =
    Provider.autoDispose<MedicineBundle>((ref) => MedicineBundle(rootBundle));

/// Every drug in the reference, loaded when a screen first asks for it and
/// dropped once no screen does. It is several megabytes once decoded.
final AutoDisposeFutureProvider<MedicineIndex> medicineIndexProvider =
    FutureProvider.autoDispose<MedicineIndex>(
      (ref) => ref.watch(medicineBundleProvider).index(),
    );

/// One drug's label sections.
final AutoDisposeFutureProviderFamily<List<MedicineSection>, MedicineEntry>
medicineSectionsProvider = FutureProvider.autoDispose
    .family<List<MedicineSection>, MedicineEntry>(
      (ref, entry) => ref.watch(medicineBundleProvider).sections(entry),
    );

/// The safety sections of one drug's Medication Guide, empty where it has
/// none (ADR-0022).
final AutoDisposeFutureProviderFamily<List<GuideSection>, MedicineEntry>
medicineGuideProvider = FutureProvider.autoDispose
    .family<List<GuideSection>, MedicineEntry>(
      (ref, entry) => ref.watch(medicineBundleProvider).guide(entry),
    );
