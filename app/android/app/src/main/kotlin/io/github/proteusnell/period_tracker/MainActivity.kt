package io.github.proteusnell.period_tracker

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * FlutterFragmentActivity, not FlutterActivity, and the app lock depends on it.
 *
 * `local_auth` shows Android's BiometricPrompt, which is a fragment and needs a
 * `FragmentActivity` to attach to. With a plain `FlutterActivity` the plugin
 * returns NOT_FRAGMENT_ACTIVITY, which surfaces in Dart as `uiUnavailable` —
 * so `authenticate()` returns without ever showing anything, and the unlock
 * screen looks like a dead button.
 *
 * Nothing fails at build time and nothing fails on a device without the lock
 * turned on, which is why this went unnoticed: the settings toggle enables
 * fine, because `isDeviceSupported()` only asks whether the device has a
 * credential and never checks the activity type.
 *
 * `main_activity_test.dart` fails the build if this reverts.
 */
class MainActivity : FlutterFragmentActivity()
