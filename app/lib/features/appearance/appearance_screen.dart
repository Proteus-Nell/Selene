import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/motion.dart';
import 'package:period_tracker/core/palette.dart';
import 'package:period_tracker/core/theme.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Where the user chooses what the app looks like (AND-39).
///
/// Two independent choices: which of the six schemes, and whether to follow the
/// device or pin light or dark. Both apply on the next frame rather than the
/// next launch, because a colour chosen against a swatch and applied later is a
/// colour nobody can actually judge.
///
/// Each row carries its four phase colours as swatches. That is the part of a
/// scheme this app is actually judged on — the ring on the home screen is the
/// first thing anyone sees — and a row showing only the primary would be
/// choosing on the wrong evidence.
class AppearanceScreen extends ConsumerWidget {
  /// Creates the appearance screen.
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme =
        ref.watch(colourSchemeProvider).valueOrNull ?? AppScheme.fallback;
    final mode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    // `unawaited` rather than a discarded Future, as everywhere else in the
    // app. Nothing here waits on the write: the screen redraws from the stream
    // the write feeds, so awaiting it would only delay the frame that is
    // already coming.
    void chooseScheme(AppScheme chosen) => unawaited(
      ref
          .read(appDatabaseProvider)
          .settingsDao
          .writeString(SettingKey.colourScheme, chosen.wireName),
    );

    void chooseMode(ThemeMode chosen) => unawaited(
      ref
          .read(appDatabaseProvider)
          .settingsDao
          .writeString(SettingKey.themeMode, chosen.name),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceTitle)),
      body: SafeArea(
        // A scroll view over a Column rather than a ListView: the content is
        // six rows and a segmented button, and a lazy list would leave the
        // note under the theme control unbuilt on a short screen — which
        // means unreachable by a screen reader as well as by a test.
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SectionHeading(l10n.appearanceSchemeSection),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l10n.appearanceSchemeNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final option in AppScheme.values)
                _SchemeRow(
                  scheme: option,
                  selected: option == scheme,
                  onSelected: () => chooseScheme(option),
                ),
              const SizedBox(height: 8),
              _SectionHeading(l10n.appearanceThemeSection),
              _ThemeModeRow(
                mode: mode,
                // Night has no light half, so the control would be a switch that
                // does nothing. Disabled and explained beats silently ignored.
                enabled: !scheme.forcesDark,
                onSelected: chooseMode,
              ),
              if (scheme.forcesDark)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    l10n.appearanceThemeLockedByScheme,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One scheme, its description, and the four colours it paints a cycle in.
class _SchemeRow extends StatelessWidget {
  const _SchemeRow({
    required this.scheme,
    required this.selected,
    required this.onSelected,
  });

  final AppScheme scheme;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The swatches are drawn in the scheme they advertise, not the one the app
    // is currently wearing, which is the whole point of showing them. Light or
    // dark follows the app, so a row previews what tapping it would give.
    final palette = scheme.palette(theme.brightness);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTheme.minTapTarget,
            ),
            child: Row(
              children: <Widget>[
                // The radio is drawn rather than a Radio widget: Material's
                // wants a group value and a changed callback of its own, and
                // wiring one to a stream that is the source of truth means two
                // things believing they own the selection.
                _SelectionDot(selected: selected),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        _label(l10n, scheme),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      Text(
                        _subtitle(l10n, scheme),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Excluded from semantics: a screen reader gets the name and
                // the description, and four unlabelled colours announced as
                // anything at all would be noise. The row is selectable by its
                // name, which is what a non-sighted user is choosing by.
                ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final color in palette.phaseColors)
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _label(AppLocalizations l10n, AppScheme scheme) =>
      switch (scheme) {
        AppScheme.rose => l10n.appearanceSchemeRose,
        AppScheme.sage => l10n.appearanceSchemeSage,
        AppScheme.lilac => l10n.appearanceSchemeLilac,
        AppScheme.periwinkle => l10n.appearanceSchemePeriwinkle,
        AppScheme.ink => l10n.appearanceSchemeInk,
        AppScheme.night => l10n.appearanceSchemeNight,
      };

  static String _subtitle(AppLocalizations l10n, AppScheme scheme) =>
      switch (scheme) {
        AppScheme.rose => l10n.appearanceSchemeRoseSubtitle,
        AppScheme.sage => l10n.appearanceSchemeSageSubtitle,
        AppScheme.lilac => l10n.appearanceSchemeLilacSubtitle,
        AppScheme.periwinkle => l10n.appearanceSchemePeriwinkleSubtitle,
        AppScheme.ink => l10n.appearanceSchemeInkSubtitle,
        AppScheme.night => l10n.appearanceSchemeNightSubtitle,
      };
}

/// The filled ring that marks the chosen row.
class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 22,
      height: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: 2,
          ),
        ),
        child: Center(
          // Sized rather than swapped, so the row does not reflow when the
          // selection moves, and it grows over `Motion.quick` — which is zero
          // when the user has asked for no animations.
          child: AnimatedContainer(
            duration: Motion.quick(context),
            curve: Motion.curve,
            width: selected ? 11 : 0,
            height: selected ? 11 : 0,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Follow the device, or pin light or dark.
class _ThemeModeRow extends StatelessWidget {
  const _ThemeModeRow({
    required this.mode,
    required this.enabled,
    required this.onSelected,
  });

  final ThemeMode mode;
  final bool enabled;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SegmentedButton<ThemeMode>(
        segments: <ButtonSegment<ThemeMode>>[
          ButtonSegment<ThemeMode>(
            value: ThemeMode.light,
            label: Text(l10n.appearanceThemeLight),
          ),
          ButtonSegment<ThemeMode>(
            value: ThemeMode.dark,
            label: Text(l10n.appearanceThemeDark),
          ),
          ButtonSegment<ThemeMode>(
            value: ThemeMode.system,
            label: Text(l10n.appearanceThemeSystem),
          ),
        ],
        selected: <ThemeMode>{mode},
        showSelectedIcon: false,
        onSelectionChanged: enabled
            ? (selection) => onSelected(selection.first)
            : null,
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, AppTheme.minTapTarget),
        ),
      ),
    );
  }
}

/// A small caps heading over a group of rows.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
