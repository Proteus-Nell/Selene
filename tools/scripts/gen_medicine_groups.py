#!/usr/bin/env python3
"""Generate the interaction checker's group names from their sourced table.

Labels often name other medicines only by a group: tranexamic acid's
contraindicates "combined hormonal contraceptives", and a naproxen label warns
about "SSRIs". The interaction checker matches what labels print (ADR-0014),
and a group's name says nothing about which drugs are in it. So
`artifacts/medicines/groups_v1.json` says, group by group, from the source each
row cites: the FDA's own drug classes, its lists, and the drugs' own approved
labels (ADR-0021). Nothing in it is a judgement of this project's.

This script resolves that table against the committed medicines bundle, and
writes what the app needs: each group's phrases and the drugs it covers, and
what each recorded kind of contraception counts as. It reads only files in the
repository, so it needs no network, and neither does the phone.

Pipeline:
    1. Read the table, and check it is well formed.
    2. Read the bundle's index and label text.
    3. Resolve every group's members, and every condition's kind, to drugs.
    4. Check the table against the bundle: every member it names is a drug the
       bundle has, every phrase is printed on some label, and so on. A table
       that has drifted from the bundle fails here rather than matching
       nothing in silence.
    5. Render `app/lib/data/reference/medicine_groups_bundled.dart`.

Usage:
    python3 tools/scripts/gen_medicine_groups.py           # regenerate the Dart
    python3 tools/scripts/gen_medicine_groups.py --check   # CI gate, writes nothing
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TABLE = REPO_ROOT / "artifacts" / "medicines" / "groups_v1.json"
BUNDLE = REPO_ROOT / "app" / "assets" / "medicines"
OUTPUT = REPO_ROOT / "app" / "lib" / "data" / "reference" / "medicine_groups_bundled.dart"
INDEX_NAME = "index.json.zlib"
CHUNK_GLOB = "labels-*.jsonl.zlib"

TABLE_SCHEMA_VERSION = 1
# The resolved table the app reads. Its own version, so that a change in its
# shape is a change the Dart has to be told about.
OUTPUT_SCHEMA_VERSION = 1

# The sections a mention is looked for in: interactions.dart's
# `mentionSections`. A phrase no label prints in any of them can never match.
MENTION_SECTIONS: tuple[str, ...] = (
    "drug_interactions",
    "ask_doctor_or_pharmacist",
    "do_not_use",
    "contraindications",
    "boxed_warning",
    "warnings_and_cautions",
    "warnings",
    "precautions",
    "ask_doctor",
    "when_using",
    "stop_use",
)
# Where a drug's label says what it is for: the professional label's
# indications, or the Drug Facts purpose and uses.
USE_SECTIONS: tuple[str, ...] = ("indications_and_usage", "purpose")

CONTRACEPTIVE_KINDS = frozenset({"any", "combined", "progestin-only"})
SELECTOR_KEYS = frozenset({"source", "class", "substances", "absent", "routes", "contraceptive"})
# The conditions a recorded kind of contraception can be: condition.dart's
# wire names. Only those whose products the bundle carries.
CONDITIONS = frozenset(
    {
        "hormonalContraceptionCombined",
        "hormonalContraceptionProgestogen",
        "hormonalIud",
        "contraceptiveImplant",
    }
)


def words(text: str) -> tuple[str, ...]:
    """Split a name into its lower-case words, dropping everything else.

    Args:
        text (str): A name: "NAPROXEN SODIUM", "estrogens, conjugated".

    Returns:
        `tuple[str, ...]`: `("naproxen", "sodium")`. Labels print a name with
        any punctuation and any capitals, so only the words are compared.
    """
    return tuple(re.findall(r"[a-z0-9]+", text.lower()))


def phrase_pattern(phrase: str) -> re.Pattern[str]:
    """Return the pattern that finds a group's phrase, as the app's does.

    The words in order, anything but a letter or digit between them, neither
    either side, and a plural allowed: interactions.dart's `_Name`.

    Args:
        phrase (str): The phrase, as the table writes it.

    Returns:
        `re.Pattern[str]`: The case-insensitive pattern.
    """
    body = r"[^A-Za-z0-9]+".join(map(re.escape, words(phrase)))
    return re.compile(rf"(?<![A-Za-z0-9]){body}(?:s|es)?(?![A-Za-z0-9])", re.IGNORECASE)


def read_bundle(directory: Path) -> tuple[dict, dict[str, dict[str, str]]]:
    """Read the medicines bundle the app ships: its index and its label text.

    Args:
        directory (Path): `app/assets/medicines`.

    Returns:
        `tuple[dict, dict[str, dict[str, str]]]`: The index, and each drug's
        sections by key, as {section name: text}.
    """
    index = json.loads(zlib.decompress((directory / INDEX_NAME).read_bytes()))
    sections: dict[str, dict[str, str]] = {}
    for chunk in sorted(directory.glob(CHUNK_GLOB)):
        for line in zlib.decompress(chunk.read_bytes()).decode().splitlines():
            record = json.loads(line)
            sections[record["key"]] = dict(record["sections"])
    return index, sections


def bundle_digest(directory: Path) -> str:
    """Return the bundle's checksum, as gen_medicines.py computes it.

    The app's `medicinesBundleSha256`. Recorded beside the groups, so that a
    test can tell when the bundle has been rebuilt and the groups have not.

    Args:
        directory (Path): `app/assets/medicines`.

    Returns:
        str: The hex SHA-256 over every file's name, length and contents.
    """
    digest = hashlib.sha256()
    for path in [directory / INDEX_NAME, *sorted(directory.glob(CHUNK_GLOB))]:
        content = path.read_bytes()
        digest.update(f"{path.name}\0{len(content)}\0".encode())
        digest.update(content)
    return digest.hexdigest()


def table_problems(table: dict) -> list[str]:
    """Check the table's shape, before anything is resolved.

    Args:
        table (dict): The parsed table.

    Returns:
        `list[str]`: What is wrong. Empty for a well-formed table.
    """
    if table.get("schema_version") != TABLE_SCHEMA_VERSION:
        return [f"schema_version is not {TABLE_SCHEMA_VERSION}"]
    problems = []
    sources = table.get("sources", {})
    for key, source in sources.items():
        for field in ("title", "publisher", "url", "retrieved"):
            if not isinstance(source.get(field), str) or not source[field]:
                problems.append(f"source {key} has no {field}")
        if not str(source.get("url", "")).startswith("https://"):
            problems.append(f"source {key}'s url is not https")
    used = set()

    def selector(where: str, rule: dict, *, member: bool) -> None:
        unknown = set(rule) - SELECTOR_KEYS
        if unknown:
            problems.append(f"{where} has unknown fields {sorted(unknown)}")
        if member:
            if rule.get("source") not in sources:
                problems.append(f"{where} cites no source the table lists")
            used.add(rule.get("source"))
        kind = rule.get("contraceptive")
        if kind is not None and kind not in CONTRACEPTIVE_KINDS:
            problems.append(f"{where} has contraceptive {kind!r}")
        if not rule.get("substances") and kind is None:
            problems.append(f"{where} names no substances and no contraceptive kind")
        for name in [*rule.get("substances", []), *rule.get("absent", [])]:
            if not words(name):
                problems.append(f"{where} names a substance with no words in it")

    contraception = table.get("contraception", {})
    try:
        re.compile(contraception.get("indication", ""))
    except re.error as error:
        problems.append(f"the contraceptive indication is not a pattern: {error}")
    if not contraception.get("indication"):
        problems.append("the contraceptive indication is empty")
    for part in ("estrogens", "progestins"):
        if not contraception.get(part):
            problems.append(f"contraception lists no {part}")
        for i, rule in enumerate(contraception.get(part, [])):
            selector(f"contraception {part} {i}", rule, member=True)

    names = set()
    phrases: dict[tuple[str, ...], str] = {}
    for group in table.get("groups", []):
        name = group.get("name")
        if not isinstance(name, str) or not name:
            problems.append("a group has no name")
            continue
        if name in names:
            problems.append(f"two groups are called {name}")
        names.add(name)
        if not group.get("phrases"):
            problems.append(f"{name} has no phrases")
        for phrase in group.get("phrases", []):
            key = words(phrase)
            if not key:
                problems.append(f"{name} has a phrase with no words in it")
            elif key in phrases:
                problems.append(f"{name} and {phrases[key]} share the phrase {phrase!r}")
            else:
                phrases[key] = name
        if not group.get("members"):
            problems.append(f"{name} has no members")
        for i, rule in enumerate(group.get("members", [])):
            selector(f"{name} member {i}", rule, member=True)

    seen = set()
    for row in table.get("conditions", []):
        condition = row.get("condition")
        if condition not in CONDITIONS:
            problems.append(f"{condition!r} is not a condition this table can map")
        if condition in seen:
            problems.append(f"{condition} is mapped twice")
        seen.add(condition)
        if row.get("source") not in sources:
            problems.append(f"{condition} cites no source the table lists")
        used.add(row.get("source"))
        selector(f"{condition} kind", row.get("kind", {}), member=False)

    for key in sorted(set(sources) - used):
        problems.append(f"source {key} is cited by nothing")
    return problems


class Resolver:
    """Match the table's rules against the bundle's drugs.

    Attributes:
        entries (`list[dict]`): The bundle's index rows.
        sections (`dict[str, dict[str, str]]`): Each drug's label, by key.
        indication (`re.Pattern[str]`): What a contraceptive's uses say.
        estrogens (`list[tuple[str, ...]]`): The estrogens, as words.
        progestins (`list[tuple[str, ...]]`): The progestins, as words.
    """

    def __init__(self, table: dict, entries: list[dict], sections: dict[str, dict[str, str]]):
        """Prepare to resolve the table's rules.

        Args:
            table (dict): The parsed table.
            entries (`list[dict]`): The bundle's index rows.
            sections (`dict[str, dict[str, str]]`): Each drug's label, by key.
        """
        self.entries = entries
        self.sections = sections
        contraception = table["contraception"]
        self.indication = re.compile(contraception["indication"], re.IGNORECASE)
        self.estrogens = [
            words(name) for rule in contraception["estrogens"] for name in rule["substances"]
        ]
        self.progestins = [
            words(name) for rule in contraception["progestins"] for name in rule["substances"]
        ]
        # Worked out once: every rule is tried against every drug.
        self._substances = {
            entry["key"]: [words(substance) for substance in entry["substances"]]
            for entry in entries
        }
        self._contraceptive: dict[str, bool] = {}

    def contains(self, entry: dict, names: list[tuple[str, ...]]) -> bool:
        """Report whether a drug contains one of `names`, in any form.

        A substance is one of them when its words start with that name's:
        "NAPROXEN SODIUM" is naproxen, and "ESTRADIOL VALERATE" estradiol, but
        "ETHINYL ESTRADIOL" is not estradiol.

        Args:
            entry (dict): An index row.
            names (`list[tuple[str, ...]]`): The names, as words.

        Returns:
            bool: Whether any of its substances is one of them.
        """
        return any(
            have[: len(name)] == name for have in self._substances[entry["key"]] for name in names
        )

    def is_contraceptive(self, entry: dict) -> bool:
        """Report whether a drug's own label says it prevents pregnancy.

        Args:
            entry (dict): An index row.

        Returns:
            bool: Whether its indications or Drug Facts purpose say so.
        """
        key = entry["key"]
        if key not in self._contraceptive:
            label = self.sections.get(key, {})
            self._contraceptive[key] = any(
                self.indication.search(label.get(section, "")) for section in USE_SECTIONS
            )
        return self._contraceptive[key]

    def matches(self, rule: dict, entry: dict, names: list[tuple[str, ...]]) -> bool:
        """Report whether a drug meets every part of a rule.

        Args:
            rule (dict): A member or kind rule: substances, routes, and a
                contraceptive kind, each optional and all required.
            entry (dict): An index row.
            names (`list[tuple[str, ...]]`): The rule's substances, as words.

        Returns:
            bool: Whether it meets them all.
        """
        if "substances" in rule and not self.contains(entry, names):
            return False
        if "routes" in rule and not set(rule["routes"]) & set(entry["routes"]):
            return False
        kind = rule.get("contraceptive")
        if kind is not None:
            if not self.is_contraceptive(entry):
                return False
            estrogen = self.contains(entry, self.estrogens)
            progestin = self.contains(entry, self.progestins)
            if kind == "combined" and not estrogen:
                return False
            if kind == "progestin-only" and (estrogen or not progestin):
                return False
            if kind == "any" and not (estrogen or progestin):
                return False
        return True

    def select(self, rule: dict) -> list[str]:
        """Return the keys of every drug that meets a rule, in index order.

        Args:
            rule (dict): A member or kind rule.

        Returns:
            `list[str]`: The keys.
        """
        names = [words(name) for name in rule.get("substances", [])]
        return [entry["key"] for entry in self.entries if self.matches(rule, entry, names)]


def own_names(entry: dict) -> set[str]:
    """Return every name a drug's ingredients go by, as interactions.dart does.

    Its match terms, and its substances' own names in the same form.

    Args:
        entry (dict): An index row.

    Returns:
        `set[str]`: The names, as space-separated lower-case words.
    """
    return {*entry["match"], *(" ".join(words(s)) for s in entry["substances"])} - {""}


def resolve(table: dict, index: dict, sections: dict[str, dict[str, str]]) -> dict:
    """Resolve the table against the bundle into what the app reads.

    Args:
        table (dict): The parsed table.
        index (dict): The bundle's index.
        sections (`dict[str, dict[str, str]]`): Each drug's label, by key.

    Returns:
        dict: Every group with its phrases, members and sources, and every
        condition with the drugs of its kind and what they all share.
    """
    entries = index["entries"]
    resolver = Resolver(table, entries, sections)
    order = {entry["key"]: i for i, entry in enumerate(entries)}
    groups = []
    membership: dict[str, set[str]] = {}
    for group in table["groups"]:
        members: set[str] = set()
        for rule in group["members"]:
            members.update(resolver.select(rule))
        membership[group["name"]] = members
        cited = list(dict.fromkeys(rule["source"] for rule in group["members"]))
        groups.append(
            {
                "name": group["name"],
                "phrases": group["phrases"],
                # The FDA classes its members come from, so that two drugs in
                # the same class are not also told they share the group.
                "classes": sorted({rule["class"] for rule in group["members"] if "class" in rule}),
                "members": sorted(members, key=order.__getitem__),
                "sources": [{"key": key, **table["sources"][key]} for key in cited],
            }
        )

    by_key = {entry["key"]: entry for entry in entries}
    conditions = []
    for row in table["conditions"]:
        kind = resolver.select(row["kind"])
        names = set.intersection(*(own_names(by_key[key]) for key in kind)) if kind else set()
        common = [g["name"] for g in groups if kind and set(kind) <= membership[g["name"]]]
        conditions.append(
            {
                "condition": row["condition"],
                "kind": kind,
                "names": sorted(names),
                "groups": common,
                "source": {"key": row["source"], **table["sources"][row["source"]]},
            }
        )
    return {"schema_version": OUTPUT_SCHEMA_VERSION, "groups": groups, "conditions": conditions}


def bundle_problems(table: dict, index: dict, sections: dict[str, dict[str, str]]) -> list[str]:
    """Check the table against the bundle it is resolved with.

    Args:
        table (dict): The parsed, well-formed table.
        index (dict): The bundle's index.
        sections (`dict[str, dict[str, str]]`): Each drug's label, by key.

    Returns:
        `list[str]`: What is wrong. Empty when every name the table gives
        resolves to what it says, and every phrase can be found.
    """
    entries = index["entries"]
    resolver = Resolver(table, entries, sections)
    problems = []

    def check_names(where: str, rule: dict) -> None:
        # A name the source gives that no drug here contains is either a typo
        # or a drug the bundle does not carry, and only the second is allowed,
        # under "absent", where the next refresh will notice it arriving.
        routed = {k: v for k, v in rule.items() if k == "routes"}
        for name in rule.get("substances", []):
            if not resolver.select({"substances": [name], **routed}):
                problems.append(f"{where}: no drug contains {name!r}")
        for name in rule.get("absent", []):
            if resolver.select({"substances": [name]}):
                problems.append(f"{where}: {name!r} is listed absent, and a drug contains it")

    for part in ("estrogens", "progestins"):
        for i, rule in enumerate(table["contraception"][part]):
            check_names(f"contraception {part} {i}", rule)

    # Lower-cased, so that a phrase's first word can rule out most labels
    # before its pattern is tried on any.
    text = [
        "\n".join(label.get(section, "") for section in MENTION_SECTIONS).lower()
        for label in sections.values()
    ]
    classes = {name for entry in entries for name in entry["classes"]}
    for group in table["groups"]:
        for i, rule in enumerate(group["members"]):
            check_names(f"{group['name']} member {i}", rule)
            if not resolver.select(rule):
                problems.append(f"{group['name']} member {i} covers no drug")
            if "class" in rule and rule["class"] not in classes:
                problems.append(f"{group['name']} member {i}: no drug is in {rule['class']!r}")
        for phrase in group["phrases"]:
            pattern = phrase_pattern(phrase)
            first = words(phrase)[0]
            if not any(first in label and pattern.search(label) for label in text):
                problems.append(f"{group['name']}: no label prints {phrase!r}")

    for row in table["conditions"]:
        check_names(f"{row['condition']} kind", row["kind"])
        if not resolver.select(row["kind"]):
            problems.append(f"{row['condition']}: no drug is of its kind")
    return problems


def render(resolved: dict, digest: str) -> str:
    """Return the full text of the generated Dart file.

    The resolved table goes in as JSON in a raw string, which `dart format`
    leaves as it is: the `--check` gate compares this file byte for byte with
    a fresh render, and code the formatter rewrote would never match.

    Args:
        resolved (dict): From `resolve`.
        digest (str): The bundle's checksum, from `bundle_digest`.

    Returns:
        str: The file's full text.
    """
    body = json.dumps(resolved, indent=1, ensure_ascii=False)
    if "'''" in body:
        raise SystemExit("error: the resolved table contains ''', which ends a raw string")
    return f"""// GENERATED BY tools/scripts/gen_medicine_groups.py. DO NOT EDIT BY HAND.
