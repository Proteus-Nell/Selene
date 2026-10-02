/// Medicine picker.
///
/// Finds one medicine in the bundled reference and hands it back, for a list
/// that is being built: the interaction checker's, or the medicines recorded
/// under Conditions and medication. The same search as Look something up, and
/// as there, nothing typed leaves the phone (ADR-0004).
///
/// Includes:
///     - pickMedicine: Opens the picker, and returns what was picked.
///     - MedicinePickerScreen: The search, and the results to pick from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/features/lookup/medicine_browse.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Open the picker over [context], and return the medicine picked.
///
/// Args:
///     context (BuildContext): What to open the picker over.
///
/// Returns:
///     `Future<MedicineEntry?>`: The medicine, or null when the reader went
///     back without picking one.
Future<MedicineEntry?> pickMedicine(BuildContext context) =>
    Navigator.of(context).push<MedicineEntry>(
      MaterialPageRoute<MedicineEntry>(
        builder: (context) => const MedicinePickerScreen(),
      ),
    );

/// Picker screen: a search box over every medicine, and the closest matches.
///
/// Tapping a match picks it and closes the screen. The closest 25 are listed,
/// as in the lookup; typing more of the name is how to reach the rest.
class MedicinePickerScreen extends ConsumerStatefulWidget {
  /// Creates the picker.
  const MedicinePickerScreen({super.key});

  @override
  ConsumerState<MedicinePickerScreen> createState() =>
      _MedicinePickerScreenState();
}

/// State for [MedicinePickerScreen]: what has been typed.
///
/// Attributes:
///     _query (TextEditingController): What has been typed so far.
class _MedicinePickerScreenState extends ConsumerState<MedicinePickerScreen> {
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
    final index = ref.watch(medicineIndexProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkerAdd)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.lookupSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ...index.when(
              data: (reference) {
                if (query.isEmpty) {
                  return <Widget>[
                    Text(
                      l10n.checkerPickerPrompt,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ];
                }
                final found = reference.search(query);
                if (found.total == 0) {
                  return <Widget>[
                    Text(
                      l10n.lookupNoResults,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ];
                }
                return <Widget>[
                  for (final match in found.matches)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MedicineTile(
                        entry: match.entry,
                        brand: match.brand,
                        onPicked: (entry) => Navigator.of(context).pop(entry),
                      ),
                    ),
                  if (found.total > found.matches.length)
                    Text(
                      l10n.lookupMedicinesShowing(
                        found.matches.length,
                        found.total,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                ];
              },
              error: (error, stack) => <Widget>[
                Text(
                  l10n.lookupMedicinesFailed,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              loading: () => <Widget>[
                LinearProgressIndicator(
                  semanticsLabel: l10n.lookupMedicinesLoading,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
