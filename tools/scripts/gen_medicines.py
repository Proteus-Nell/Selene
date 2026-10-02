#!/usr/bin/env python3
"""Generate the medicines reference from openFDA's drug label export.

The app's medicines reference covers every human prescription and
over-the-counter drug that openFDA links to a current US product listing. It
does that **with no network permission at all**: the export is downloaded and
reduced here, on a developer machine or in CI, and the result is committed. The
phone never makes a request, and `assert_no_network.sh` fails the build if it
ever could (ADR-0004, ADR-0009, ADR-0012).

One label has to stand for each drug, and that choice is the whole job. openFDA
holds over a quarter of a million labels, and a single drug can have hundreds:
every manufacturer, repackager and strength files its own. The first version of
this script took the top hit of a text search, which found "levonorgestrel"
inside the name of a combined pill and answered "zinc" with a diaper cream. A
drug is now identified by what it contains, never by what its name contains,
and every step below is a rule. Nothing is chosen by hand.

Pipeline:
    1. Download the export's partitions, refusing any whose label count
       disagrees with openFDA's index.
    2. Keep labels linked to a current product listing for exactly one human
       prescription or over-the-counter drug, and drop homeopathic products.
    3. Group the rest by active substances, route, and prescription status.
    4. Take one label per group, best first by `rank`, and write the
       selection with one drug per line so that a refresh diffs per drug.

Two things openFDA cannot give us, both of which the app has to say out loud:

  * It is **US labelling**. Strengths, brand names, available formulations and
    warnings differ in every other jurisdiction, and a user reading US warnings
    about a box bought in Manchester is being quietly misinformed.
  * Tampons and menstrual cups are FDA **devices**, not drugs. They are not in
    the drug label export at all, and their TSS guidance is curated separately
    in AND-32, clearly marked as curated rather than sourced.

Usage:
    python3 tools/scripts/gen_medicines.py --fetch   # needs network, ~1.8 GB
    python3 tools/scripts/gen_medicines.py           # regenerate Dart only
    python3 tools/scripts/gen_medicines.py --check   # CI gate, writes nothing
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
import urllib.error
import urllib.request
import zipfile
from collections import Counter, defaultdict
from collections.abc import Iterable
from itertools import pairwise
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ARTIFACT = REPO_ROOT / "artifacts" / "medicines" / "medicines_v1.json"
SELECTION = REPO_ROOT / "artifacts" / "medicines" / "selection_v1.json"
OUTPUT = (
    REPO_ROOT / "app" / "lib" / "data" / "reference" / "medicines_bundled.dart"
)
# Under data/, which is gitignored: the export is about 1.8 GB and is never
# committed. Only what is selected from it is.
CACHE = REPO_ROOT / "data" / "openfda" / "drug-label"

SCHEMA_VERSION = 1
SELECTION_SCHEMA_VERSION = 1
KEY_LIMIT = 96  # characters of a key's substance part; see entry_key
DOWNLOAD_INDEX = "https://api.fda.gov/download.json"
HEADERS = {"User-Agent": "period-tracker-medicines-generator"}

# The sections each kind of label is judged on, in the order the app will
# render them: the professional label for a prescription drug, the Drug Facts
# panel for an over-the-counter one.
#
# Nothing here is dosing, deliberately, because a dose read off a US label and
# applied to a box from another country is the specific harm this feature has
# to avoid. Not carried at all, rather than carried and hidden, which would
# leave it one edit away from being shown.
RX_SECTIONS: tuple[str, ...] = (
    "boxed_warning",
    "indications_and_usage",
    "contraindications",
    "warnings_and_cautions",
    "warnings",
    "precautions",
    "drug_interactions",
    "use_in_specific_populations",
    "pregnancy",
    "nursing_mothers",
)
OTC_SECTIONS: tuple[str, ...] = (
    "purpose",
    "indications_and_usage",
    "warnings",
    "do_not_use",
    "ask_doctor",
    "ask_doctor_or_pharmacist",
    "when_using",
    "stop_use",
    "pregnancy_or_breast_feeding",
)

# Why a label takes no part in the selection. Each is counted in the output,
# so a change in openFDA's export shows up as a change in these numbers.
SKIP_UNLINKED = "unlinked"
SKIP_OTHER_TYPE = "other_product_type"
SKIP_MULTI_PRODUCT = "multi_product"
SKIP_HOMEOPATHIC = "homeopathic"

# SPL writes homeopathic potencies in units of its own, `[hp_X]` and `[hp_C]`,
# which no other product uses.
HOMEOPATHIC_UNIT = re.compile(r"\[hp_", re.IGNORECASE)
# A potency in the name itself, "ARNICA 30C". Over-the-counter labels only: on
# a prescription label "13C" is carbon-13, in a breath-test diagnostic.
POTENCY = re.compile(r"\b\d+\s?(?:X|C|CK|LM)\b")
# Dosage-form words that appear in some generic names but are not substances:
# "LEVONORGESTREL AND ETHINYL ESTRADIOL TABLETS".
FORM_WORDS = frozenset({"TABLET", "TABLETS", "CAPSULE", "CAPSULES", "KIT", "USP"})
TABLETS = re.compile(r"\b(?:TABLETS?|CAPSULES?)\b")
# A strength written into a generic name, "1 MG/0.02 MG". Not a substance.
STRENGTH = re.compile(r"\b\d+(?:\.\d+)?\s*(?:MG|MCG|G|ML|IU|UNITS?|%)(?=\W|$)")

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


def export_index() -> tuple[str, list[dict]]:
    """Read openFDA's download index for the drug label export.

    Returns:
        `tuple[str, list[dict]]`: The export date, and the partitions, each
        with its URL, its size in MiB and how many labels it holds.
    """
    request = urllib.request.Request(DOWNLOAD_INDEX, headers=HEADERS)
    with urllib.request.urlopen(request, timeout=60) as response:
        label = json.load(response)["results"]["drug"]["label"]
    return str(label["export_date"]), list(label["partitions"])


def download_partitions(
    cache: Path, partitions: list[dict]
) -> list[tuple[Path, int]]:
    """Download every partition that is not already cached whole.

    A cached file counts only if its size matches the index, so an interrupted
    download is fetched again rather than read as a short export. Each file
    lands under a temporary name and is renamed into place.

    Args:
        cache (Path): Where the zip files are kept between runs.
        partitions (`list[dict]`): The partitions from the download index.

    Returns:
        `list[tuple[Path, int]]`: Each partition's local path, and how many
        labels openFDA says it holds.
    """
    cache.mkdir(parents=True, exist_ok=True)
    local = []
    for partition in partitions:
        url = str(partition["file"])
        path = cache / url.rsplit("/", 1)[-1]
        size_mib = float(partition["size_mb"])
        cached = path.exists() and abs(path.stat().st_size / 2**20 - size_mib) < 0.01
        if not cached:
            print(f"downloading {path.name} ({size_mib:.0f} MiB)...", file=sys.stderr)
            partial = path.with_name(path.name + ".part")
            request = urllib.request.Request(url, headers=HEADERS)
            with (
                urllib.request.urlopen(request, timeout=300) as response,
                partial.open("wb") as out,
            ):
                shutil.copyfileobj(response, out, length=1 << 20)
            partial.replace(path)
        local.append((path, int(partition["records"])))
    return local


def read_partition(path: Path, expected: int) -> list[dict]:
    """Read one partition's labels, refusing a file that holds the wrong count.

    Args:
        path (Path): The cached zip file.
        expected (int): How many labels the download index says it holds.

    Returns:
        `list[dict]`: The labels, as openFDA serves them.

    Raises:
        SystemExit: When the count disagrees. A short partition would silently
            drop every drug whose only labels were in the missing part.
    """
    with zipfile.ZipFile(path) as archive:
        (member,) = archive.namelist()
        with archive.open(member) as stream:
            labels = json.load(stream)["results"]
    if len(labels) != expected:
        raise SystemExit(
            f"error: {path.name} holds {len(labels)} labels, and openFDA's "
            f"index says {expected}"
        )
    return labels


def normalise(text: str) -> str:
    """Return `text` upper-cased with its whitespace collapsed.

    Args:
        text (str): A name as openFDA spells it.

    Returns:
        str: The name in the form groups are keyed by.
    """
    return " ".join(str(text).upper().split())


def slug(text: str) -> str:
    """Return `text` lower-cased, with every run of other characters a hyphen.

    Args:
        text (str): A substance or route name.

    Returns:
        str: The form identities and keys are built from, so that names which
        differ only in punctuation, "A, B" and "A B", are the same drug.
    """
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def substances_from_name(generic: str) -> tuple[str, ...]:
    """Read a product's active substances off its generic name.

    Only for labels openFDA lists no substances for, which are mostly kits. A
    pill pack is a kit of active and placebo tablets, and its generic name,
    "LEVONORGESTREL AND ETHINYL ESTRADIOL AND ETHINYL ESTRADIOL", is the only
    place its ingredients appear. Without this, every brand of the same pill
    became a drug of its own, named by however its label happened to be worded.

    Args:
        generic (str): The normalised generic name.

    Returns:
        `tuple[str, ...]`: The distinct substances, sorted, with dosage-form
        words removed, or the whole name when nothing else is left.
    """
    # Commas and slashes inside brackets, and the slash in units like "V/V",
    # are part of a name, not a list. Hidden before splitting, put back after.
    hidden = re.sub(
        r"\([^)]*\)",
        lambda match: match.group(0).replace(",", "\x00").replace("/", "\x01"),
        generic,
    )
    hidden = re.sub(r"\b([A-Z])/([A-Z])\b", "\\1\x01\\2", hidden)
    hidden = STRENGTH.sub(" ", hidden)
    found = set()
    for part in re.split(r",|/|\bAND\b", hidden):
        part = part.replace("\x00", ",").replace("\x01", "/")
        words = [word for word in part.split() if word not in FORM_WORDS]
        if words:
            found.add(" ".join(words))
    return tuple(sorted(found)) or (generic,)


def says_tablets(label: dict) -> bool:
    """Report whether a label's package says it holds tablets or capsules.

    Args:
        label (dict): One label, as openFDA serves it.

    Returns:
        bool: True for "28 Tablets" on the carton, unless the carton also names
        a route other than swallowing: vaginal, sublingual or buccal.
    """
    text = " ".join(label.get("package_label_principal_display_panel") or []).upper()
    other_route = any(word in text for word in ("VAGINAL", "SUBLINGUAL", "BUCCAL"))
    return bool(TABLETS.search(text)) and not other_route


def has_text(label: dict, section: str) -> bool:
    """Report whether a label carries a section with anything in it.

    Args:
        label (dict): One label, as openFDA serves it.
        section (str): The section's openFDA field name.

    Returns:
        bool: True when the section holds at least one non-blank paragraph.
    """
    return any(str(part).strip() for part in label.get(section) or [])


def is_homeopathic(label: dict, generic: str, kind: str) -> bool:
    """Report whether a label is for a homeopathic product.

    Homeopathic products carry potencies rather than doses, and their labels
    hold no interaction information to show. Over two thousand of them are
    linked to current listings, enough to bury real drugs in every search.

    Args:
        label (dict): One label, as openFDA serves it.
        generic (str): Its normalised generic name.
        kind (str): "rx" or "otc".

    Returns:
        bool: True for a homeopathic potency unit, a label that says it is
        homeopathic or cites the HPUS, or an over-the-counter name that carries
        a potency.
    """
    units = " ".join(label.get("spl_product_data_elements") or [])
    statement = " ".join(
        " ".join(label.get(field) or [])
        for field in (
            "active_ingredient",
            "purpose",
            "indications_and_usage",
            "package_label_principal_display_panel",
        )
    ).upper()
    return bool(
        HOMEOPATHIC_UNIT.search(units)
        or "HPUS" in statement
        or "HOMEOPATHIC" in statement
        or (kind == "otc" and POTENCY.search(generic))
    )


def summarise(label: dict) -> tuple[str | None, dict | None]:
    """Reduce one label to what selection needs, or say why it is skipped.

    Args:
        label (dict): One label, as openFDA serves it.

    Returns:
        `tuple[str | None, dict | None]`: `(None, record)` for a label that
        takes part, or `(reason, None)` with one of the `SKIP_` reasons.
    """
    openfda = label.get("openfda") or {}
    product_types = openfda.get("product_type") or []
    generic_names = openfda.get("generic_name") or []
    if not product_types or not generic_names:
        return SKIP_UNLINKED, None
    if product_types not in (["HUMAN PRESCRIPTION DRUG"], ["HUMAN OTC DRUG"]):
        return SKIP_OTHER_TYPE, None
    if len(generic_names) != 1:
        return SKIP_MULTI_PRODUCT, None
    kind = "rx" if product_types == ["HUMAN PRESCRIPTION DRUG"] else "otc"
    generic = normalise(generic_names[0])
    if is_homeopathic(label, generic, kind):
        return SKIP_HOMEOPATHIC, None

    wanted = RX_SECTIONS if kind == "rx" else OTC_SECTIONS
    listed = sorted({normalise(s) for s in openfda.get("substance_name") or []})
    substances = tuple(listed) or substances_from_name(generic)
    return None, {
        # The identity of the drug. A name is not one: "ZINC ACETATE AND
        # PRAMOXINE HCL" and "PRAMOXINE HYDROCHLORIDE, ZINC ACETATE" are the
        # same product, and "LEVONORGESTREL" is a substring of a combined pill.
        "identity": tuple(sorted({slug(s) for s in substances})),
        "substances": substances,
        "routes": tuple(sorted({normalise(r) for r in openfda.get("route") or []})),
        "says_tablets": says_tablets(label),
        "type": kind,
        "generic_name": generic,
        "brands": [" ".join(str(b).split()) for b in openfda.get("brand_name") or []],
        "sections": frozenset(s for s in wanted if has_text(label, s)),
        # openFDA sets this only on the original packager's labels.
        "original": True in (openfda.get("is_original_packager") or []),
        "application": str((openfda.get("application_number") or [""])[0]),
        "manufacturer": str((openfda.get("manufacturer_name") or [""])[0]),
        "effective_time": str(label.get("effective_time") or ""),
        "set_id": str(label.get("set_id") or ""),
        "id": str(label.get("id") or ""),
    }


def content_tier(record: dict) -> int:
    """Grade how much of the safety information a label carries.

    Args:
        record (dict): A label summarised by `summarise`.

    Returns:
        int: 2 for warnings plus the section that names other medicines, 1 for
        some safety section, and 0 for none, which leaves nothing to show.
    """
    sections = record["sections"]
    if record["type"] == "rx":
        warnings = sections & {"warnings_and_cautions", "warnings", "precautions"}
        if warnings and "drug_interactions" in sections:
            return 2
        others = {"contraindications", "boxed_warning", "drug_interactions"}
        return 1 if warnings or sections & others else 0
    advice = sections & {"do_not_use", "ask_doctor", "ask_doctor_or_pharmacist", "stop_use"}
    if "warnings" in sections and advice:
        return 2
    return 1 if "warnings" in sections or advice else 0


def rank(record: dict) -> tuple:
    """Return the sort key that puts a group's best label first.

    Steps:
        1. The most complete safety information.
        2. The original packager's label over a repackager's copy of it.
        3. The reference label (NDA or BLA) over a generic (ANDA), over one
           written to an over-the-counter monograph.
        4. The newest.
        5. The lowest set id, so equal labels are ordered the same every run.

    Args:
        record (dict): A label summarised by `summarise`.

    Returns:
        tuple: A key that sorts the best label lowest.
    """
    application = record["application"]
    reference = (
        2
        if application.startswith(("NDA", "BLA"))
        else 1
        if application.startswith("ANDA")
        else 0
    )
    effective = int(record["effective_time"]) if record["effective_time"].isdigit() else 0
    return (
        -content_tier(record),
        not record["original"],
        -reference,
        -effective,
        record["set_id"],
        record["id"],
    )


def entry_key(identity: tuple[str, ...], routes: tuple[str, ...], kind: str) -> str:
    """Build a drug's stable identifier from what defines it.

    Args:
        identity (`tuple[str, ...]`): Its active substances, slugged and sorted.
        routes (`tuple[str, ...]`): Its routes, sorted. May be empty.
        kind (str): "rx" or "otc".

    Returns:
        str: For example `tranexamic-acid.oral.rx`. Never shown to the user.
        Some cosmetic products list every ingredient, water and fragrance
        included, as a substance, so a long identity is cut short and finished
        with a hash of the whole, which keeps it unique.
    """
    substances = "+".join(identity)
    if len(substances) > KEY_LIMIT:
        digest = hashlib.sha256(substances.encode()).hexdigest()[:12]
        substances = f"{substances[: KEY_LIMIT - 13]}-{digest}"
    route = "+".join(slug(r) for r in routes) or "unspecified"
    return f"{substances}.{route}.{kind}"


def brand_names(labels: list[dict], generic_names: Iterable[str]) -> list[str]:
    """Collect every brand a group's labels are sold under.

    Args:
        labels (`list[dict]`): The group's summarised labels.
        generic_names (`Iterable[str]`): The group's generic names, which are
            left out: a store-brand "Ibuprofen" adds nothing to search.

    Returns:
        `list[str]`: One entry per brand, case-insensitively, in its most
        common spelling, sorted.
    """
    spellings: dict[str, Counter] = defaultdict(Counter)
    for label in labels:
        for brand in label["brands"]:
            spellings[brand.casefold()][brand] += 1
    generic = {name.casefold() for name in generic_names}
    chosen = [
        min(counts, key=lambda s: (-counts[s], s))
        for folded, counts in spellings.items()
        if folded not in generic
    ]
    return sorted(chosen, key=lambda s: (s.casefold(), s))


def with_routes(records: list[dict]) -> list[dict]:
    """Fill in the route a label leaves out, where it can be known.

    Kits list no route, so every pill pack would otherwise be a drug of its own
    beside the same pill with a route. A label without one takes, in order:

    Steps:
        1. Oral, when its own carton says tablets or capsules.
        2. Its drug's usual route, when at least nine in ten of the labels that
           give or imply a route agree. Some cartons are placeholders, "Add
           image transcription here", and say nothing.
        3. Nothing, and it stays a drug with an unspecified route.

    Args:
        records (`list[dict]`): Labels summarised by `summarise`.

    Returns:
        `list[dict]`: The same labels, with routes filled in where known.
    """
    implied = [
        {**record, "routes": ("ORAL",)}
        if not record["routes"] and record["says_tablets"]
        else record
        for record in records
    ]
    usual: dict[tuple, Counter] = defaultdict(Counter)
    for record in implied:
        if record["routes"]:
            usual[(record["identity"], record["type"])][record["routes"]] += 1
    filled = []
    for record in implied:
        counts = usual.get((record["identity"], record["type"]))
        if not record["routes"] and counts:
            route, agreeing = min(counts.items(), key=lambda item: (-item[1], item[0]))
            if agreeing >= 0.9 * sum(counts.values()):
                record = {**record, "routes": route}
        filled.append(record)
    return filled


def select(records: Iterable[dict]) -> tuple[list[dict], int]:
    """Choose one label to stand for each drug.

    Args:
        records (`Iterable[dict]`): Labels summarised by `summarise`.

    Returns:
        `tuple[list[dict], int]`: The drugs, sorted by key, and how many groups
        were dropped because no label in them carries a safety section.

    Raises:
        SystemExit: When two different drugs would share a key, rather than
            silently letting one overwrite the other.
    """
    records = with_routes(list(records))
    groups: dict[tuple, list[dict]] = defaultdict(list)
    for record in records:
        groups[(record["identity"], record["routes"], record["type"])].append(record)

    entries, empty = [], 0
    for (identity, routes, kind), labels in groups.items():
        best = min(labels, key=rank)
        if content_tier(best) == 0:
            empty += 1
            continue
        names = Counter(label["generic_name"] for label in labels)
        entries.append(
            {
                "key": entry_key(identity, routes, kind),
                # The name most of the group's labels use, which for a
                # combination product is rarely the one the best label uses.
                "name": min(names, key=lambda n: (-names[n], len(n), n)),
                "substances": list(best["substances"]),
                "routes": list(routes),
                "type": kind,
                "brands": brand_names(labels, names),
                "labels": len(labels),
                "label": {
                    "application": best["application"],
                    "effective_time": best["effective_time"],
                    "id": best["id"],
                    "manufacturer": best["manufacturer"],
                    "set_id": best["set_id"],
                },
            }
        )

    entries.sort(key=lambda e: e["key"])
    clashes = sorted({a["key"] for a, b in pairwise(entries) if a["key"] == b["key"]})
    if clashes:
        raise SystemExit("error: different drugs share a key: " + ", ".join(clashes[:5]))
    return entries, empty


def build_selection(
    partitions: list[tuple[Path, int]], export_date: str
) -> tuple[dict, list[dict]]:
    """Read every partition and select one label per drug.

    Partitions are read one at a time and released, because each holds close to
    a gigabyte of JSON once decompressed.

    Args:
        partitions (`list[tuple[Path, int]]`): Local paths and label counts.
        export_date (str): The export's date, from openFDA's index.

    Returns:
        `tuple[dict, list[dict]]`: The selection's metadata, with a count for
        every reason a label was left out, and the drugs.
    """
    skipped: Counter = Counter()
    records: list[dict] = []
    total = 0
    for path, expected in partitions:
        for label in read_partition(path, expected):
            total += 1
            reason, record = summarise(label)
            if reason is None:
                records.append(record)
            else:
                skipped[reason] += 1
        print(f"read {path.name}", file=sys.stderr)

    entries, empty = select(records)
    meta = {
        "schema_version": SELECTION_SCHEMA_VERSION,
        "source": "openFDA drug label bulk export",
        "export_date": export_date,
        "jurisdiction": "US",
        "counts": {
            "labels": total,
            SKIP_UNLINKED: skipped[SKIP_UNLINKED],
            SKIP_OTHER_TYPE: skipped[SKIP_OTHER_TYPE],
            SKIP_MULTI_PRODUCT: skipped[SKIP_MULTI_PRODUCT],
            SKIP_HOMEOPATHIC: skipped[SKIP_HOMEOPATHIC],
            "considered": len(records),
            "no_safety_sections": empty,
            "drugs": len(entries),
        },
    }
    return meta, entries


def selection_json(meta: dict, entries: list[dict]) -> str:
    """Render the selection as JSON with one drug per line.

    Still a single valid JSON document, but laid out so that a refresh shows up
    in a diff as the drugs whose label changed, not as one rewritten blob.

    Args:
        meta (dict): The selection's metadata.
        entries (`list[dict]`): The drugs, already sorted by key.

    Returns:
        str: The file's full text.
    """
    lines = ",\n".join(json.dumps(e, sort_keys=True) for e in entries)
    return (
        '{"meta": ' + json.dumps(meta, sort_keys=True) + ',\n"entries": [\n'
        + lines
        + "\n]}\n"
    )


def selection_problems(text: str) -> list[str]:
    """Check a committed selection is well formed.

    Catches what a hand edit or a bad merge usually leaves behind: lines out of
    order, a reformatted file, a repeated key. It cannot catch a changed value,
    a drug renamed in place; only rerunning `--fetch` against the same export
    can, because the export is the only thing the values can be checked against.

    Args:
        text (str): The selection file's contents.

    Returns:
        `list[str]`: What is wrong with it. Empty when it is in the layout this
        generator writes, sorted, and free of duplicate keys.
    """
    payload = json.loads(text)
    keys = [entry["key"] for entry in payload["entries"]]
    problems = []
    if payload["meta"].get("schema_version") != SELECTION_SCHEMA_VERSION:
        problems.append("its schema_version is not one this generator writes")
    if any(a >= b for a, b in pairwise(keys)):
        problems.append("its entries are not sorted by key, or a key repeats")
    if selection_json(payload["meta"], payload["entries"]) != text:
        problems.append("it is not in the form this generator writes")
    return problems


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
    """Render `values` as a Dart `List<String>` literal, one item per line.

    Args:
        values (`list[str]`): The strings.
        indent (str): The indentation of the line the literal opens on.

    Returns:
        str: The literal, or `<String>[]` when there is nothing in it.
    """
    if not values:
        return "<String>[]"
    body = "".join(f"{indent}  {dart_string(v)},\n" for v in values)
    return f"<String>[\n{body}{indent}]"


def dart_entry(entry: dict, indent: str) -> str:
    """Render one artifact entry as a `Medicine(...)` constructor call.

    Args:
        entry (dict): One entry of the medicines artifact.
        indent (str): The indentation of the line the call opens on.

    Returns:
        str: The call, already in `dart format` layout, ending in a comma.
    """
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
    """Run the generator from the command line.

    Returns:
        int: 0 on success, 1 when a fetch fails or `--check` finds a stale or
        edited file, and 2 for flags that cannot be combined.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fetch",
        action="store_true",
        help="download openFDA's label export and rewrite the selection",
    )
    parser.add_argument(
        "--cache",
        type=Path,
        default=CACHE,
        help="where the downloaded export is kept between runs",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if a generated file is stale or edited, and write nothing",
    )
    args = parser.parse_args()

    if args.fetch and args.check:
        print("error: --fetch and --check are mutually exclusive", file=sys.stderr)
        return 2

    if args.fetch:
        try:
            export_date, partitions = export_index()
            local = download_partitions(args.cache, partitions)
            meta, entries = build_selection(local, export_date)
        except (urllib.error.URLError, TimeoutError, OSError, zipfile.BadZipFile) as error:
            # Reported rather than swallowed, and nothing committed is touched.
            # A selection built from part of the export would silently drop
            # every drug whose labels all sat in the missing part.
            print(f"error: reading openFDA's export failed: {error}", file=sys.stderr)
            print("the committed artifacts have not been modified.", file=sys.stderr)
            return 1
        SELECTION.parent.mkdir(parents=True, exist_ok=True)
        SELECTION.write_text(selection_json(meta, entries), encoding="utf-8")
        print(
            f"wrote {SELECTION.relative_to(REPO_ROOT)}: {len(entries)} drugs "
            f"from {meta['counts']['labels']} labels"
        )

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
        failed = False
        if SELECTION.exists():
            problems = selection_problems(SELECTION.read_text(encoding="utf-8"))
            for problem in problems:
                print(
                    f"error: {SELECTION.relative_to(REPO_ROOT)}: {problem}. "
                    "Rerun `--fetch` rather than editing it.",
                    file=sys.stderr,
                )
            failed = bool(problems)
            if not problems:
                print(f"OK: {SELECTION.relative_to(REPO_ROOT)} is well formed")
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != generated:
            print(
                f"error: {OUTPUT.relative_to(REPO_ROOT)} is stale. Run "
                f"`python3 tools/scripts/gen_medicines.py` and commit the result.",
                file=sys.stderr,
            )
            failed = True
        if failed:
            return 1
        print(f"OK: {OUTPUT.relative_to(REPO_ROOT)} matches the artifact")
        return 0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(generated, encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(REPO_ROOT)} (sha256 {digest[:12]}...)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
