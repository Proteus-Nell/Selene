/// Day rollover.
///
/// Recomputes the prediction when the app comes back on a different day from
/// the one it last saw. A prediction is computed when the logs change, and
/// some of what it says depends on the day as well: a late period's range
/// moves forward a day at a time, and the count towards losing track goes up
/// whether or not anything is logged (ADR-0016). Phones keep an app alive in
/// the background for days, so without this, opening it on Thursday could
/// show a range moved forward to Tuesday.
///
/// Includes:
///     - DayRollover: The widget that watches for it.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/date_utils.dart';
import 'package:period_tracker/data/repositories/providers.dart';

/// Day rollover: recomputes the prediction when the day has changed.
///
/// Only on a change of day, not on every return to the app. The cache would
/// make a recompute cheap either way, but a prediction that has not changed
/// should not be rebuilt for nothing, and with it the notification schedule.
///
/// Attributes:
///     child (Widget): The subtree this sits in front of.
class DayRollover extends ConsumerStatefulWidget {
  /// Wraps [child].
  const DayRollover({required this.child, super.key});

  /// The subtree this sits in front of.
  final Widget child;

  @override
  ConsumerState<DayRollover> createState() => _DayRolloverState();
}

/// State for [DayRollover].
///
/// Attributes:
///     _listener (AppLifecycleListener): Reports the app coming back.
///     _day (CivilDate): The day the current prediction was made on.
class _DayRolloverState extends ConsumerState<DayRollover> {
  /// Reports the app coming back to the foreground.
  late final AppLifecycleListener _listener;

  /// The day the current prediction was made on.
  late CivilDate _day;

  @override
  void initState() {
    super.initState();
    _day = ref.read(clockProvider).today();
    _listener = AppLifecycleListener(onResume: _resumed);
  }

  /// Recompute the prediction if the day has moved on since the last look.
  void _resumed() {
    final today = ref.read(clockProvider).today();
    if (today == _day) return;
    _day = today;
    ref.invalidate(predictionProvider);
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
