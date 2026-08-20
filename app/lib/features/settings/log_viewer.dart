import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/logging.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Shows every log line the app has recorded, and lets the user clear them.
///
/// The point of showing it is verification. The claim in `docs/PRIVACY.md` is
/// that the activity log holds no cycle content, and this screen is how the
/// user checks that for themselves rather than taking it on trust. The claim is
/// true by construction: [LogEvent] is an enum and [LogField] admits only
/// counts, durations, flags and enum names, so there is no way to spell a date
/// or a symptom into a log line.
class LogViewerScreen extends ConsumerStatefulWidget {
  /// Creates the log viewer.
  const LogViewerScreen({super.key});

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final logger = ref.watch(loggerProvider);
    final records = logger.records.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsLogViewer),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: l10n.settingsLogViewerClear,
            onPressed: records.isEmpty
                ? null
                : () {
                    logger.clear();
                    setState(() {});
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(content: Text(l10n.settingsLogViewerCleared)),
                      );
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: records.isEmpty
            ? Center(child: Text(l10n.settingsLogViewerEmpty))
            : ListView.separated(
                itemCount: records.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final record = records[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      record.event.name,
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      record.toJsonLine(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
