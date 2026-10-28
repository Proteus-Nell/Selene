/// Medicine screen.
///
/// One medicine's label, as published: what the medicine is, which label
/// stands for it, and the label's safety sections in the order the label is
/// read. Below them, where the label has one, the safety sections of its
/// Medication Guide, the leaflet written for patients (ADR-0022). Nothing on
/// it is written for this app (ADR-0012).
///
/// Includes:
///     - MedicineScreen: The screen.
///     - medicineKind: How a medicine is taken, and whether it needs a
///       prescription.
///     - medicineBrands: Its brand names, cut short.
///     - medicineSectionHeading: A label section's heading.
///     - _Section: One section, under its heading.
///     - _Guide: The Medication Guide's safety sections, folded away.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_bundle.dart';
import 'package:period_tracker/data/reference/medicines_bundled.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/features/lookup/interaction_checker_screen.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Medicine screen: one medicine's label.
///
/// The label text loads when the screen opens, from the chunk of the bundle
/// that holds it. The header does not wait for it: everything above the
/// sections comes from the index, which is already loaded.
///
/// Attributes:
///     entry (MedicineEntry): The medicine.
///     brand (String?): The brand it was found by, listed first.
class MedicineScreen extends ConsumerWidget {
  /// Creates the screen for [entry].
  ///
  /// Args:
  ///     entry (MedicineEntry): The medicine.
  ///     brand (String?): The brand it was found by, if it was found by one.
  const MedicineScreen({required this.entry, this.brand, super.key});

  /// The medicine.
  final MedicineEntry entry;

  /// The brand it was found by, listed first among its brands.
  final String? brand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final sections = ref.watch(medicineSectionsProvider(entry));
    final guide = ref.watch(medicineGuideProvider(entry)).valueOrNull;
    final brands = medicineBrands(l10n, entry, first: brand, limit: 12);
    final date =
        entry.label.effectiveDate?.full(context) ?? entry.label.effectiveTime;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lookupMedicinesHeading)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(entry.name, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 4),
            Text(medicineKind(l10n, entry), style: theme.textTheme.bodyMedium),
            if (brands != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(brands, style: small),
            ],
            const SizedBox(height: 12),
            // On every medicine, not once on the list before it: this is the
            // page a reader compares with the box in their hand.
            Text(l10n.lookupMedicinesUsOnly, style: small),
            const SizedBox(height: 4),
            Text(
              l10n.lookupMedicineLabel(entry.label.manufacturer, date),
              style: small,
            ),
            const SizedBox(height: 4),
            Text(l10n.lookupMedicineOneLabel, style: small),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => InteractionCheckerScreen(
                      initial: <MedicineEntry>[entry],
                    ),
                  ),
                ),
                icon: const Icon(Icons.compare_arrows),
                label: Text(l10n.lookupMedicineCheck),
              ),
            ),
            ...sections.when(
              data: (sections) => <Widget>[
                for (final section in sections) _Section(section: section),
              ],
              error: (error, stack) => <Widget>[
                const SizedBox(height: 8),
                Text(l10n.lookupMedicineFailed),
              ],
              loading: () => <Widget>[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  semanticsLabel: l10n.lookupMedicineLoading,
                ),
              ],
            ),
            if (guide != null && guide.isNotEmpty) ...<Widget>[
              const SizedBox(height: 24),
              _Guide(guide: guide),
            ],
            const SizedBox(height: 24),
            Text(medicinesDisclaimer, style: small),
          ],
        ),
      ),
    );
  }
}

/// One label section, under its heading.
///
/// The boxed warning is set apart the way the label sets it apart: it is the
/// FDA's most serious warning, and printed like the rest it reads as one more
/// paragraph.
///
/// Attributes:
///     section (MedicineSection): The section.
class _Section extends StatelessWidget {
  /// Creates a section.
  ///
  /// Args:
  ///     section (MedicineSection): The section.
  const _Section({required this.section});

  /// The section.
  final MedicineSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final boxed = section.name == 'boxed_warning';
    // The theme's body text is dark, and so is its error container, which is
    // its error colour.
    final ink = boxed ? theme.colorScheme.onErrorContainer : null;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            medicineSectionHeading(l10n, section.name),
            style: theme.textTheme.titleSmall?.copyWith(color: ink),
          ),
        ),
        for (final paragraph in section.paragraphs) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            paragraph,
            style: theme.textTheme.bodyMedium?.copyWith(color: ink),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: boxed
          ? Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(padding: const EdgeInsets.all(16), child: body),
            )
          : body,
    );
  }
}

