/// The app's own Flutter binding.
///
/// Exists for one override. Flutter cuts every animation it runs to a
/// twentieth of its length when Android reports "remove animations", and it
/// does so inside `AnimationController`, below anything a widget can reach.
/// Selene decides its movement by its own Reduce animations switch instead
/// (ADR-0029), so the framework has to be told by the app rather than by the
/// phone, and the binding is the only place it asks.
///
/// Includes:
///     - AppBinding: The binding, answering from the app's setting.
///     - setFrameworkAnimationsReduced: How the app tells it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Application binding: the framework's, with the animation flag in the app's
/// hands.
///
/// `SemanticsBinding.disableAnimations` is what `AnimationController` consults
/// before every run, and by default it is Android's accessibility flag. Here it
/// is [reduceAnimations] and nothing else. That is one half of ADR-0029; the
/// other half is the `MediaQuery` the app root builds, which carries the same
/// value to `Motion`. Both are needed: with only the `MediaQuery` overridden,
/// the tokens would report full durations and the framework would then run
/// them in a single frame.
///
/// Attributes:
///     reduceAnimations (bool): Whether the framework should cut its
///         animations short.
class AppBinding extends WidgetsFlutterBinding {
  /// The one instance, once [ensureInitialized] has made it.
  static AppBinding? _instance;

  /// Whether the framework should cut its animations short.
  ///
  /// False until the app has read its setting, which `buildAppScope` does
  /// before the first frame.
  bool reduceAnimations = false;

  /// Make this the app's binding, unless one already exists.
  ///
  /// A test binding gets there first when the app is started from a test, on
  /// a device or off it, and there can only be one. In that case this does
  /// nothing and the test's binding stays, which is what the test asked for.
  ///
  /// Returns:
  ///     WidgetsBinding: The binding in force, this one or the test's.
  static WidgetsBinding ensureInitialized() {
    // Only a debug build can have had another binding made before main ran,
    // and only a debug build tracks the type, so the check is exact in both.
    if (_instance == null && BindingBase.debugBindingType() == null) {
      AppBinding();
    }
    return WidgetsBinding.instance;
  }

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  /// Whether animations are to be cut short: the app's setting, never the
  /// platform's.
  @override
  bool get disableAnimations => reduceAnimations;
}

/// Tell the framework whether to cut its animations short.
///
/// Does nothing under a binding that is not [AppBinding], which is every
/// widget test: those set the platform's flag on the test binding instead.
///
/// Args:
///     reduced (bool): Whether the Reduce animations switch is on.
void setFrameworkAnimationsReduced({required bool reduced}) {
  final binding = WidgetsBinding.instance;
  if (binding is AppBinding) binding.reduceAnimations = reduced;
}
