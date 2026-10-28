/// Herbal supplements screens.
///
/// NCCIH's Herbs at a Glance fact sheets, as NCCIH wrote them (ADR-0023): an
/// A to Z of every herb, and each herb's page, with what it is, what research
/// has found and what is known about its safety. Nothing on them is written
/// for this app, and nothing is fetched: the sheets are in the app's assets.
///
/// Not the Supplements page under Learn, which is about nutrition and stays
/// behind the ten-second hold. These are found on Look something up.
///
/// Includes:
///     - SupplementsScreen: Every herb, A to Z.
///     - SupplementScreen: One herb's fact sheet.
///     - SupplementTile: One herb in a list.
///     - _Section: One section of a fact sheet, under its heading.
///     - _Block: One paragraph or list item, indented as the page nests it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/data/reference/supplement.dart';
import 'package:period_tracker/data/reference/supplement_bundle.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/lookup/interaction_checker_screen.dart';
import 'package:period_tracker/features/lookup/list_mark.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Every herb in the reference, A to Z, under its initial.
class SupplementsScreen extends ConsumerWidget {
  /// Creates the A to Z.
  const SupplementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final reference = ref.watch(supplementsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lookupSupplementsEntry)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            ...reference.when(
              data: (reference) => <Widget>[
                Text(
                  l10n.supplementsIntro(_fetched(context, reference.fetched)),
                  style: theme.textTheme.bodyMedium,
                ),
                for (final (letter, herbs) in _byInitial(
                  reference.herbs,
                )) ...<Widget>[
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(letter, style: theme.textTheme.titleSmall),
                  ),
                  const SizedBox(height: 8),
                  for (final herb in herbs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SupplementTile(supplement: herb),
                    ),
                ],
                const SizedBox(height: 16),
                Text(reference.disclaimer, style: small),
              ],
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

/// One herb's fact sheet: its names, where the sheet is from, and its
/// sections in the page's order.
///
/// Attributes:
///     supplement (Supplement): The herb.
class SupplementScreen extends ConsumerWidget {
  /// Creates the page for [supplement].
  const SupplementScreen({required this.supplement, super.key});

  /// The herb.
  final Supplement supplement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final disclaimer = ref.watch(supplementsProvider).valueOrNull?.disclaimer;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lookupSupplementsHeading)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(supplement.name, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.supplementsCommonNames(supplement.commonNames.join(', ')),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.supplementsLatinNames(supplement.latinNames.join(', ')),
              style: small?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            Text(l10n.supplementsSource(supplement.updated), style: small),
            // Compared with medicines only where there are medicines to
            // compare it with.
            if (medicinesFetched) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => InteractionCheckerScreen(
                        initialSupplements: <Supplement>[supplement],
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.compare_arrows),
                  label: Text(l10n.supplementsCompare),
                ),
              ),
            ],
            for (final section in supplement.sections)
              _Section(section: section),
            const SizedBox(height: 24),
            Text(l10n.supplementsPhoto, style: small),
            const SizedBox(height: 4),
            SelectableText(
              l10n.supplementsAddress(supplement.url),
              style: small,
            ),
            if (disclaimer != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(disclaimer, style: small),
            ],
          ],
        ),
      ),
    );
  }
}

/// One herb in a list: its title, and under it the name a search found it
/// by or its Latin names.
///
/// Attributes:
///     supplement (Supplement): The herb.
///     alias (String?): The name a search found it by, when not its title.
///     onPicked (`ValueChanged<Supplement>?`): What a tap does instead of
///         opening the herb's page: the checker's picker hands it back.
class SupplementTile extends StatelessWidget {
  /// Creates the tile.
  const SupplementTile({
    required this.supplement,
    this.alias,
    this.onPicked,
    super.key,
  });

  /// The herb.
  final Supplement supplement;

  /// The name a search found it by, when that was not its title.
  final String? alias;

  /// What a tap does instead of opening the herb's page.
  final ValueChanged<Supplement>? onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final picked = onPicked;
    final found = alias;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.eco_outlined),
        title: Text(supplement.name),
        subtitle: Text(
          found != null
              ? l10n.supplementsFoundBy(found)
              : supplement.latinNames.join(', '),
        ),
        trailing: picked == null ? const Icon(Icons.chevron_right) : null,
        onTap: picked != null
            ? () => picked(supplement)
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      SupplementScreen(supplement: supplement),
                ),
              ),
      ),
    );
  }
}

/// One section of a fact sheet, under its heading.
///
/// Attributes:
///     section (SupplementSection): The section.
class _Section extends StatelessWidget {
  /// Creates a section.
  const _Section({required this.section});

  /// The section.
  final SupplementSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(section.heading, style: theme.textTheme.titleSmall),
          ),
          for (final block in section.blocks) _Block(block: block),
        ],
      ),
    );
  }
}

/// One paragraph or list item, with its mark drawn beside its text and
/// indented as deep as the page nests it.
///
/// Attributes:
///     block (SupplementBlock): The paragraph or item.
class _Block extends StatelessWidget {
  /// Creates a block.
  const _Block({required this.block});

  /// The paragraph or item.
  final SupplementBlock block;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: block.depth == 0
          ? Text(block.text, style: style)
          : ListItem(depth: block.depth, text: block.text, style: style),
    );
  }
}

/// [herbs], already in A to Z order, under the letter each starts with.
List<(String, List<Supplement>)> _byInitial(List<Supplement> herbs) {
  final groups = <(String, List<Supplement>)>[];
  for (final herb in herbs) {
    final letter = herb.name.isEmpty ? '' : herb.name[0].toUpperCase();
    if (groups.isEmpty || groups.last.$1 != letter) {
      groups.add((letter, <Supplement>[]));
    }
    groups.last.$2.add(herb);
  }
  return groups;
}

/// When the sheets were read, as the locale writes a date, or as the
/// reference gives it if that is not one.
String _fetched(BuildContext context, String fetched) {
  try {
    return CivilDate.parseIso8601(fetched).full(context);
  } on FormatException {
    return fetched;
  }
}
