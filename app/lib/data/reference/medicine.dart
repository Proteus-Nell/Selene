import 'package:meta/meta.dart';

/// One medicine's reference entry, as it appears in the app.
///
/// Compiled in from `artifacts/medicines/medicines_v1.json` by
/// `tools/scripts/gen_medicines.py`. **The phone never fetches any of it** —
/// the app has no `INTERNET` permission at all, and `assert_no_network.sh`
/// fails the build if that ever changes (ADR-0004, ADR-0009).
///
/// Everything here is a warning or a "what is this for". There is deliberately
/// **no dosing**: the labelling is US, and a dose read off a US label and
/// applied to a box bought elsewhere is the specific harm this feature exists
/// to avoid rather than cause.
@immutable
final class Medicine {
  /// Creates an entry.
  const Medicine({
    required this.key,
    required this.genericName,
    required this.brandNames,
    required this.sections,
  });

  /// Stable identifier. Never shown; used to find an entry from code.
  final String key;

  /// The generic name openFDA was queried by.
  final String genericName;

  /// Brand names from the label, capped — a label can carry dozens, and a
  /// screen listing all of them is a screen nobody reads.
  final List<String> brandNames;

  /// Label sections, keyed by openFDA's own field names.
  ///
  /// A map rather than named fields because which sections a label carries
  /// varies by medicine, and a fixed set of nullable fields would turn every
  /// absence into a decision about whether it mattered. The screen renders
  /// whatever is present, in a fixed order.
  final Map<String, String> sections;

  @override
  bool operator ==(Object other) =>
      other is Medicine && other.key == key && other.genericName == genericName;

  @override
  int get hashCode => Object.hash(key, genericName);

  @override
  String toString() => 'Medicine($key, ${sections.length} sections)';
}