/// The safety sections of a medicine's Medication Guide, folded away under a
/// note that says what they are and what is left out.
///
/// Folded, because a guide is long and the label above it is what the page
/// is for. The note is above the fold, so nobody opens it expecting to find
/// how to take the medicine.
///
/// Attributes:
///     guide (`List<GuideSection>`): The guide's safety sections.
class _Guide extends StatelessWidget {
  /// Creates the guide.
  const _Guide({required this.guide});

  /// The guide's safety sections, in its order.
  final List<GuideSection> guide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(l10n.lookupGuideTitle, style: theme.textTheme.titleSmall),
        subtitle: Text(l10n.lookupGuideNote, style: theme.textTheme.bodySmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final section in guide) ...<Widget>[
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(section.heading, style: theme.textTheme.titleSmall),
            ),
            for (final part in section.parts) ...<Widget>[
              const SizedBox(height: 4),
              Text(part, style: theme.textTheme.bodyMedium),
            ],
          ],
        ],
      ),
    );
  }
}

/// Say how a medicine is taken, and whether it needs a prescription.
///
/// Args:
///     l10n (AppLocalizations): The translations.
///     entry (MedicineEntry): The medicine.
///
/// Returns:
///     String: Such as "Oral · Over the counter". The route is openFDA's own
///     word, with only its case changed, and is left out for the few kits
///     that have none.
String medicineKind(AppLocalizations l10n, MedicineEntry entry) {
  final type = switch (entry.type) {
    MedicineType.prescription => l10n.lookupMedicinePrescription,
    MedicineType.overTheCounter => l10n.lookupMedicineOverTheCounter,
  };
  if (entry.routes.isEmpty) return type;
  final routes = entry.routes
      .map(
        (route) => route.isEmpty
            ? route
            : route[0].toUpperCase() + route.substring(1).toLowerCase(),
      )
      .join(', ');
  return '$routes · $type';
}

/// List a medicine's brand names, cut short.
///
/// Args:
///     l10n (AppLocalizations): The translations.
///     entry (MedicineEntry): The medicine.
///     first (String?): A brand to list before the rest: the one a search
///         found it by.
///     limit (int): The most names to list before counting the rest.
///
/// Returns:
///     String?: The names, and how many more there are, or null when the
///     medicine has no brand names.
String? medicineBrands(
  AppLocalizations l10n,
  MedicineEntry entry, {
  required int limit,
  String? first,
}) {
  final brands = <String>[
    ?first,
    for (final brand in entry.brands)
      if (brand != first) brand,
  ];
  if (brands.isEmpty) return null;
  final named = brands.take(limit).join(', ');
  final rest = brands.length - limit;
  return rest > 0 ? l10n.lookupMedicineOtherNames(named, rest) : named;
}

/// Return the heading for one label section.
///
/// Args:
///     l10n (AppLocalizations): The translations.
///     section (String): The section's openFDA field name.
///
/// Returns:
///     String: Its heading, or the field name itself for a section the
///     generator starts carrying before this switch knows it: visible, rather
///     than a section with no heading.
String medicineSectionHeading(AppLocalizations l10n, String section) =>
    switch (section) {
      'boxed_warning' => l10n.lookupSectionBoxedWarning,
      'purpose' => l10n.lookupSectionPurpose,
      'indications_and_usage' => l10n.lookupSectionUses,
      'contraindications' => l10n.lookupSectionContraindications,
      'warnings_and_cautions' => l10n.lookupSectionWarningsAndPrecautions,
      'warnings' => l10n.lookupSectionWarnings,
      'precautions' => l10n.lookupSectionPrecautions,
      'drug_interactions' => l10n.lookupSectionInteractions,
      'use_in_specific_populations' => l10n.lookupSectionSpecificPopulations,
      'pregnancy' => l10n.lookupSectionPregnancyLabel,
      'nursing_mothers' => l10n.lookupSectionNursingMothers,
      'do_not_use' => l10n.lookupSectionDoNotUse,
      'ask_doctor' => l10n.lookupSectionAskDoctor,
      'ask_doctor_or_pharmacist' => l10n.lookupSectionAskDoctorOrPharmacist,
      'when_using' => l10n.lookupSectionWhenUsing,
      'stop_use' => l10n.lookupSectionStopUse,
      'pregnancy_or_breast_feeding' => l10n.lookupSectionPregnancy,
      _ => section,
    };
