// What the app lock does with each way `local_auth` can fail (AND-33).
//
// Every branch of this mapping is a decision about whether someone gets into
// their own diary, and two of them are decisions in opposite directions:
//
//   * a device whose credential has been removed, or a platform that cannot
//     show a prompt at all, must let the user *in*. The lock delegates
//     entirely to the device credential, so if there is nothing to ask for
//     there is no way to prove anything either, and refusing would mean the
//     diary is gone for good. It is not encrypted (ADR-0008), so a lock that
//     cannot function has protected nothing and would have cost everything.
//
//   * a broken fingerprint sensor must *not*. A device credential is still a
//     way in, and letting someone straight through because the sensor failed
//     would be a way around the lock rather than a graceful degradation.
//
// The mapping is asserted here rather than through the service, because
// reaching that switch through `LocalAuthService` means faking a platform
// channel to throw each code in turn — a lot of machinery between the test and
// the decision it is checking.

import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:period_tracker/security/app_lock.dart';

void main() {
  group('unlockOutcomeFor', () {
    test('never turns a failure into a way in', () {
      // The invariant that holds regardless of how the plugin's enum grows.
      // `granted` is reserved for authenticate() returning true; arriving here
      // at all means the platform reported a failure.
      for (final code in LocalAuthExceptionCode.values) {
        expect(
          unlockOutcomeFor(code),
          isNot(UnlockOutcome.granted),
          reason: '$code is treated as a successful unlock',
        );
      }
    });

    test('does not strand the user when nothing can be asked of them', () {
      // `uiUnavailable` is the one that shipped broken: with a plain
      // FlutterActivity the plugin cannot show BiometricPrompt and reports
      // this, which used to map to `refused`. The user tapped Unlock, saw
      // nothing happen, and had no route into the app at all.
      expect(
        unlockOutcomeFor(LocalAuthExceptionCode.uiUnavailable),
        UnlockOutcome.unavailable,
      );
      expect(
        unlockOutcomeFor(LocalAuthExceptionCode.noCredentialsSet),
        UnlockOutcome.unavailable,
      );
    });

    test('does not let a failed sensor become a way past the lock', () {
      const stillHasAPin = <LocalAuthExceptionCode>[
        LocalAuthExceptionCode.noBiometricHardware,
        LocalAuthExceptionCode.noBiometricsEnrolled,
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
        LocalAuthExceptionCode.biometricLockout,
        LocalAuthExceptionCode.temporaryLockout,
      ];
      for (final code in stillHasAPin) {
        expect(
          unlockOutcomeFor(code),
          UnlockOutcome.refused,
          reason: '$code opened the app without a credential',
        );
      }
    });

    test('treats a cancellation as a refusal, not as a broken lock', () {
      // Backing out of the prompt has to leave the lock on. Reporting these as
      // unavailable would make "press back" the way in.
      const cancelled = <LocalAuthExceptionCode>[
        LocalAuthExceptionCode.userCanceled,
        LocalAuthExceptionCode.systemCanceled,
        LocalAuthExceptionCode.timeout,
        LocalAuthExceptionCode.userRequestedFallback,
      ];
      for (final code in cancelled) {
        expect(unlockOutcomeFor(code), UnlockOutcome.refused, reason: '$code');
      }
    });
  });
}
