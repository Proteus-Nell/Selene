#!/usr/bin/env python3
"""Generate the medicines artifact and its Dart mirror (task AND-31).

The app shows reference information about a small allowlist of medicines that
come up around menstrual cycles. It does that **with no network permission at
all**: the data is fetched here, on a developer machine or in CI, committed as
`artifacts/medicines/medicines_v1.json`, and compiled into the app as Dart
constants. The phone never makes a request, and `assert_no_network.sh` fails the
build if it ever could (ADR-0004, ADR-0009).

This is the same shape as `gen_priors_dart.py`, deliberately: one artifact, one
generated Dart file, one SHA-256 recorded alongside so that "the committed Dart
no longer matches the committed artifact" is mechanically detectable rather than
something a reviewer has to notice. `--check` is the CI form and writes nothing.

Two things openFDA cannot give us, both of which the app has to say out loud:

  * It is **US labelling**. Strengths, brand names, available formulations and
    warnings differ in every other jurisdiction, and a user reading US warnings
    about a box bought in Manchester is being quietly misinformed.
  * Tampons and menstrual cups are FDA **devices**, not drugs. They are not in
    `/drug/label` at all, and their TSS guidance is hand-curated separately in
    AND-32 — clearly marked as curated rather than sourced.

Usage:
    python3 tools/scripts/gen_medicines.py --fetch   # needs network
    python3 tools/scripts/gen_medicines.py           # regenerate Dart only
    python3 tools/scripts/gen_medicines.py --check   # CI gate, writes nothing
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ARTIFACT = REPO_ROOT / "artifacts" / "medicines" / "medicines_v1.json"
OUTPUT = (
    REPO_ROOT / "app" / "lib" / "data" / "reference" / "medicines_bundled.dart"
)

SCHEMA_VERSION = 1
API = "https://api.fda.gov/drug/label.json"

# Every medicine the app will show, and nothing else.
#
# An allowlist rather than a search, because the point is a small, reviewable
# set of things that actually come up around menstrual cycles. A query that
# returned "whatever openFDA has" would put the app in the position of
# presenting drug information nobody chose to present.
#
# The key is the app's stable identifier and is never shown to the user; the
# generic name is what openFDA is queried by.
ALLOWLIST: tuple[tuple[str, str], ...] = (
    ("ibuprofen", "ibuprofen"),
    ("naproxen", "naproxen"),
    ("mefenamic_acid", "mefenamic acid"),
    ("paracetamol", "acetaminophen"),
    ("tranexamic_acid", "tranexamic acid"),
    ("combined_oral_contraceptive", "ethinyl estradiol and levonorgestrel"),
    ("progestogen_only_pill", "norethindrone"),
    ("levonorgestrel_emergency", "levonorgestrel"),
    ("ferrous_sulfate", "ferrous sulfate"),
    ("ferrous_fumarate", "ferrous fumarate"),
    ("ferrous_gluconate", "ferrous gluconate"),
    ("magnesium", "magnesium oxide"),
    ("zinc", "zinc"),
)

# Label sections carried into the artifact, in the order the app renders them.
#
# Deliberately short. Everything here is a warning or a "what is this for";
# nothing is dosing, because a dose read off a US label and applied to a box
# from another country is the specific harm this feature has to avoid.
SECTIONS: tuple[tuple[str, str], ...] = (
    ("purpose", "purpose"),
    ("warnings", "warnings"),
    ("do_not_use", "do_not_use"),
    ("ask_doctor", "ask_doctor"),
    ("stop_use", "stop_use"),
    ("pregnancy_or_breast_feeding", "pregnancy_or_breast_feeding"),
)

# openFDA asks that this notice travel with the data.
#
# [VERIFY] the exact wording against https://open.fda.gov/terms/ before
# release. The marker lives in this comment and NOT in the string, because the
# string is rendered at the foot of the lookup screen: it shipped reading
# "[VERIFY] Data from openFDA..." to every user who opened it, which is a note
# to a developer showing up in an app. A marker that is visible to the reader
# is not a marker, it is a defect.
DISCLAIMER = (
    "Data from openFDA. This information comes from US drug "
    "labelling and has not been evaluated for use outside the United States. "
    "It is not a substitute for advice from a doctor or pharmacist."
)


def fetch_entry(key: str, generic: str, *, limit: int = 1) -> dict:
    """Fetch one allowlisted medicine from openFDA."""
    query = urllib.parse.urlencode(
        {"search": f'openfda.generic_name:"{generic}"', "limit": str(limit)}
    )
    request = urllib.request.Request(
        f"{API}?{query}",
        headers={"User-Agent": "period-tracker-medicines-generator"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)

    results = payload.get("results") or []
    if not results:
        raise SystemExit(f"error: openFDA returned nothing for {generic!r}")
    label = results[0]
    openfda = label.get("openfda", {})

    sections = {}
    for name, field in SECTIONS:
        value = label.get(field)
        if isinstance(value, list) and value:
            sections[name] = " ".join(str(v).strip() for v in value).strip()

    return {
        "key": key,
        "generic_name": generic,
        # Sorted and capped: a label can carry dozens of brand names, and a
        # screen listing all of them is a screen nobody reads.
        "brand_names": sorted({str(b) for b in openfda.get("brand_name", [])})[
            :6
        ],
        "sections": dict(sorted(sections.items())),
        "label_id": str(label.get("id", "")),
        "effective_time": str(label.get("effective_time", "")),
    }


def fetch_all() -> dict:
    """Fetch every allowlisted medicine and build the artifact payload."""
    entries = []
    for key, generic in ALLOWLIST:
        print(f"fetching {generic}...", file=sys.stderr)
        entries.append(fetch_entry(key, generic))
    return {
        "schema_version": SCHEMA_VERSION,
        "source": "openFDA /drug/label",
        "jurisdiction": "US",
        "snapshot_status": "fetched",
        "snapshot_date": date.today().isoformat(),
        "disclaimer": DISCLAIMER,
        # Sorted by key so the artifact is byte-stable across runs and a diff
        # shows what actually changed rather than a reshuffle.
        "entries": sorted(entries, key=lambda e: e["key"]),
    }


def empty_artifact() -> dict:
    """The artifact's shape before anything has been fetched.

    Committed rather than left absent so that every consumer — the Dart
    generator, the app, the tests — exercises the real shape from the first
    commit, and so the unpopulated state is visible in the repository instead
    of being a missing file someone might mistake for an oversight.
    """
    return {
        "schema_version": SCHEMA_VERSION,
        "source": "openFDA /drug/label",
        "jurisdiction": "US",
        "snapshot_status": "not_fetched",
        "snapshot_date": None,
        "disclaimer": DISCLAIMER,
        "entries": [],
    }


def dart_string(value: str) -> str:
    """Render `value` as a Dart single-quoted literal."""
    escaped = (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\n", "\\n")
        .replace("\r", "")
    )
    return f"'{escaped}'"


def dart_string_list(values: list[str], indent: str) -> str:
    if not values:
        return "<String>[]"
    body = "".join(f"{indent}  {dart_string(v)},\n" for v in values)
    return f"<String>[\n{body}{indent}]"


def dart_entry(entry: dict, indent: str) -> str:
    sections = entry.get("sections", {})
    # The map literal opens on the `sections:` line, which sits at `indent` + 2
    # spaces, so its entries indent to + 4 and its closing brace back to + 2.
    # Getting this wrong is not cosmetic: `dart format` rewrites it, which makes
    # the format gate and `--check` fight the moment someone runs `--fetch`.
    # `TestFormatting` in research/tests/test_gen_medicines.py caught exactly
    # that, on the only code path the committed empty artifact never exercises.
    entry_indent = f"{indent}    "
    section_lines = "".join(
        f"{entry_indent}{dart_string(name)}: {dart_string(text)},\n"
        for name, text in sorted(sections.items())
    )
    sections_literal = (
        "<String, String>{}"
        if not section_lines
        else f"<String, String>{{\n{section_lines}{indent}  }}"
    )
    return (
        f"{indent}Medicine(\n"
        f"{indent}  key: {dart_string(entry['key'])},\n"
        f"{indent}  genericName: {dart_string(entry['generic_name'])},\n"
        f"{indent}  brandNames: "
        f"{dart_string_list(entry.get('brand_names', []), indent + '  ')},\n"
        f"{indent}  sections: {sections_literal},\n"
        f"{indent}),\n"
    )


def render(payload: dict, digest: str) -> str:
    """Return the full text of the generated Dart file."""
    if payload["schema_version"] != SCHEMA_VERSION:
        raise SystemExit(
            f"error: artifact schema_version {payload['schema_version']} is not "
            f"{SCHEMA_VERSION}; this generator does not know how to read it"
        )

    # Rendered so that the output is already `dart format` clean. It has to be:
    # `--check` compares the file byte for byte against a fresh render, and the
    # repo's format gate rewrites anything that is not formatted. A generator
    # whose output the formatter touches makes those two checks fight — format
    # the file and --check fails, regenerate and format fails — and the first
    # thing anyone reaches for is deleting one of them.
    entries = "".join(dart_entry(e, "  ") for e in payload["entries"])
    entries_literal = (
        "<Medicine>[]" if not entries else f"<Medicine>[\n{entries}]"
    )
    snapshot = payload.get("snapshot_date")
    snapshot_literal = "null" if snapshot is None else dart_string(snapshot)

    return f'''// GENERATED BY tools/scripts/gen_medicines.py. DO NOT EDIT BY HAND.
//
// Regenerate with:
//     python3 tools/scripts/gen_medicines.py --fetch
//
// The app compiles this in rather than parsing an asset, so a lookup never
// depends on file IO and a corrupt asset cannot leave the screen empty with no
// explanation. The phone makes no request for any of it: the fetch happens in
// the generator, and the app has no INTERNET permission at all (ADR-0004).

/// Bundled medicine reference entries.
///
/// Carries the openFDA label extracts the lookup screen renders, compiled in
/// as Dart constants, plus the checksum and date of the artifact they came
/// from. Nothing here is fetched on the phone.
///
/// Includes:
///     - medicinesArtifactSha256: Checksum of the source artifact.
///     - medicinesFetchedOn: When the snapshot was taken.
///     - medicinesDisclaimer: What the screen says about the source.
///     - bundledMedicines: The entries themselves.
library;

import 'package:period_tracker/data/reference/medicine.dart';

/// SHA-256 of the `medicines_v1.json` these constants were generated from.
///
/// A drift guard, not a security boundary: the artifact is committed to the
/// repository and never fetched at runtime. `gen_medicines.py --check` fails
/// CI if the two stop matching.
const String medicinesArtifactSha256 =
    '{digest}';

/// Whether the artifact has actually been populated from openFDA.
///
/// False in a repository where nobody has run `--fetch` yet. The app renders
/// an explanation rather than an empty screen in that case, and a release-gate
/// test reports it. Shipping an empty reference section silently would be
/// worse than not having one.
const bool medicinesFetched = {str(payload["snapshot_status"] == "fetched").lower()};

/// The day the data was pulled from openFDA, or null if it never was.
///
/// Displayed on the screen. Drug labelling changes, and a reference with no
/// date on it invites the reader to assume it is current.
const String? medicinesSnapshotDate = {snapshot_literal};

/// The jurisdiction this labelling comes from.
///
/// **US**, and the screen says so. Strengths, brand names, available
/// formulations and warnings differ everywhere else, and a user reading US
/// warnings about a box bought elsewhere is being quietly misinformed.
const String medicinesJurisdiction = {dart_string(payload["jurisdiction"])};

/// The notice openFDA asks to travel with the data.
const String medicinesDisclaimer =
    {dart_string(payload["disclaimer"])};

/// Every medicine compiled into the app.
const List<Medicine> bundledMedicines = {entries_literal};
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fetch",
        action="store_true",
        help="pull the allowlist from openFDA and rewrite the artifact",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if the generated Dart is stale, and write nothing",
    )
    args = parser.parse_args()

    if args.fetch and args.check:
        print("error: --fetch and --check are mutually exclusive", file=sys.stderr)
        return 2

    if args.fetch:
        try:
            payload = fetch_all()
        except (urllib.error.URLError, TimeoutError) as error:
            # Reported rather than swallowed, and the artifact is left alone.
            # Half a snapshot is worse than none: the app would show four
            # medicines and no indication that nine others were meant to be
            # there.
            print(f"error: openFDA fetch failed: {error}", file=sys.stderr)
            print(
                "the committed artifact has not been modified.", file=sys.stderr
            )
            return 1
        ARTIFACT.parent.mkdir(parents=True, exist_ok=True)
        ARTIFACT.write_text(
            json.dumps(payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        print(f"wrote {ARTIFACT.relative_to(REPO_ROOT)}")

    if not ARTIFACT.exists():
        ARTIFACT.parent.mkdir(parents=True, exist_ok=True)
        ARTIFACT.write_text(
            json.dumps(empty_artifact(), indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        print(f"created empty {ARTIFACT.relative_to(REPO_ROOT)}")

    raw = ARTIFACT.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    generated = render(json.loads(raw), digest)

    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current == generated:
            print(f"OK: {OUTPUT.relative_to(REPO_ROOT)} matches the artifact")
            return 0
        print(
            f"error: {OUTPUT.relative_to(REPO_ROOT)} is stale. Run "
            f"`python3 tools/scripts/gen_medicines.py` and commit the result.",
            file=sys.stderr,
        )
        return 1

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(generated, encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(REPO_ROOT)} (sha256 {digest[:12]}...)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
