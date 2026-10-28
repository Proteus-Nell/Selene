package io.github.proteusnell.period_tracker

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

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
class MainActivity : FlutterFragmentActivity() {
    /**
     * Answers one question from Dart: which time zone the phone is set to.
     *
     * A medicine reminder repeats every day at the same time on the clock in
     * the zone it was scheduled in, so it needs the phone's own zone by name
     * to stay at its time when the clocks change (ADR-0025). Dart can read the
     * zone's offset but not its name, and no plugin the app already has asks.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.proteusnell.period_tracker/time_zone",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "name" -> result.success(TimeZone.getDefault().id)
                else -> result.notImplemented()
            }
        }
    }
}
