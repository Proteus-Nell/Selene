/// Group names: which drugs a label means by "NSAIDs".
///
/// Labels often name other medicines only by a group: tranexamic acid's
/// contraindicates "combined hormonal contraceptives". A group's name says
/// nothing about which drugs are in it, so a sourced table does (ADR-0021):
/// `artifacts/medicines/groups_v1.json`, from the FDA's own classes and lists
/// and the drugs' own labels. The generator resolves it against the medicines
/// bundle into `medicine_groups_bundled.dart`, and this reads that.
///
/// Pure, so it can run in a background isolate and in a plain test.
///
/// Includes:
///     - GroupSource: Where a group's members come from.
///     - MedicineGroup: One group, the phrases it goes by, and its drugs.
///     - ConditionKind: What a recorded kind of contraception counts as.
///     - MedicineGroups: The table.
library;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:period_tracker/data/reference/medicine.dart';
import 'package:period_tracker/data/reference/medicine_groups_bundled.dart';
import 'package:period_tracker/domain/models/condition.dart';

/// The resolved table's format this code reads: the generator's
/// `OUTPUT_SCHEMA_VERSION`.
const int medicineGroupsSchemaVersion = 1;

/// Where some of a group's members come from.
///
/// Attributes:
///     title (String): What the source is, as it titles itself.
///     publisher (String): Who published it.
///     url (String): Where it is.
///     date (String?): When it was published or last revised, `YYYY-MM-DD`.
///     retrieved (String): When it was read for the table, `YYYY-MM-DD`.
///     note (String?): What in it the table relies on, where that is not
///         the whole of it.
@immutable
final class GroupSource {
  /// Creates a source.
  ///
  /// Args:
  ///     title (String): What the source is.
  ///     publisher (String): Who published it.
  ///     url (String): Where it is.
  ///     retrieved (String): When it was read for the table.
  ///     date (String?, optional): When it was published. Defaults to null,
  ///         for a source with no date of its own.
  ///     note (String?, optional): What in it the table relies on. Defaults
  ///         to null.
  const GroupSource({
    required this.title,
    required this.publisher,
    required this.url,
    required this.retrieved,
    this.date,
    this.note,
  });

  /// Read a source from the resolved table.
  factory GroupSource.fromJson(Map<String, Object?> json) => GroupSource(
    title: json['title']! as String,
    publisher: json['publisher']! as String,
    url: json['url']! as String,
    retrieved: json['retrieved']! as String,
    date: json['date'] as String?,
    note: json['note'] as String?,
  );

  /// What the source is, as it titles itself.
  final String title;

  /// Who published it.
  final String publisher;

  /// Where it is. Always https.
  final String url;

  /// When it was published or last revised, or null.
  final String? date;

  /// When it was read for the table.
  final String retrieved;

  /// What in it the table relies on, quoted where it can be: "a selective
  /// serotonin (5-HT) reuptake inhibitor (SSRI)". Null where it is the whole
  /// source, such as an FDA class's list of members.
  final String? note;
}

/// One group name, the phrases a label prints it as, and the drugs it covers.
///
/// Attributes:
///     name (String): How the app names it: "NSAIDs".
///     phrases (`List<String>`): How labels print it, singular.
///     classes (`List<String>`): The FDA classes its members come from.
///     members (`Set<String>`): The keys of the drugs it covers.
///     sources (`List<GroupSource>`): Where its members come from.
@immutable
final class MedicineGroup {
  /// Creates a group.
  ///
  /// Args:
  ///     name (String): How the app names it.
  ///     phrases (`List<String>`): How labels print it, singular.
  ///     members (`Set<String>`): The keys of the drugs it covers.
  ///     classes (`List<String>`, optional): The FDA classes its members come
  ///         from. Defaults to none.
  ///     sources (`List<GroupSource>`, optional): Where its members come
  ///         from. Defaults to none.
  const MedicineGroup({
    required this.name,
    required this.phrases,
    required this.members,
    this.classes = const <String>[],
    this.sources = const <GroupSource>[],
  });

  /// Read a group from the resolved table.
  factory MedicineGroup.fromJson(Map<String, Object?> json) => MedicineGroup(
    name: json['name']! as String,
    phrases: _strings(json['phrases']),
    classes: _strings(json['classes']),
    members: Set<String>.unmodifiable(_strings(json['members'])),
    sources: List<GroupSource>.unmodifiable(<GroupSource>[
      for (final source in json['sources']! as List<Object?>)
        GroupSource.fromJson(source! as Map<String, Object?>),
    ]),
  );

  /// How the app names it, in a sentence: "NSAIDs", "combined hormonal
  /// contraceptives". Plural, as labels use it.
  final String name;

  /// How labels print it, singular: "NSAID", "nonsteroidal
  /// anti-inflammatory drug". A plural is matched too.
  final List<String> phrases;

  /// The FDA classes its members come from, by their names. Two drugs in one
  /// of these are told so already, and are not told they share the group.
  final List<String> classes;

  /// The keys of the drugs it covers, as the bundle names them.
  final Set<String> members;

  /// Where its members come from, in the order the table cites them.
  final List<GroupSource> sources;

  /// Whether [entry] is in the group.
  bool covers(MedicineEntry entry) => members.contains(entry.key);

