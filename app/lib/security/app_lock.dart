import 'package:local_auth/local_auth.dart';
import 'package:meta/meta.dart';

/// Why the app lock cannot be turned on.
enum LockUnavailableReason {
  /// The device has no PIN, pattern, passcode or enrolled biometric.
  ///
  /// The common case, and the one worth explaining rather than greying out a
  /// switch: the app lock delegates entirely to the device's own credential,
  /// so there is nothing for it to ask for. The fix is in the system settings,
  /// not in this app, and saying so is the difference between a user enabling
  /// a screen lock and concluding the feature is broken.
  noCredentialEnrolled,

  /// The platform cannot authenticate at all.
  notSupported,
}

/// The outcome of an unlock attempt.
enum UnlockOutcome {
  /// The user proved who they are.
  granted,

  /// The user failed or dismissed the prompt. Not an error.
  refused,

  /// The device stopped being able to authenticate.
  ///
  /// Reached when a credential is removed while the lock is on. Treated as a
  /// [granted]-equivalent by the gate, deliberately — see [AppLockService].
  unavailable,
}

/// Maps a `local_auth` failure code to what the gate should do about it.
///
/// Lifted out of [LocalAuthService.unlock] so it can be asserted directly:
/// every branch here is a decision about whether someone gets into their own
/// diary, and the alternative is a test that has to fake a platform channel to
/// reach a `switch`. `app_lock_test.dart` walks the whole enum.
@visibleForTesting
UnlockOutcome unlockOutcomeFor(LocalAuthExceptionCode code) =>
    // Listed exhaustively rather than with a `_` wildcard, deliberately. A new
    // code added by the plugin would fall into the wildcard silently, and
    // "silently" here means either sealing the user out of their own diary or
    // letting anyone in — the two failure modes this feature has. Breaking the
    // build is the correct response to an unlock outcome nobody has classified
    // yet.
    switch (code) {
      // The credential was removed while the lock was on. Reported as
      // unavailable so the gate can let the user in rather than sealing them
      // out of their own diary with no way to prove anything.
      LocalAuthExceptionCode.noCredentialsSet ||
      // The platform cannot show a prompt at all. On Android this is either a
      // transient no-Activity state, or — the case that actually bit — a
      // MainActivity that is not a FragmentActivity, which BiometricPrompt
      // needs. That second one is permanent for the whole build.
      //
      // Treated as unavailable rather than refused, because refusing here
      // strands the user: they tap Unlock, nothing appears, and there is no way
      // into their own diary ever again. The data is unencrypted on disk either
      // way (ADR-0008), so a lock that cannot function has protected nothing
      // and would have cost them everything.
      //
      // This is a fallback for a state that should not exist, not a tolerated
      // one: MainActivity.kt is the fix, and main_activity_test.dart fails the
      // build if it reverts.
      LocalAuthExceptionCode.uiUnavailable => UnlockOutcome.unavailable,
      // Not treated as unavailable: with a device credential as fallback,
      // missing or unenrolled biometrics still leave a PIN to fall back on, and
      // letting the user straight in because their fingerprint sensor broke
      // would be a way around the lock rather than a graceful degradation of
      // it.
      LocalAuthExceptionCode.noBiometricHardware ||
      LocalAuthExceptionCode.noBiometricsEnrolled ||
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
      LocalAuthExceptionCode.temporaryLockout ||
      LocalAuthExceptionCode.biometricLockout ||
      LocalAuthExceptionCode.userCanceled ||
      LocalAuthExceptionCode.timeout ||
      LocalAuthExceptionCode.systemCanceled ||
      LocalAuthExceptionCode.authInProgress ||
      LocalAuthExceptionCode.userRequestedFallback ||
      LocalAuthExceptionCode.deviceError ||
      LocalAuthExceptionCode.unknownError => UnlockOutcome.refused,
    };

/// Asks the device to prove who is holding it.
///
/// An interface rather than a direct `LocalAuthentication` call so the gate can
/// be tested without a platform channel. Every test in this app runs headless
/// in `flutter test`, and a lock that could only be exercised on a device is a
/// lock whose failure modes are never exercised at all.
abstract interface class AppLockService {
  /// Whether the device can authenticate, and if not, why.
  ///
  /// Returns null when the lock can be used.
  Future<LockUnavailableReason?> unavailableReason();

  /// Prompts for the device credential.
  ///
  /// [reason] is shown by the system prompt and must not be empty.
  Future<UnlockOutcome> unlock(String reason);
}

/// The real thing, over `local_auth`.
///
/// **This gates the interface. It does not encrypt anything.** The database is
/// unencrypted in app-private storage (ADR-0004), and anyone with physical
/// access, root, or a debug bridge can read it whether or not this is on.
/// `PRIVACY.md` says so in those words, because a lock a user mistakes for
/// encryption is worse than no lock: it buys a false sense of safety at the
/// price of a few taps.
///
/// What it does buy is real and worth having: the screen is not readable by
/// someone who picks the phone up, which is the threat model most users of a
/// period tracker actually have.
@immutable
final class LocalAuthService implements AppLockService {
  /// Creates the service over [auth].
  const LocalAuthService({LocalAuthentication? auth})
    // An initializing formal would have to be `this._auth`, and Dart does not
    // allow a named parameter to start with an underscore.
    // ignore: prefer_initializing_formals
    : _auth = auth;

  final LocalAuthentication? _auth;

  LocalAuthentication get _local => _auth ?? LocalAuthentication();

  @override
  Future<LockUnavailableReason?> unavailableReason() async {
    try {
      // isDeviceSupported covers biometrics *or* a device credential, which is
      // the fallback this app wants: requiring a fingerprint would exclude
      // anyone whose sensor has stopped working, and they still have a PIN.
      final supported = await _local.isDeviceSupported();
      if (!supported) return LockUnavailableReason.noCredentialEnrolled;
      return null;
    } on Object {
      // A platform that throws here cannot authenticate, and the honest report
      // is that the feature is unavailable rather than that the device has no
      // credential — the user would go and set one and it still would not work.
      return LockUnavailableReason.notSupported;
    }
  }

  @override
  Future<UnlockOutcome> unlock(String reason) async {
    try {
      final ok = await _local.authenticate(
        localizedReason: reason,
        // Not biometricOnly: a device credential is a legitimate way in, and
        // insisting on a fingerprint locks out anyone whose sensor has failed.
        persistAcrossBackgrounding: true,
      );
      return ok ? UnlockOutcome.granted : UnlockOutcome.refused;
    } on LocalAuthException catch (e) {
      return unlockOutcomeFor(e.code);
    } on Object {
      // Anything else is a refusal rather than a crash. Failing open here would
      // defeat the feature; failing hard would leave the user staring at a
      // screen with no way forward.
      return UnlockOutcome.refused;
    }
  }
}
