/// Herbal supplement picker.
///
/// Finds one herb in NCCIH's fact sheets and hands it back, for the
/// interaction checker's list (ADR-0023). As with the medicine picker,
/// nothing typed leaves the phone (ADR-0004).
///
/// Includes:
///     - pickSupplement: Opens the picker, and returns what was picked.
///     - SupplementPickerScreen: The herbs, A to Z, and a search over them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/reference/supplement.dart';
import 'package:period_tracker/data/reference/supplement_bundle.dart';
import 'package:period_tracker/features/lookup/supplement_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Open the picker over [context], and return the herb picked.
///
/// Args:
///     context (BuildContext): What to open the picker over.
///
/// Returns:
///     `Future<Supplement?>`: The herb, or null when the reader went back
///     without picking one.
Future<Supplement?> pickSupplement(BuildContext context) =>
    Navigator.of(context).push<Supplement>(
      MaterialPageRoute<Supplement>(
        builder: (context) => const SupplementPickerScreen(),
      ),
    );

/// Picker screen: every herb, narrowed by what is typed.
///
/// Every herb is listed before anything is typed: there are a few dozen,
/// not several thousand as there are medicines. Tapping one picks it and
/// closes the screen.
class SupplementPickerScreen extends ConsumerStatefulWidget {
  /// Creates the picker.
  const SupplementPickerScreen({super.key});

  @override
  ConsumerState<SupplementPickerScreen> createState() =>
      _SupplementPickerScreenState();
}

/// State for [SupplementPickerScreen]: what has been typed.
///
/// Attributes:
///     _query (TextEditingController): What has been typed so far.
class _SupplementPickerScreenState
    extends ConsumerState<SupplementPickerScreen> {
  /// What has been typed so far.
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = _query.text.trim();
    final reference = ref.watch(supplementsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkerAddSupplement)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.lookupSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ...reference.when(
              data: (reference) {
                final found = query.isEmpty
                    ? <SupplementMatch>[
                        for (final herb in reference.herbs)
                          SupplementMatch(herb),
                      ]
                    : reference.search(query);
                if (found.isEmpty) {
                  return <Widget>[
                    Text(
                      l10n.lookupNoResults,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ];
                }
                return <Widget>[
                  for (final match in found)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SupplementTile(
                        supplement: match.supplement,
                        alias: match.alias,
                        onPicked: (herb) => Navigator.of(context).pop(herb),
                      ),
                    ),
                ];
              },
              error: (error, stack) => <Widget>[
                Text(l10n.supplementsFailed, style: theme.textTheme.bodyMedium),
              ],
              loading: () => <Widget>[
                LinearProgressIndicator(
                  semanticsLabel: l10n.supplementsLoading,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