//
// Regenerate with:
//     python3 tools/scripts/gen_medicine_groups.py
//
// From artifacts/medicines/groups_v1.json, resolved against the medicines
// bundle in app/assets/medicines. ADR-0021.

/// Bundled group names: the sourced table, resolved against the bundle.
///
/// Read by `medicine_groups.dart`, which is what the rest of the app uses.
///
/// Includes:
///     - medicineGroupsBundleSha256: The bundle these were resolved against.
///     - medicineGroupsJson: The groups, their members and their sources.
library;

/// `medicinesBundleSha256` of the bundle the groups were resolved against.
///
/// A test compares the two, so a rebuilt bundle whose groups nobody
/// regenerated fails the build rather than matching drugs that have moved.
const String medicineGroupsBundleSha256 =
    '{digest}';

/// The groups, as JSON: each with its phrases, the keys of the drugs it
/// covers, and its sources; and each recorded kind of contraception with the
/// drugs of that kind and what they all share.
const String medicineGroupsJson = r'''
{body}
''';
"""


def main() -> int:
    """Run the generator from the command line.

    Returns:
        int: 0 on success, and 1 when the table is malformed, disagrees with
        the bundle, or `--check` finds the Dart stale.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if the table disagrees with the bundle or the Dart is stale",
    )
    args = parser.parse_args()

    table = json.loads(TABLE.read_text(encoding="utf-8"))
    problems = table_problems(table)
    if not problems:
        index, sections = read_bundle(BUNDLE)
        problems = bundle_problems(table, index, sections)
    for problem in problems:
        print(f"error: {TABLE.relative_to(REPO_ROOT)}: {problem}.", file=sys.stderr)
    if problems:
        return 1

    generated = render(resolve(table, index, sections), bundle_digest(BUNDLE))
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != generated:
            print(
                f"error: {OUTPUT.relative_to(REPO_ROOT)} is stale. Run "
                "`python3 tools/scripts/gen_medicine_groups.py` and commit the result.",
                file=sys.stderr,
            )
            return 1
        print(f"OK: the group table, the bundle and {OUTPUT.name} agree")
        return 0

    OUTPUT.write_text(generated, encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