  @override
  bool operator ==(Object other) =>
      other is MedicineGroup && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'MedicineGroup($name)';
}

/// What a recorded kind of contraception counts as, in the conflict flags.
///
/// A recorded combined pill says which kind of medicine somebody takes, and
/// not which one. So it counts as what every product of that kind in the
/// bundle has in common: the groups they are all in, and the ingredients they
/// all contain (ADR-0021). For the hormonal IUD that is levonorgestrel; for the
/// combined pill it is no one ingredient, since not every pill has ethinyl
/// estradiol.
///
/// Attributes:
///     condition (Condition): The kind of contraception.
///     kind (`Set<String>`): The keys of the products of that kind.
///     names (`List<String>`): The ingredients they all contain, as a label
///         would name them.
///     groups (`List<MedicineGroup>`): The groups they are all in.
///     source (GroupSource): What says which products are of the kind.
@immutable
final class ConditionKind {
  /// Creates what a condition counts as.
  ///
  /// Args:
  ///     condition (Condition): The kind of contraception.
  ///     kind (`Set<String>`): The keys of the products of that kind.
  ///     names (`List<String>`): The ingredients they all contain.
  ///     groups (`List<MedicineGroup>`): The groups they are all in.
  ///     source (GroupSource): What says which products are of the kind.
  const ConditionKind({
    required this.condition,
    required this.kind,
    required this.names,
    required this.groups,
    required this.source,
  });

  /// The kind of contraception.
  final Condition condition;

  /// The keys of the bundle's products of this kind. A recorded medicine
  /// among them is taken to be the one the condition records.
  final Set<String> kind;

  /// The ingredients every product of the kind contains, as lower-case words:
  /// "levonorgestrel". Empty where they share none.
  final List<String> names;

  /// The groups every product of the kind is in.
  final List<MedicineGroup> groups;

  /// What says which products are of the kind.
  final GroupSource source;

  /// Whether [entry] is a product of this kind.
  bool isKind(MedicineEntry entry) => kind.contains(entry.key);
}

/// The group table: every group, and what each kind of contraception counts
/// as.
///
/// Attributes:
///     groups (`List<MedicineGroup>`): The groups, in the table's order.
///     conditions (`Map<Condition, ConditionKind>`): By condition.
@immutable
final class MedicineGroups {
  /// Creates a table.
  ///
  /// Args:
  ///     groups (`List<MedicineGroup>`): The groups.
  ///     conditions (`Map<Condition, ConditionKind>`, optional): What each
  ///         kind of contraception counts as. Defaults to none.
  const MedicineGroups(
    this.groups, {
    this.conditions = const <Condition, ConditionKind>{},
  });

  /// Read the resolved table the generator writes.
  ///
  /// Args:
  ///     source (String): The table, as JSON.
  ///
  /// Returns:
  ///     MedicineGroups: The table.
  ///
  /// Throws:
  ///     FormatException: For a table in a format this code does not read,
  ///         or one naming a condition the app does not have.
  factory MedicineGroups.decode(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    if (json['schema_version'] != medicineGroupsSchemaVersion) {
      throw FormatException(
        'group table schema ${json['schema_version']} is not '
        '$medicineGroupsSchemaVersion',
      );
    }
    final groups = <MedicineGroup>[
      for (final group in json['groups']! as List<Object?>)
        MedicineGroup.fromJson(group! as Map<String, Object?>),
    ];
    final byName = {for (final group in groups) group.name: group};
    final conditions = <Condition, ConditionKind>{};
    for (final row in json['conditions']! as List<Object?>) {
      final map = row! as Map<String, Object?>;
      final name = map['condition']! as String;
      final condition = Condition.values.asNameMap()[name];
      if (condition == null) throw FormatException('unknown condition: $name');
      conditions[condition] = ConditionKind(
        condition: condition,
        kind: Set<String>.unmodifiable(_strings(map['kind'])),
        names: _strings(map['names']),
        groups: List<MedicineGroup>.unmodifiable(<MedicineGroup>[
          for (final group in _strings(map['groups'])) byName[group]!,
        ]),
        source: GroupSource.fromJson(map['source']! as Map<String, Object?>),
      );
    }
    return MedicineGroups(
      List<MedicineGroup>.unmodifiable(groups),
      conditions: Map<Condition, ConditionKind>.unmodifiable(conditions),
    );
  }

  /// No groups at all: label text and FDA classes alone, as before ADR-0021.
  static const MedicineGroups none = MedicineGroups(<MedicineGroup>[]);

  /// The table the app ships, read once per isolate when first used.
  static final MedicineGroups bundled = MedicineGroups.decode(
    medicineGroupsJson,
  );

  /// The groups, in the table's order.
  final List<MedicineGroup> groups;

  /// What each kind of contraception counts as, by condition. A condition
  /// missing here counts as nothing, and takes no part in the flags.
  final Map<Condition, ConditionKind> conditions;

  /// The groups [entry] is in, in the table's order.
  List<MedicineGroup> of(MedicineEntry entry) => <MedicineGroup>[
    for (final group in groups)
      if (group.covers(entry)) group,
  ];
}

List<String> _strings(Object? value) => List<String>.unmodifiable(
  (value as List<Object?>? ?? const <Object?>[]).cast<String>(),
);
