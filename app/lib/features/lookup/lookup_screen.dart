/// Lookup screen.
///
/// Searches the reference the app carries with it, and offers a way out to a
/// browser when the answer is not here. Nothing typed into the box leaves the
/// phone: the app has no `INTERNET` permission at all (ADR-0004).
///
/// Includes:
///     - LookupScreen: The screen itself.
///     - _LookupScreenState: The query, the matching, and the hand-off.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/features/common/snack.dart';
import 'package:period_tracker/features/lookup/browser_handoff.dart';
import 'package:period_tracker/features/lookup/medicine_browse.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Lookup screen: look something up, with somewhere to go if it is not here.
///
/// Everything on this screen is stored on the device (AND-32). **Nothing typed
/// into the search box leaves the phone.** The app has no `INTERNET`
/// permission at all (ADR-0004), and the subtitle says so, because a user
/// typing a drug name into a search field has every reason to assume
/// otherwise.
///
/// The medicines are every drug in openFDA's label export, several thousand of
/// them (ADR-0012), so they are searched, or browsed a letter at a time, and
/// each opens onto its own page.
class LookupScreen extends ConsumerStatefulWidget {
  /// Creates the lookup screen.
  const LookupScreen({super.key});

  @override
  ConsumerState<LookupScreen> createState() => _LookupScreenState();
}

/// State for [LookupScreen]: the query, and what currently matches it.
///
/// The search is a pass over every drug's names, so its last result is kept,
/// and a rebuild that changes neither the query nor the page reuses it.
///
/// Attributes:
///     _query (TextEditingController): What has been typed so far.
///     _shown (int): How many medicines to list.
///     _last (record?): The last search, and what it was run for.
class _LookupScreenState extends ConsumerState<LookupScreen> {
  /// How many more medicines each "Show more" lists.
  static const int _page = 25;

  /// What has been typed so far.
  final TextEditingController _query = TextEditingController();

  /// How many medicines to list. Back to one page whenever the query changes.
  int _shown = _page;

  /// The last search: the index and query and page size it ran for, and what
  /// it found.
  (MedicineIndex, String, int, MedicineSearch)? _last;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Search the medicines, or return the last search if nothing changed.
  ///
  /// Args:
  ///     index (MedicineIndex): Every drug.
  ///     query (String): What has been typed, trimmed and not empty.
  ///
  /// Returns:
  ///     MedicineSearch: The best [_shown] matches, and how many there were.
  MedicineSearch _medicines(MedicineIndex index, String query) {
    final last = _last;
    if (last != null &&
        identical(last.$1, index) &&
        last.$2 == query &&
        last.$3 == _shown) {
      return last.$4;
    }
    final found = index.search(query, limit: _shown);
    _last = (index, query, _shown, found);
    return found;
  }

  /// Hand the query off to a browser, after confirming.
  ///
  /// The confirmation is [BrowserHandoff.confirmAndOpen]'s, not this screen's:
  /// leaving the app is the one action here that reaches the network, and the
  /// user is told before it happens rather than after.
  ///
  /// Returns:
  ///     `Future<void>`: Completes once the browser has opened, or once the
  ///     failure has been reported. A user who declined the confirmation gets
  ///     neither.
  Future<void> _handOff() async {
    final opened = await BrowserHandoff.confirmAndOpen(
      context,
      term: _query.text.trim().isEmpty ? null : _query.text.trim(),
    );
    if (!mounted || opened) return;
    // Only reported when the user asked for it and it did not happen. A device
    // with no browser is unusual but not impossible, and silence there looks
    // like a dead button.
    showAppSnackBar(context, AppLocalizations.of(context).lookupLeavingFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = _query.text.trim();
    // Not watched at all when no bundle was built: there is nothing to load,
    // and the screen says so instead.
    final index = medicinesFetched ? ref.watch(medicineIndexProvider) : null;
    final loaded = index?.valueOrNull;
    final medicines = loaded == null || query.isEmpty
        ? MedicineSearch.none
        : _medicines(loaded, query);
    final nothingMatched =
        query.isNotEmpty && loaded != null && medicines.total == 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lookupTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Text(l10n.lookupSubtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              onChanged: (_) => setState(() => _shown = _page),
              decoration: InputDecoration(
                labelText: l10n.lookupSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              l10n.lookupMedicinesHeading,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            if (!medicinesFetched)
              // Said plainly rather than rendered as an empty list, which reads
              // as a broken screen. See gen_medicines.py.
              Text(
                l10n.lookupMedicinesUnavailable,
                style: theme.textTheme.bodyMedium,
              )
            else ...<Widget>[
              Text(
                l10n.lookupMedicinesSource(medicinesSnapshotDate ?? ''),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              // Always, not only when a US user is detected. The app has no
              // way to detect anything. A reader applying US warnings to a box
              // bought elsewhere is being quietly misinformed.
              Text(
                l10n.lookupMedicinesUsOnly,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ...index!.when(
                data: (reference) => query.isEmpty
                    // Asked for, not listed: several thousand medicines
                    // unasked would be a list nobody reads.
                    ? <Widget>[
                        Text(
                          l10n.lookupMedicinesPrompt(reference.entries.length),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.lookupBrowseHeading,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        MedicineLetters(index: reference),
                      ]
                    : <Widget>[
                        for (final match in medicines.matches)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: MedicineTile(
                              entry: match.entry,
                              brand: match.brand,
                            ),
                          ),
                        if (medicines.total >
                            medicines.matches.length) ...<Widget>[
                          Text(
                            l10n.lookupMedicinesShowing(
                              medicines.matches.length,
                              medicines.total,
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                          TextButton(
                            onPressed: () => setState(() => _shown += _page),
                            child: Text(l10n.lookupMedicinesShowMore),
                          ),
                        ],
                      ],
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

            if (nothingMatched) ...<Widget>[
              const SizedBox(height: 8),
              Text(l10n.lookupNoResults, style: theme.textTheme.bodyMedium),
            ],

            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.lookupSearchOnlineTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.lookupSearchOnlineBody),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _handOff,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.lookupSearchOnlineAction),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(medicinesDisclaimer, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
