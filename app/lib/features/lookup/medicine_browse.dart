/// Medicines A-Z.
///
/// The browse half of Look something up, next to its search: a letter grid,
/// a page per letter listing every name under it, and a page for a name more
/// than one drug goes by. Everything comes from the index the lookup has
/// already loaded.
///
/// Includes:
///     - MedicineLetters: The grid of letters.
///     - MedicineLetterScreen: Every name under one letter.
///     - MedicineNameScreen: The drugs that share one name.
///     - MedicineTile: One drug in a list, opening onto its label.
///     - _NameRow: One name on a letter's page.
library;

import 'package:flutter/material.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/features/lookup/medicine_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// The grid of letters a reader browses the medicines by.
///
/// Every letter is shown, in the same place every time, and one no name
/// starts with is greyed out rather than left out. A grid that closed up
/// around the gaps would put each letter somewhere different.
///
/// Attributes:
///     index (MedicineIndex): Every drug.
class MedicineLetters extends StatelessWidget {
  /// Creates the grid.
  ///
  /// Args:
  ///     index (MedicineIndex): Every drug.
  const MedicineLetters({required this.index, super.key});

  /// Every drug.
  final MedicineIndex index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: <Widget>[
        for (final letter in MedicineIndex.letters)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: TextButton(
              onPressed: index.browse(letter).isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => MedicineLetterScreen(
                          letter: letter,
                          names: index.browse(letter),
                        ),
                      ),
                    ),
              child: Text(
                letter.toUpperCase(),
                // "A" read aloud is a letter, not a way in. Said in full, a
                // screen reader user knows what tapping it does.
                semanticsLabel: letter == '#'
                    ? l10n.lookupBrowseOther
                    : l10n.lookupBrowseLetter(letter.toUpperCase()),
              ),
            ),
          ),
      ],
    );
  }
}

/// Every name under one letter, in alphabetical order.
///
/// "A" alone holds several hundred names, so the scrollbar can be dragged:
/// reading through to "azithromycin" a row at a time is not browsing.
///
/// Attributes:
///     letter (String): The letter, as [MedicineIndex.letters] writes it.
///     names (`List<MedicineName>`): The names under it.
class MedicineLetterScreen extends StatefulWidget {
  /// Creates the page for [letter].
  ///
  /// Args:
  ///     letter (String): The letter, as [MedicineIndex.letters] writes it.
  ///     names (`List<MedicineName>`): The names under it, in order.
  const MedicineLetterScreen({
    required this.letter,
    required this.names,
    super.key,
  });

  /// The letter, as [MedicineIndex.letters] writes it.
  final String letter;

  /// The names under it, in alphabetical order.
  final List<MedicineName> names;

  @override
  State<MedicineLetterScreen> createState() => _MedicineLetterScreenState();
}

/// State for [MedicineLetterScreen]: the scroll position the scrollbar drags.
class _MedicineLetterScreenState extends State<MedicineLetterScreen> {
  /// Shared by the list and its scrollbar.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.lookupBrowseTitle(widget.letter.toUpperCase())),
      ),
      body: SafeArea(
        child: Scrollbar(
          controller: _scroll,
          interactive: true,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: widget.names.length,
            itemBuilder: (context, i) => _NameRow(name: widget.names[i]),
          ),
        ),
      ),
    );
  }
}

/// One name on a letter's page.
///
/// A name with one drug opens straight onto its label. A name several drugs
/// go by opens onto a page that tells them apart, rather than picking one of
/// them for the reader.
///
/// Attributes:
///     name (MedicineName): The name, and the drugs that go by it.
class _NameRow extends StatelessWidget {
  /// Creates a row.
  ///
  /// Args:
  ///     name (MedicineName): The name, and the drugs that go by it.
  const _NameRow({required this.name});

  /// The name, and the drugs that go by it.
  final MedicineName name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final single = name.entries.length == 1;
    return ListTile(
      title: Text(name.name, maxLines: 3, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        single
            ? medicineKind(l10n, name.entries.single)
            : l10n.lookupBrowseShared(name.entries.length),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => single
              ? MedicineScreen(entry: name.entries.single)
              : MedicineNameScreen(name: name),
        ),
      ),
    );
  }
}

/// The drugs that share one name.
///
/// Each is titled by what is in it rather than by the name they share, which
/// would be the same on every row.
///
/// Attributes:
///     name (MedicineName): The name, and the drugs that go by it.
class MedicineNameScreen extends StatelessWidget {
  /// Creates the page for [name].
  ///
  /// Args:
  ///     name (MedicineName): The name, and the drugs that go by it.
  const MedicineNameScreen({required this.name, super.key});

  /// The name, and the drugs that go by it.
  final MedicineName name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lookupMedicinesHeading)),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: name.entries.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(name.name, style: theme.textTheme.titleLarge),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.lookupBrowseSharedIntro,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }
            final entry = name.entries[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MedicineTile(
                entry: entry,
                title: entry.substances.isEmpty
                    ? null
                    : entry.substances.join(', '),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One drug in a list: its name, how it is taken, and its brands.
///
/// Opens onto the drug's own page, unless it is being picked for a list. The
/// label text is long, and a list where every row carried its full label
/// would be a list nobody could scan.
///
/// Attributes:
///     entry (MedicineEntry): The drug.
///     brand (String?): The brand it was found by, listed first.
///     title (String?): What to title the row by, in place of the name.
///     onPicked (`ValueChanged<MedicineEntry>?`): Called with [entry] when
///         the tile picks a drug rather than opening one.
class MedicineTile extends StatelessWidget {
  /// Creates a tile.
  ///
  /// Args:
  ///     entry (MedicineEntry): The drug.
  ///     brand (String?): The brand a search found it by, if any.
  ///     title (String?): A title in place of the drug's name: its
  ///         substances, where several drugs share the name.
  ///     onPicked (`ValueChanged<MedicineEntry>?`): Picks the drug instead of
  ///         opening its page. Defaults to null, which opens the page.
  const MedicineTile({
    required this.entry,
    this.brand,
    this.title,
    this.onPicked,
    super.key,
  });

  /// The drug.
  final MedicineEntry entry;

  /// The brand a search found the drug by, listed first among its brands.
  final String? brand;

  /// What the row is titled by, when not the drug's name.
  final String? title;

  /// Called with [entry] when the tile picks a drug rather than opening one.
  final ValueChanged<MedicineEntry>? onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The brand it was found by goes first: searching "plan b" and getting
    // "LEVONORGESTREL" back is only reassuring if "Plan B" is on the tile.
    final brands = medicineBrands(l10n, entry, first: brand, limit: 3);
    return Card(
      child: ListTile(
        title: Text(title ?? entry.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(medicineKind(l10n, entry)),
            if (brands != null) Text(brands),
          ],
        ),
        trailing: Icon(
          onPicked == null ? Icons.chevron_right : Icons.add_circle_outline,
        ),
        onTap: switch (onPicked) {
          final picked? => () => picked(entry),
          null => () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => MedicineScreen(entry: entry, brand: brand),
            ),
          ),
        },
      ),
    );
  }
}
