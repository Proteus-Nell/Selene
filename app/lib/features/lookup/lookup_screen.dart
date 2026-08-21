import 'package:flutter/material.dart';
import 'package:period_tracker/data/reference/hygiene.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/features/common/snack.dart';
import 'package:period_tracker/features/lookup/browser_handoff.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Look something up, and have somewhere to go when it is not here (AND-32).
///
/// Everything on this screen is stored on the device. **Nothing typed into the
/// search box leaves the phone** — the app has no `INTERNET` permission at all
/// (ADR-0004), and the subtitle says so, because a user typing a drug name into
/// a search field has every reason to assume otherwise.
///
/// Two sections with different provenance, and the screen keeps them apart:
/// the medicines are a dated snapshot of a regulator's own text, and the
/// hygiene entries are hand-written for this app. Presenting curated wording as
/// though it came from a regulator would be borrowing an authority we do not
/// have (ADR-0009).
class LookupScreen extends StatefulWidget {
  /// Creates the lookup screen.
  const LookupScreen({super.key});

  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Whether [terms] matches the current query.
  ///
  /// Substring rather than prefix, and over every search term rather than the
  /// title alone: somebody looking for TSS will type "tss", and somebody
  /// frightened by a fever will type "fever". A search that only matches
  /// titles fails the person in the most hurry.
  bool _matches(Iterable<String> terms) {
    final needle = _query.text.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return terms.any((term) => term.toLowerCase().contains(needle));
  }

  List<HygieneEntry> get _hygiene => <HygieneEntry>[
    for (final entry in bundledHygieneEntries)
      if (_matches(<String>[
        ...entry.searchTerms,
        _hygieneTitle(AppLocalizations.of(context), entry),
      ]))
        entry,
  ];

  List<Medicine> get _medicines => <Medicine>[
    for (final medicine in bundledMedicines)
      if (_matches(<String>[medicine.genericName, ...medicine.brandNames]))
        medicine,
  ];

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
    final hygiene = _hygiene;
    final medicines = _medicines;
    final nothingMatched =
        hygiene.isEmpty && medicines.isEmpty && medicinesFetched;

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
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.lookupSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            if (hygiene.isNotEmpty) ...<Widget>[
              Text(
                l10n.lookupHygieneHeading,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.lookupCuratedNote,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final entry in hygiene) _HygieneCard(entry: entry),
              const SizedBox(height: 20),
            ],

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
              // Always, not only when a US user is detected — the app has no
              // way to detect anything. A reader applying US warnings to a box
              // bought elsewhere is being quietly misinformed.
              Text(
                l10n.lookupMedicinesUsOnly,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final medicine in medicines)
                _MedicineCard(medicine: medicine),
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

/// A curated hygiene entry.
class _HygieneCard extends StatelessWidget {
  const _HygieneCard({required this.entry});

  final HygieneEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final urgent = entry.urgency == HygieneUrgency.urgent;

    return Card(
      // The urgent entry does not look like the rest of the page. A screen
      // where the thing someone might need within the hour is styled like
      // reference reading is a screen where they do not find it.
      color: urgent ? theme.colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (urgent) ...<Widget>[
                  ExcludeSemantics(
                    child: Icon(
                      Icons.warning_amber_outlined,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _hygieneTitle(l10n, entry),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (urgent) ...<Widget>[
              // First, and in the emphasised style. Everything else on this
              // card is context for it.
              Text(
                l10n.hygieneTssUrgent,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(_hygieneBody(l10n, entry)),
          ],
        ),
      ),
    );
  }
}

/// One medicine's label sections, in a fixed order.
class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine});

  final Medicine medicine;

  /// The sections shown, in reading order, with their headings.
  ///
  /// A fixed order rather than whatever the map iterates: a label that happens
  /// to carry "stop use" before "what it is for" would otherwise render
  /// backwards. Sections absent from a label are simply not shown.
  static const List<String> _order = <String>[
    'purpose',
    'warnings',
    'do_not_use',
    'ask_doctor',
    'stop_use',
    'pregnancy_or_breast_feeding',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(medicine.genericName, style: theme.textTheme.titleSmall),
            if (medicine.brandNames.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                medicine.brandNames.join(', '),
                style: theme.textTheme.bodySmall,
              ),
            ],
            for (final section in _order)
              if (medicine.sections[section]
                  case final String text) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _sectionHeading(l10n, section),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
          ],
        ),
      ),
    );
  }

  static String _sectionHeading(AppLocalizations l10n, String section) =>
      switch (section) {
        'purpose' => l10n.lookupSectionPurpose,
        'warnings' => l10n.lookupSectionWarnings,
        'do_not_use' => l10n.lookupSectionDoNotUse,
        'ask_doctor' => l10n.lookupSectionAskDoctor,
        'stop_use' => l10n.lookupSectionStopUse,
        'pregnancy_or_breast_feeding' => l10n.lookupSectionPregnancy,
        // Unreachable for anything in _order, and a visible fallback rather
        // than a blank heading if the generator ever adds a section here.
        _ => section,
      };
}

String _hygieneTitle(AppLocalizations l10n, HygieneEntry entry) =>
    switch (entry.key) {
      'tss' => l10n.hygieneTssTitle,
      'tampons' => l10n.hygieneTamponsTitle,
      'cups' => l10n.hygieneCupsTitle,
      'external' => l10n.hygieneExternalTitle,
      _ => entry.key,
    };

String _hygieneBody(AppLocalizations l10n, HygieneEntry entry) =>
    switch (entry.key) {
      'tss' => l10n.hygieneTssBody,
      'tampons' => l10n.hygieneTamponsBody,
      'cups' => l10n.hygieneCupsBody,
      'external' => l10n.hygieneExternalBody,
      _ => '',
    };
