import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/db/daos/settings_dao.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/domain/models/day_log.dart';
import 'package:period_tracker/features/common/formatting.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/routing/router.dart';

/// First run: what the app is not, then one date.
///
/// Two things about this screen are requirements rather than choices.
///
/// **The disclaimer is a screen the user reads, not a buried EULA.** A period
/// predictor is one careless sentence away from claiming to be a contraceptive,
/// and the non-claims in `docs/PLAN.md` 6.2 are the copy spec for what is said
/// here.
///
/// **The notification permission is not requested here.** Asking at first
/// launch gets denied by reflex, and on Android 13+ re-asking after a denial is
/// deliberately hard. That request belongs in context, after the first cycle is
/// logged (`docs/PLAN.md` 2.4.3, and task AND-17).
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the onboarding flow.
  ///
  /// [onFinished] defaults to navigating to the log screen. It is injectable so
  /// that a widget test can exercise the flow without standing up a router,
  /// which would otherwise make the copy tests depend on navigation.
  const OnboardingScreen({this.onFinished, super.key});

  /// Called once the user has finished, after the settings write.
  final VoidCallback? onFinished;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _disclaimerAcknowledged = false;
  CivilDate? _selectedDate;

  Future<void> _finish({required bool withDate}) async {
    final repository = ref.read(cycleRepositoryProvider);
    final settings = ref.read(appDatabaseProvider).settingsDao;
    final date = _selectedDate;
    if (withDate && date != null) {
      await repository.upsert(DayLog(date: date, flow: FlowIntensity.medium));
    }
    await settings.writeBool(SettingKey.onboardingComplete, value: true);
    if (!mounted) return;
    final finished = widget.onFinished;
    if (finished != null) {
      finished();
    } else {
      context.go(Routes.log);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _disclaimerAcknowledged
            ? _FirstEntry(
                today: ref.watch(clockProvider).today(),
                selected: _selectedDate,
                onSelected: (date) => setState(() => _selectedDate = date),
                onSave: () => _finish(withDate: true),
                onSkip: () => _finish(withDate: false),
              )
            : _Disclaimer(
                onAcknowledge: () =>
                    setState(() => _disclaimerAcknowledged = true),
              ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.onAcknowledge});

  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            children: <Widget>[
              Text(l10n.onboardingTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(l10n.onboardingIntro, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              Text(
                l10n.onboardingWhatItIsNotTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _NonClaim(text: l10n.onboardingNotContraception),
              _NonClaim(text: l10n.onboardingNotMedical),
              _NonClaim(text: l10n.onboardingNotDiagnostic),
              _NonClaim(text: l10n.onboardingAlwaysARange),
              const SizedBox(height: 24),
              // Named here, before the user has recorded anything, rather than
              // left to be discovered. docs/PLAN.md 6.5 says to treat this data
              // as if it will be read by someone the user did not choose; the
              // corollary is that they get to know which field carries the most
              // risk before they decide whether to use it. It points at the app
              // lock in the same breath, so the disclosure comes with the
              // remedy rather than only the warning.
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.onboardingSensitiveTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.onboardingSensitiveBody),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAcknowledge,
              child: Text(l10n.onboardingAcknowledge),
            ),
          ),
        ),
      ],
    );
  }
}

class _NonClaim extends StatelessWidget {
  const _NonClaim({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Excluded from semantics: a screen reader announcing "block"
          // before every line adds nothing, and the text says it all.
          ExcludeSemantics(
            child: Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _FirstEntry extends StatelessWidget {
  const _FirstEntry({
    required this.today,
    required this.selected,
    required this.onSelected,
    required this.onSave,
    required this.onSkip,
  });

  /// Today, from the injected clock rather than the device.
  ///
  /// Not [DateTime.now]: `tools/scripts/check_no_datetime_now.sh` forbids it
  /// outside `core/clock.dart`, and the reason bites here specifically. The
  /// repository refuses future-dated writes, so a picker anchored on the real
  /// device clock while the repository is anchored on an injected one would
  /// silently reject every date the user chose.
  final CivilDate today;

  final CivilDate? selected;
  final ValueChanged<CivilDate> onSelected;
  final VoidCallback onSave;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final anchor = today.toLocalMidnight();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.onboardingFirstEntryTitle,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.onboardingFirstEntryBody,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: CalendarDatePicker(
              initialDate: anchor,
              // A period start is in the past by definition, and 180 days back
              // is further than anyone remembers precisely.
              firstDate: anchor.subtract(const Duration(days: 180)),
              lastDate: anchor,
              onDateChanged: (value) => onSelected(
                CivilDate(value.year, value.month, value.day),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Row(
            children: <Widget>[
              TextButton(
                onPressed: onSkip,
                child: Text(l10n.onboardingFirstEntrySkip),
              ),
              const Spacer(),
              FilledButton(
                onPressed: selected == null ? null : onSave,
                child: Text(
                  selected == null
                      ? l10n.commonSave
                      : l10n.logStartedOn(selected!.dayAndMonth(context)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
