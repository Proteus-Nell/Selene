/// Companion dock.
///
/// The bottom bar with the companion sitting at the end of it, the sheet its
/// suggestion arrives in, and the crescent that breathes on the button. It
/// takes width from the navigation bar rather than floating over the screen,
/// so "covers nothing" is a property of the layout rather than a hope.
///
/// Includes:
///     - CompanionDock: The row: navigation bar, then companion.
///     - CompanionButton: The control that offers the line.
///     - showCompanionSuggestion: The sheet the line arrives in.
///     - CompanionBreath: How long a breath lasts, and how big it is.
///     - CompanionMark: The crescent, and the ticker behind it.
///     - _CompanionMarkState: When that ticker runs, and when it must not.
///     - _CrescentPainter: The crescent and its halo, at one point of a
///       breath.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/core/motion.dart';
import 'package:period_tracker/features/companion/companion_lines.dart';
import 'package:period_tracker/features/companion/companion_providers.dart';
import 'package:period_tracker/l10n/app_localizations.dart';

/// Companion dock: the bottom bar, with the companion at the end (AND-37).
///
/// **Why it is in the bar rather than floating over the screen.** The brief for
/// this feature was a persistent presence that does not block content and does
/// not cover a tap target, and a floating badge cannot promise either. It sits
/// on top of whatever is underneath it, and what is underneath it here includes
/// the last line of every scrolled list and the extended action button on the
/// conditions screen. Giving the companion its own slot in the bar is the only
/// arrangement where "covers nothing" is a property of the layout instead of a
/// hope about the screens, and `companion_dock_test.dart` asserts the two
/// rectangles do not meet, so a later change back to floating fails.
///
/// It costs no vertical space: the navigation bar is already tall enough for a
/// 48dp target, so the companion takes width from four destinations that had
/// more than they needed rather than height from the screen.
///
/// It is inside [Scaffold.bottomNavigationBar] of the shell, which puts it on
/// all four tabs and on every screen pushed within them. It is **outside** the
/// onboarding route, which is deliberate: the first thing a new user reads is
/// the disclaimer, and nothing should be sitting beside it offering advice.
///
/// Attributes:
///     navigationBar (Widget): The app's navigation bar.
///     showCompanion (bool): Whether the companion is offered at all.
class CompanionDock extends StatelessWidget {
  /// Wraps [navigationBar] and puts the companion at the end of the same row.
  ///
  /// Args:
  ///     navigationBar (Widget): The app's navigation bar, laid out in the
  ///         space the companion leaves.
  ///     showCompanion (bool, optional): Whether the companion is offered.
  ///         Defaults to false, so a caller that has not been taught about
  ///         the preference gets the bar without it. With it false the row is
  ///         the navigation bar alone and the width goes back to the
  ///         destinations.
  const CompanionDock({
    required this.navigationBar,
    this.showCompanion = false,
    super.key,
  });

  /// The app's navigation bar, laid out in the space the companion leaves.
  final Widget navigationBar;

  /// Whether the companion is offered at all (AND-37).
  ///
  /// Off by default, so a caller that has not been taught about the preference
  /// gets the bar without it rather than one the user did not ask for.
  final bool showCompanion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      // The colour a bare NavigationBar paints itself, so the seam between the
      // two halves of this row is invisible.
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              // The bar has a SafeArea of its own. The outer one above has
              // already taken the system inset, so this stops it being taken
              // twice and the bar floating clear of the bottom edge.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: navigationBar,
              ),
            ),
            if (showCompanion)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: CompanionButton(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Companion button: a labelled control that offers one line (AND-37).
///
/// A control, not an ornament, so it is named for a screen reader and meets the
/// 48dp target the theme sets for every icon button. Its suggestion is not
/// painted next to it. It arrives on tap, in a sheet a screen reader reads and
/// anyone can dismiss.
class CompanionButton extends ConsumerWidget {
  /// Creates the companion control.
  const CompanionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Watched rather than read on tap, and that is not a style choice. Riverpod
    // providers are lazy: read from inside `onPressed`, the logs, the
    // prediction and the conditions would all begin loading at the moment of
    // the tap, and the first thing the companion ever said would be "the log is
    // still being read". Watching keeps the answer current for the whole time
    // the bar is on screen, which is the whole time the app is.
    final line = ref.watch(companionLineProvider);
    return IconButton(
      tooltip: l10n.companionLabel,
      onPressed: () => showCompanionSuggestion(context, line),
      icon: const SizedBox.square(dimension: 24, child: CompanionMark()),
    );
  }
}

