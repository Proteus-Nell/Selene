import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:period_tracker/core/clock.dart';
import 'package:period_tracker/security/app_lock.dart';

/// Whether the app is currently showing its contents.
///
/// Named `AppLockState` rather than `LockState` because Flutter's own
/// `LockState` (from `shortcuts.dart`, about keyboard modifiers) is exported by
/// `material.dart`, and the ambiguous import is a compile error in every widget
/// that touches both.
enum AppLockState {
  /// Nothing is shown until the user proves who they are.
  locked,

  /// A prompt is up.
  unlocking,

  /// The app is usable.
  unlocked,
}

/// Decides when the app is locked, and holds the state while it is.
///
/// Two things lock it: a cold start, and coming back from the background after
/// more than [backgroundGrace]. Nothing else — in particular, an ordinary
/// screen rotation or a permission dialog must not, and both of those arrive
/// through the same lifecycle callbacks as a real backgrounding.
///
/// That is what the grace period is for. Android delivers `paused` and
/// `inactive` for a system dialog, a notification shade pull and a task
/// switcher glance, none of which are the user handing their phone to someone.
/// Re-locking on every one of them would make the app unusable — the file
/// picker used by export alone would lock it mid-export — and a lock people
/// turn off is worth less than a lock with a sixty-second window.
///
/// **This gates the interface and encrypts nothing.** See [LocalAuthService].
class LockController extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates a controller over [service].
  LockController({
    required AppLockService service,
    required Clock clock,
    required Future<bool> Function() isEnabled,
  }) : // Initializing formals would have to be `this._service` and the rest,
       // and Dart does not allow a named parameter to start with an
       // underscore. Same as PredictionRepository.
       // ignore: prefer_initializing_formals
       _service = service,
       // ignore: prefer_initializing_formals, same reason as above
       _clock = clock,
       // ignore: prefer_initializing_formals, same reason as above
       _isEnabled = isEnabled;

  /// How long the app may be backgrounded before it locks again.
  ///
  /// Sixty seconds, per the plan. Long enough to answer a message, copy a code
  /// out of another app, or pick a folder in the system file picker; short
  /// enough that a phone left on a table is not left open.
  static const Duration backgroundGrace = Duration(seconds: 60);

  final AppLockService _service;
  final Clock _clock;
  final Future<bool> Function() _isEnabled;

  AppLockState _state = AppLockState.locked;
  DateTime? _backgroundedAt;
  bool _started = false;

  /// The current state.
  AppLockState get state => _state;

  /// Whether the app's contents may be shown.
  bool get isOpen => _state == AppLockState.unlocked;

  /// Establishes the starting state.
  ///
  /// Called once, from the gate's `initState`. When the lock is off this
  /// unlocks immediately and the gate never renders — an app whose lock is
  /// disabled must not flash a lock screen on every launch.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    if (!await _isEnabled()) {
      _set(AppLockState.unlocked);
      return;
    }
    await unlock();
  }

  /// Prompts for the device credential.
  ///
  /// Safe to call while a prompt is already up: the second call returns without
  /// starting another. Two overlapping BiometricPrompts is a platform error on
  /// Android, and the paths that can race here — a lifecycle event arriving
  /// while the first prompt is open, and the user tapping "unlock" again — are
  /// both ordinary.
  Future<void> unlock() async {
    if (_state == AppLockState.unlocking) return;
    _set(AppLockState.unlocking);

    final outcome = await _service.unlock('Unlock to see your diary');
    switch (outcome) {
      case UnlockOutcome.granted:
      case UnlockOutcome.unavailable:
        // unavailable means the device credential was removed while the lock
        // was on. Letting the user in is the only humane answer: the
        // alternative is a diary nobody can open, with the data still sitting
        // unencrypted on disk, so the lock would have cost them everything and
        // protected nothing.
        _set(AppLockState.unlocked);
      case UnlockOutcome.refused:
        _set(AppLockState.locked);
    }
  }

  /// Locks immediately, for the settings toggle being turned on.
  void lock() => _set(AppLockState.locked);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Recorded, not acted on. Whether this counts is decided on the way
        // back, when the elapsed time is known.
        _backgroundedAt ??= _clock.nowUtc();
      case AppLifecycleState.resumed:
        // Not awaited: the framework's callback is synchronous, and the work
        // this kicks off ends in notifyListeners() rather than in a value
        // anyone is waiting for.
        unawaited(_onResumed());
      case AppLifecycleState.inactive:
        // Deliberately ignored. `inactive` arrives for a notification shade
        // pull, an incoming call banner and the app switcher preview, none of
        // which mean the phone left the user's hand.
        break;
    }
  }

  Future<void> _onResumed() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;
    if (!await _isEnabled()) return;
    if (_state != AppLockState.unlocked) return;
    // Strictly less than: exactly [backgroundGrace] locks. "After 60 seconds"
    // leaves the boundary ambiguous, and for a privacy feature the ambiguity
    // resolves towards locking. lock_controller_test.dart pins both sides.
    if (_clock.nowUtc().difference(since) < backgroundGrace) return;
    _set(AppLockState.locked);
    await unlock();
  }

  void _set(AppLockState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
