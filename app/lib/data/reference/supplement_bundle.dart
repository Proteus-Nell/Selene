/// Herbal supplements reader.
///
/// Reads NCCIH's fact sheets out of the app's own assets, where
/// `tools/scripts/gen_supplements.py` put them. The phone makes no request for
/// any of them (ADR-0004, ADR-0023).
///
/// Includes:
///     - supplementsAsset: Where the reference sits among the assets.
///     - loadSupplements: Reads and decodes it.
///     - supplementAssetsProvider: The asset bundle it is read from.
///     - supplementsProvider: Every herb, once loaded.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/reference/supplement.dart';

/// Where the reference sits among the assets.
const String supplementsAsset = 'assets/supplements/nccih_herbs.json';

/// Read the herbal supplements reference out of [assets].
///
/// Decoded where it is called: the file is a quarter of a megabyte, against
/// the medicines index's several, and a widget test's fake clock never sees
/// a background isolate finish.
///
/// Args:
///     assets (AssetBundle): Where the file is read from.
///
/// Returns:
///     `Future<SupplementReference>`: Every herb.
///
/// Throws:
///     FormatException: For a reference in a format this code does not read.
Future<SupplementReference> loadSupplements(AssetBundle assets) async {
  final data = await assets.load(supplementsAsset);
  return SupplementReference.decode(utf8.decode(Uint8List.sublistView(data)));
}

/// The asset bundle the reference is read from. Overridden in widget tests
/// with herbs written out in the test.
final Provider<AssetBundle> supplementAssetsProvider = Provider<AssetBundle>(
  (ref) => rootBundle,
);

/// Every herb in the reference, loaded when a screen first asks for it and
/// dropped once no screen does.
final AutoDisposeFutureProvider<SupplementReference> supplementsProvider =
    FutureProvider.autoDispose<SupplementReference>(
      (ref) => loadSupplements(ref.watch(supplementAssetsProvider)),
    );