/// Show the current suggestion, dismissibly.
///
/// A sheet rather than a bubble drawn beside the dock. It takes focus, so a
/// screen reader reads the line without being driven to it; it can be left by
/// the dismiss button, by the drag handle, by the back gesture or by tapping
/// away; and it is a route, so it is torn down with everything else when the
/// app locks.
///
/// Args:
///     context (BuildContext): What to show the sheet over.
///     line (CompanionLine): The line to say. Already chosen by the rules in
///         `companion_rules.dart` rather than picked here.
///
/// Returns:
///     `Future<void>`: Completes when the sheet is closed, however it was
///     closed. Nothing is recorded about which way that was.
Future<void> showCompanionSuggestion(
  BuildContext context,
  CompanionLine line,
) {
  final theme = Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surfaceContainer,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        // Scrollable, because the sheet is capped at a fraction of the screen
        // and the longest line here is three clauses plus a citation note. At
        // 200% text scale that is taller than the cap on any phone, and a
        // suggestion that cannot be read to the end is worse than none.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SizedBox.square(dimension: 24, child: CompanionMark()),
                  const SizedBox(width: 12),
                  Text(l10n.companionLabel, style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              Text(line.text(l10n), style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.companionDismiss),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// How long one breath of the idle animation takes.
///
/// Derived from [Motion.standard] rather than added to [Motion] as a sixth
/// token, for two reasons. A token added there has to be added to `Motion.all`
/// and to the list `motion_test.dart` pins, and this is not a new kind of
/// movement. It is the app's one transition duration, held long enough to read
/// as breathing rather than as a control answering a finger. And multiplying
/// keeps the accessibility guarantee for free: zero times anything is zero, so
/// "remove animations" collapses this the same way it collapses everything
/// else, and [CompanionMark] then paints its resting frame and starts no ticker
/// at all.
abstract final class CompanionBreath {
  /// How many [Motion.standard]s one half-breath lasts.
  static const int standards = 6;

  /// Return how long one half-breath lasts.
  ///
  /// Args:
  ///     context (BuildContext): Read for the device's animation setting.
  ///
  /// Returns:
  ///     Duration: [standards] times [Motion.standard], or [Duration.zero]
  ///     with animations off, which is what makes [CompanionMark] start no
  ///     ticker at all.
  static Duration of(BuildContext context) =>
      Motion.standard(context) * standards;

  /// How much larger the mark gets at the top of a breath.
  ///
  /// Small on purpose. This sits beside four navigation destinations and is
  /// visible on every screen in the app; anything that reads as movement in
  /// peripheral vision would be a thing to be irritated by rather than a thing
  /// to be fond of.
  static const double swell = 0.06;

  /// Peak opacity of the halo drawn around the mark.
  static const double haloAlpha = 0.24;
}

/// The companion's art: a crescent that breathes (AND-37).
///
/// Drawn rather than iconised, because the charm of this feature has to come
/// from the art and the motion. `docs/PLAN.md` 6.3 rules out the shortcut of
/// getting it from the words instead.
///
/// **The idle animation stops in two situations, and neither is optional.**
/// With `MediaQuery.disableAnimationsOf` set (Android's "remove animations",
/// iOS's reduce motion) [CompanionBreath.of] is zero, no ticker is created,
/// and the mark is simply drawn at rest. And when the app leaves the
/// foreground the controller is stopped rather than left ticking against a
/// surface nobody can see.
class CompanionMark extends StatefulWidget {
  /// Creates the mark.
  const CompanionMark({super.key});

  @override
  State<CompanionMark> createState() => _CompanionMarkState();
}

/// State for [CompanionMark]: when the breath runs, and when it must not.
///
/// Observes the app lifecycle as well as the media query, because the two
/// reasons to stop are independent: the device may have animations on while
/// the app is behind the recent-apps switcher.
///
/// Attributes:
///     _controller (AnimationController): One half-breath, repeated in
///         reverse.
///     _foreground (bool): Whether the app is resumed.
class _CompanionMarkState extends State<CompanionMark>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// One half-breath, repeated in reverse for as long as it should run.
  late final AnimationController _controller = AnimationController(vsync: this);

  /// Whether the app is resumed. Anything else stops the breath.
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only `resumed` counts as running. `inactive` is the state an app is in
    // behind the recent-apps switcher and behind the system credential prompt
    // this app's lock puts up, and animating underneath either of those spends
    // battery on frames nobody sees.
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _sync();
  }

  /// Start, stop or retime the breath to match the current conditions.
  ///
  /// Called from both triggers rather than duplicated at each, so there is one
  /// place that decides whether the ticker should be running. Stopping also
  /// resets the value to 0, which is the resting frame: a mark frozen
  /// mid-breath would be drawn slightly swollen for as long as it stayed
  /// there.
  void _sync() {
    final breath = CompanionBreath.of(context);
    if (breath == Duration.zero || !_foreground) {
      _controller
        ..stop()
        ..value = 0;
      return;
    }
    _controller.duration = breath;
    if (!_controller.isAnimating) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _CrescentPainter(
          // Curved rather than linear so the top and the bottom of the breath
          // are the parts it lingers on, which is what makes it read as
          // breathing instead of as a pulse.
          breath: Curves.easeInOut.transform(_controller.value),
          ink: scheme.secondary,
        ),
      ),
    );
  }
}

/// Paints the crescent and its halo at a point in the breath.
///
/// Attributes:
///     breath (double): 0 at rest, 1 at the top of a breath.
///     ink (Color): The colour of the mark.
class _CrescentPainter extends CustomPainter {
  /// Creates the painter.
  ///
  /// Args:
  ///     breath (double): 0 at rest, 1 at the top of a breath. Already eased
  ///         by the caller, so this is a position and not a time.
  ///     ink (Color): The colour of the mark. The halo is the same colour at
  ///         [CompanionBreath.haloAlpha] times [breath], so it is invisible
  ///         at rest.
  const _CrescentPainter({required this.breath, required this.ink});

  /// 0 at rest, 1 at the top of a breath.
  final double breath;

  /// The colour of the mark.
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius =
        math.min(size.width, size.height) /
        2 *
        0.74 *
        (1 + CompanionBreath.swell * breath);

    canvas.drawCircle(
      centre,
      radius * 1.26,
      Paint()
        ..color = ink.withValues(alpha: CompanionBreath.haloAlpha * breath)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // A disc with a second disc taken out of it, rather than an arc with a
    // stroke: the shape stays a solid silhouette at any size, which is what
    // survives being 24 logical pixels tall next to four navigation labels.
    final disc = Path()
      ..addOval(Rect.fromCircle(center: centre, radius: radius));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: centre.translate(radius * 0.46, -radius * 0.30),
          radius: radius * 0.88,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, disc, bite),
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(_CrescentPainter oldDelegate) =>
      oldDelegate.breath != breath || oldDelegate.ink != ink;
}
