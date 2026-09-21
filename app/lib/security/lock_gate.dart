/// The lock gate widget.
///
/// Wraps the whole app shell and hides it until the device credential has been
/// offered. Encrypts nothing; it decides what is on screen.
///
/// Includes:
///     - LockGate: The wrapper, which owns the controller's lifecycle.
///     - _LockScreen: What is shown while locked, deliberately anonymous.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:period_tracker/data/repositories/providers.dart';
import 'package:period_tracker/l10n/app_localizations.dart';
import 'package:period_tracker/security/lock_controller.dart';

/// Lock gate: hides the app until the device credential is offered (AND-29).
///
/// Wraps the whole shell rather than individual screens, which is the answer
/// to the only question this feature really has: what counts as protected?
/// Gating a screen at a time leaves the answer to whoever adds the next
/// screen, and they will forget one, probably the calendar, which shows a
/// month of period dates at a glance.
///
/// **It hides the interface and encrypts nothing.** The database is
/// unencrypted in app-private storage (ADR-0004), so anyone with physical
/// access, root or a debug bridge reads it whether this is on or off.
/// `PRIVACY.md` says exactly that, and so does the line under the settings
/// toggle, because a lock a user mistakes for encryption is worse than no lock
/// at all: it buys a false sense of safety for a few taps.
///
/// Attributes:
///     child (Widget): The app shell, shown once unlocked.
class LockGate extends ConsumerStatefulWidget {
  /// Wraps [child] behind the lock.
  ///
  /// Args:
  ///     child (Widget): The app shell.
  const LockGate({required this.child, super.key});

  /// The app shell.
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

/// State for [LockGate]. Starts the controller after the first frame.
class _LockGateState extends ConsumerState<LockGate> {
  @override
  void initState() {
    super.initState();
    // Started after the first frame, because the prompt is platform UI and
    // showing it from initState races the engine's attach on a cold start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Not awaited: nothing here waits on the result, and the controller
      // reports through notifyListeners rather than through this future.
      unawaited(ref.read(lockControllerProvider).start());
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(lockControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isOpen) return widget.child;
        return _LockScreen(
          busy: controller.state == AppLockState.unlocking,
          onUnlock: controller.unlock,
        );
      },
    );
  }
}

/// What is shown instead of the app.
///
/// Deliberately says nothing about what the app is for. This is what a person
/// looking over a shoulder sees, and a lock screen reading "Period Tracker,
/// unlock to see your cycle" would leak the one fact the lock exists to keep.
///
/// Attributes:
///     busy (bool): Whether a prompt is already up.
///     onUnlock (`Future<void> Function()`): Asks for the credential.
class _LockScreen extends StatelessWidget {
  /// Creates the lock screen.
  ///
  /// Args:
  ///     busy (bool): Whether a prompt is already up.
  ///     onUnlock (`Future<void> Function()`): Asks for the credential.
  const _LockScreen({required this.busy, required this.onUnlock});

  /// Whether a prompt is already up, which disables the button.
  final bool busy;

  /// Asks for the credential.
  final Future<void> Function() onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(l10n.lockTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(l10n.lockBody, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                // Always offered, even while a prompt is up. A dismissed
                // system prompt leaves the app locked with nothing to tap,
                // which reads as a frozen app rather than a locked one.
                FilledButton.icon(
                  onPressed: busy ? null : onUnlock,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: Text(l10n.lockAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
