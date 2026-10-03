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
       Each drug carries the FDA's pharmacologic classes for it, and the
       names another label would mention it by (`match_terms`), which is
       what the app's interaction checker looks for (ADR-0014).
    5. Read the chosen labels again, and pack their safety sections into
       compressed chunks under app/assets/medicines, with an index the app
       searches.

Two things openFDA cannot give us:

  * Labelling from anywhere but the US. Strengths, brand names, available
    formulations and warnings differ in every other jurisdiction, and a user
    reading US warnings about a box bought in Manchester is being quietly
    misinformed, so the app says so on every page.
  * Tampons and menstrual cups. They are FDA **devices**, not drugs, and are
    not in the drug label export at all.

Usage:
    python3 tools/scripts/gen_medicines.py --fetch   # needs network, ~1.8 GB
    python3 tools/scripts/gen_medicines.py           # regenerate the Dart only
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
import zlib
from collections import Counter, defaultdict
from collections.abc import Iterable
from itertools import pairwise
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SELECTION = REPO_ROOT / "artifacts" / "medicines" / "selection_v2.json"
OUTPUT = REPO_ROOT / "app" / "lib" / "data" / "reference" / "medicines_bundled.dart"
BUNDLE = REPO_ROOT / "app" / "assets" / "medicines"
INDEX_NAME = "index.json.zlib"
CHUNK_NAME = "labels-{:03d}.jsonl.zlib"
CHUNK_GLOB = "labels-*.jsonl.zlib"
# Under data/, which is gitignored: the export is about 1.8 GB and is never
# committed. Only what is selected from it is.
CACHE = REPO_ROOT / "data" / "openfda" / "drug-label"

SELECTION_SCHEMA_VERSION = 2
BUNDLE_SCHEMA_VERSION = 2
# Bytes of label text per chunk, before compression. zlib's 32 KB window means
# a bigger chunk barely compresses better, and a smaller one opens faster.
CHUNK_TARGET = 1_000_000
KEY_LIMIT = 96  # characters of a key's substance part; see entry_key
DOWNLOAD_INDEX = "https://api.fda.gov/download.json"
DOWNLOAD_ATTEMPTS = 3
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
# The tag on an established pharmacologic class, "Estrogen [EPC]".
EPC_TAG = re.compile(r"\s*\[EPC\]$")
# A word that ends at least this many different substance names is the form a
# substance comes in, not the substance: the salt in "NAPROXEN SODIUM", the
# part of the plant in "GINGER ROOT". Read off the data, not listed by hand.
SALT_MIN = 8
# The fewest characters a substance's name may be cut down to. Shorter, and
# what is left is more often an abbreviation or a word than a drug.
BASE_MIN = 5

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


class IncompleteDownloadError(OSError):
    """A partition kept arriving shorter than openFDA says it is."""


def is_whole(size: int, size_mib: float) -> bool:
    """Report whether a file is the size openFDA's download index gives.

    The index gives sizes in MiB to two decimal places, so a whole file is
    within a hundredth of a MiB of it.

    Args:
        size (int): The file's size in bytes.
        size_mib (float): The size the index gives, in MiB.

    Returns:
        bool: True when the two agree.
    """
    return abs(size / 2**20 - size_mib) < 0.01


def fetch_partition(url: str, path: Path, size_mib: float) -> None:
    """Download one partition whole, or leave nothing behind.

    Python's HTTP client returns quietly when a connection closes early, so a
    transfer cut off part way would be written as a short file and fail later
    as a zip that cannot be opened. Each attempt is checked against the length
    the server announced, the size openFDA's index gives, and the zip's own
    directory, and a short one is fetched again.

    Args:
        url (str): Where the partition is.
        path (Path): Where it goes. Written only once it is whole.
        size_mib (float): Its size according to the download index.

    Raises:
        IncompleteDownloadError: When every attempt arrived short.
    """
    partial = path.with_name(path.name + ".part")
    for attempt in range(1, DOWNLOAD_ATTEMPTS + 1):
        request = urllib.request.Request(url, headers=HEADERS)
        with (
            urllib.request.urlopen(request, timeout=300) as response,
            partial.open("wb") as out,
        ):
            announced = response.headers.get("Content-Length")
            shutil.copyfileobj(response, out, length=1 << 20)
        size = partial.stat().st_size
        if (
            (announced is None or size == int(announced))
            and is_whole(size, size_mib)
            and zipfile.is_zipfile(partial)
        ):
            partial.replace(path)
            return
        print(
            f"{path.name} arrived short ({size:,} bytes), attempt {attempt} of {DOWNLOAD_ATTEMPTS}",
            file=sys.stderr,
        )
    partial.unlink(missing_ok=True)
    raise IncompleteDownloadError(f"{path.name} arrived short {DOWNLOAD_ATTEMPTS} times")


def download_partitions(cache: Path, partitions: list[dict]) -> list[tuple[Path, int]]:
    """Download every partition that is not already cached whole.

    A cached file counts only if its size matches the index and it opens as a
    zip, so a download cut short on an earlier run is fetched again rather than
    read as a short export.

    Args:
        cache (Path): Where the zip files are kept between runs.
        partitions (`list[dict]`): The partitions from the download index.

    Returns:
        `list[tuple[Path, int]]`: Each partition's local path, and how many
        labels openFDA says it holds.

    Raises:
        IncompleteDownloadError: When a partition never arrives whole.
    """
    cache.mkdir(parents=True, exist_ok=True)
    local = []
    for partition in partitions:
        url = str(partition["file"])
        path = cache / url.rsplit("/", 1)[-1]
        size_mib = float(partition["size_mb"])
        cached = (
            path.exists() and is_whole(path.stat().st_size, size_mib) and zipfile.is_zipfile(path)
        )
        if not cached:
            print(f"downloading {path.name} ({size_mib:.0f} MiB)...", file=sys.stderr)
            fetch_partition(url, path, size_mib)
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
            f"error: {path.name} holds {len(labels)} labels, and openFDA's index says {expected}"
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


def pharm_class(text: str) -> str:
    """Return an established pharmacologic class's name, without its tag.

    Args:
        text (str): The class as openFDA gives it, "Estrogen [EPC]".

    Returns:
        str: "Estrogen". The FDA's own capitalisation is kept, since the app
        shows the name.
    """
    return EPC_TAG.sub("", " ".join(str(text).split()))


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
        # Whether openFDA lists the substances, rather than their being read
        # off the name. Only a listed name is looked for in other labels.
        "listed": bool(listed),
        "classes": tuple(sorted({pharm_class(c) for c in openfda.get("pharm_class_epc") or []})),
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
        2 if application.startswith(("NDA", "BLA")) else 1 if application.startswith("ANDA") else 0
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


def name_words(name: str) -> tuple[str, ...]:
    """Split a name into lower-case words, dropping everything else.

    Args:
        name (str): A substance's name, "NAPROXEN SODIUM".

    Returns:
        `tuple[str, ...]`: `("naproxen", "sodium")`. A label writes the same
        name with any punctuation or capitals, so only the words are matched.
    """
    return tuple(re.findall(r"[a-z0-9]+", name.lower()))


def salt_words(names: Iterable[str]) -> frozenset[str]:
    """Find the words that say what form a substance is in, not which it is.

    Args:
        names (`Iterable[str]`): Every substance name in the selection.

    Returns:
        `frozenset[str]`: Each word that ends at least `SALT_MIN` different
        names of more than one word: "sodium", "hydrochloride", "root".
    """
    last = Counter(words[-1] for words in map(name_words, set(names)) if len(words) > 1)
    return frozenset(word for word, count in last.items() if count >= SALT_MIN)


def base_words(words: tuple[str, ...], salt: frozenset[str]) -> tuple[str, ...]:
    """Cut the salt words off the end of a name, keeping at least one word.

    Args:
        words (`tuple[str, ...]`): A name's words.
        salt (`frozenset[str]`): From `salt_words`.

    Returns:
        `tuple[str, ...]`: `("naproxen",)` for "naproxen sodium".
    """
    while len(words) > 1 and words[-1] in salt:
        words = words[:-1]
    return words


def match_terms(entries: list[dict], listed: set[str]) -> dict[str, list[str]]:
    """Work out the names another label would mention each drug by.

    A label warning about naproxen sodium usually says "naproxen", so each
    substance is looked for under its full name and, where it is safe to,
    under its name with the salt cut off. Every rule here is read off the data.

    Steps:
        1. Only a substance openFDA lists on some label counts. A name read
           off a kit's title can be "DAY" or "COLD", and would match nearly
           every label there is.
        2. The full name, unless it is only digits.
        3. The name without its salt words, when that is `BASE_MIN` or more
           characters, is not itself a salt word, and is unambiguous: every
           substance whose name starts with it cuts down to it too. "estradiol"
           is not a base of "estradiol valerate" while "estradiol cypionate"
           does not cut down to "estradiol".

    Args:
        entries (`list[dict]`): The selected drugs.
        listed (`set[str]`): The slug of every substance openFDA lists on at
            least one label.

    Returns:
        `dict[str, list[str]]`: Each drug's terms by key, as space-separated
        lower-case words, sorted. Empty for a drug no other label could name.
    """
    names = {substance for entry in entries for substance in entry["substances"]}
    salt = salt_words(names)
    bases = {name: base_words(name_words(name), salt) for name in names}
    candidates = {base for name, base in bases.items() if base != name_words(name)}
    ambiguous = set()
    for name, base in bases.items():
        words = name_words(name)
        for length in range(1, len(words) + 1):
            prefix = words[:length]
            if prefix in candidates and prefix != base:
                ambiguous.add(prefix)

    terms = {}
    for entry in entries:
        found = set()
        for name in entry["substances"]:
            words = name_words(name)
            if slug(name) not in listed or not words or "".join(words).isdigit():
                continue
            found.add(" ".join(words))
            base = bases[name]
            text = " ".join(base)
            if (
                base != words
                and base not in ambiguous
                and len(text) >= BASE_MIN
                and not "".join(base).isdigit()
                and base[-1] not in salt
            ):
                found.add(text)
        terms[entry["key"]] = sorted(found)
    return terms


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
    # The FDA classes a substance by what it is, so a class given on a label
    # of that substance alone holds wherever the substance is: most labels
    # carry no class at all, a drugstore's ibuprofen among them.
    substance_classes: dict[str, set[str]] = defaultdict(set)
    listed: set[str] = set()
    for record in records:
        groups[(record["identity"], record["routes"], record["type"])].append(record)
        if len(record["identity"]) == 1:
            substance_classes[record["identity"][0]].update(record["classes"])
        if record["listed"]:
            listed.update(record["identity"])

    entries, empty = [], 0
    for (identity, routes, kind), labels in groups.items():
        best = min(labels, key=rank)
        if content_tier(best) == 0:
            empty += 1
            continue
        names = Counter(label["generic_name"] for label in labels)
        classes = set().union(
            *(label["classes"] for label in labels),
            *(substance_classes[substance] for substance in identity),
        )
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
                "classes": sorted(classes),
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
    terms = match_terms(entries, listed)
    for entry in entries:
        entry["match"] = terms[entry["key"]]
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
    return '{"meta": ' + json.dumps(meta, sort_keys=True) + ',\n"entries": [\n' + lines + "\n]}\n"


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


def section_text(label: dict, section: str) -> str:
    """Return a section's paragraphs as published, a blank line between each.

    Args:
        label (dict): One label, as openFDA serves it.
        section (str): The section's openFDA field name.

    Returns:
        str: The section's text. Nothing in it is reworded, reordered or cut.
    """
    return "\n\n".join(str(part).strip() for part in label.get(section) or [] if str(part).strip())


def extract_sections(
    partitions: list[tuple[Path, int]], entries: list[dict]
) -> dict[str, list[list[str]]]:
    """Read the chosen labels again and take their safety sections.

    A second pass over the export, because a label cannot be chosen until every
    label for its drug has been seen, and holding the text of all of them would
    take gigabytes.

    Args:
        partitions (`list[tuple[Path, int]]`): Local paths and label counts.
        entries (`list[dict]`): The selected drugs.

    Returns:
        `dict[str, list[list[str]]]`: Each drug's sections by key, as
        `[name, text]` pairs in the order the app renders them.

    Raises:
        SystemExit: When a chosen label is not in the export, which means the
            cached files changed between the two passes.
    """
    chosen = {entry["label"]["id"]: entry for entry in entries}
    sections: dict[str, list[list[str]]] = {}
    for path, expected in partitions:
        for label in read_partition(path, expected):
            entry = chosen.get(str(label.get("id") or ""))
            if entry is None:
                continue
            order = RX_SECTIONS if entry["type"] == "rx" else OTC_SECTIONS
            sections[entry["key"]] = [
                [name, section_text(label, name)] for name in order if has_text(label, name)
            ]
        print(f"read {path.name} again", file=sys.stderr)
    missing = sorted({entry["key"] for entry in entries} - set(sections))
    if missing:
        raise SystemExit(
            f"error: {len(missing)} chosen labels are not in the export, e.g. {missing[0]}"
        )
    return sections


def build_bundle(
    meta: dict, entries: list[dict], sections: dict[str, list[list[str]]]
) -> tuple[bytes, list[bytes]]:
    """Pack the label text into compressed chunks, and index every drug.

    Steps:
        1. One JSON record per drug, one per line, in key order. Neighbouring
           keys are usually the same substance in another form, and their
           shared wording compresses together.
        2. A new chunk once the current one holds `CHUNK_TARGET` bytes, so that
           opening a drug decompresses a megabyte rather than sixty.
        3. An index of every drug: what search needs, where its text is,
           which label it came from, and how many labels it had. Search ranks
           a drug sold under many labels above one sold under few. Its
           classes and match terms go in too, for the interaction checker.

    Args:
        meta (dict): The selection's metadata.
        entries (`list[dict]`): The selected drugs, sorted by key.
        sections (`dict[str, list[list[str]]]`): Each drug's sections.

    Returns:
        `tuple[bytes, list[bytes]]`: The compressed index, and the compressed
        chunks in order.
    """
    rows, chunks, lines, size = [], [], [], 0
    for entry in entries:
        record = json.dumps(
            {"key": entry["key"], "sections": sections[entry["key"]]},
            ensure_ascii=False,
            separators=(",", ":"),
        )
        rows.append(
            {
                "brands": entry["brands"],
                "chunk": len(chunks),
                "classes": entry["classes"],
                "key": entry["key"],
                "label": {
                    "effective_time": entry["label"]["effective_time"],
                    "manufacturer": entry["label"]["manufacturer"],
                    "set_id": entry["label"]["set_id"],
                },
                "labels": entry["labels"],
                "line": len(lines),
                "match": entry["match"],
                "name": entry["name"],
                "routes": entry["routes"],
                "substances": entry["substances"],
                "type": entry["type"],
            }
        )
        lines.append(record)
        size += len(record.encode())
        if size >= CHUNK_TARGET:
            chunks.append("\n".join(lines).encode())
            lines, size = [], 0
    if lines:
        chunks.append("\n".join(lines).encode())

    index = {
        "chunks": len(chunks),
        "disclaimer": DISCLAIMER,
        "entries": rows,
        "export_date": meta["export_date"],
        "jurisdiction": meta["jurisdiction"],
        "schema_version": BUNDLE_SCHEMA_VERSION,
    }
    encoded = json.dumps(index, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return zlib.compress(encoded.encode(), 9), [zlib.compress(c, 9) for c in chunks]


def write_bundle(directory: Path, index: bytes, chunks: list[bytes]) -> None:
    """Replace the bundle in `directory` with a new one.

    Chunk files from the previous bundle are removed first: a refresh with fewer
    chunks would otherwise leave old ones behind, still shipped and still
    counted by the checksum.

    Args:
        directory (Path): Where the app's assets for the bundle live.
        index (bytes): The compressed index.
        chunks (`list[bytes]`): The compressed chunks, in order.
    """
    directory.mkdir(parents=True, exist_ok=True)
    for stale in directory.glob(CHUNK_GLOB):
        stale.unlink()
    (directory / INDEX_NAME).write_bytes(index)
    for number, chunk in enumerate(chunks):
        (directory / CHUNK_NAME.format(number)).write_bytes(chunk)


def bundle_files(directory: Path) -> list[Path]:
    """List the bundle's files, the index first and then the chunks in order.

    Args:
        directory (Path): Where the app's assets for the bundle live.

    Returns:
        `list[Path]`: The files, or an empty list when there is no index.
    """
    index = directory / INDEX_NAME
    if not index.exists():
        return []
    return [index, *sorted(directory.glob(CHUNK_GLOB))]


def bundle_digest(files: list[Path]) -> str:
    """Return one SHA-256 over every file's name, length and contents.

    Args:
        files (`list[Path]`): The bundle's files, in order.

    Returns:
        str: The hex digest. That of nothing at all when there is no bundle.
    """
    digest = hashlib.sha256()
    for path in files:
        content = path.read_bytes()
        digest.update(f"{path.name}\0{len(content)}\0".encode())
        digest.update(content)
    return digest.hexdigest()


def read_index(path: Path) -> dict:
    """Decompress and parse the bundle's index.

    Args:
        path (Path): The compressed index file.

    Returns:
        dict: The index, as `build_bundle` wrote it.
    """
    return json.loads(zlib.decompress(path.read_bytes()))


def bundle_problems(files: list[Path], selection: dict | None) -> list[str]:
    """Check the bundle is whole, and agrees with the committed selection.

    Args:
        files (`list[Path]`): The bundle's files, index first.
        selection (dict | None): The parsed selection, when there is one.

    Returns:
        `list[str]`: What is wrong. Empty when every drug's line holds that
        drug's text, and the drugs and labels are the selection's.
    """
    index = read_index(files[0])
    chunk_files = files[1:]
    if index.get("schema_version") != BUNDLE_SCHEMA_VERSION:
        return ["the index's schema_version is not one this generator writes"]
    if index["chunks"] != len(chunk_files):
        return [f"the index expects {index['chunks']} chunks, and there are {len(chunk_files)}"]

    problems = []
    chunks = [zlib.decompress(path.read_bytes()).decode().split("\n") for path in chunk_files]
    for row in index["entries"]:
        lines = chunks[row["chunk"]] if row["chunk"] < len(chunks) else []
        record = json.loads(lines[row["line"]]) if row["line"] < len(lines) else {}
        if record.get("key") != row["key"]:
            problems.append(f"{row['key']} does not point at its own text")
            break
    if selection is not None:
        drugs = [(e["key"], e["label"]["set_id"]) for e in selection["entries"]]
        indexed = [(row["key"], row["label"]["set_id"]) for row in index["entries"]]
        matching = [(e["classes"], e["match"]) for e in selection["entries"]]
        if drugs != indexed:
            problems.append("its drugs or labels are not the selection's")
        elif matching != [(row["classes"], row["match"]) for row in index["entries"]]:
            problems.append("its classes or match terms are not the selection's")
        if index["export_date"] != selection["meta"]["export_date"]:
            problems.append("it was built from a different export than the selection")
    return problems


def dart_string(value: str) -> str:
    """Render `value` as a Dart single-quoted literal.

    Args:
        value (str): The text.

    Returns:
        str: The literal, with quotes, dollar signs, backslashes and newlines
        escaped.
    """
    escaped = (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\n", "\\n")
        .replace("\r", "")
    )
    return f"'{escaped}'"


def render(index: dict | None, digest: str) -> str:
    """Return the full text of the generated Dart file.

    Rendered so that the output is already `dart format` clean. It has to be:
    `--check` compares the file byte for byte against a fresh render, and the
    repo's format gate rewrites anything that is not formatted. A generator
    whose output the formatter touches makes those two checks fight.

    Args:
        index (dict | None): The bundle's index, or None when there is none.
        digest (str): `bundle_digest` of the bundle's files.

    Returns:
        str: The file's full text.
    """
    if index is not None and index.get("schema_version") != BUNDLE_SCHEMA_VERSION:
        raise SystemExit(
            f"error: bundle schema_version {index.get('schema_version')} is not "
            f"{BUNDLE_SCHEMA_VERSION}; this generator does not know how to read it"
        )
    fetched = index is not None
    snapshot = "null" if index is None else dart_string(index["export_date"])
    count = 0 if index is None else len(index["entries"])
    chunks = 0 if index is None else index["chunks"]
    disclaimer = DISCLAIMER if index is None else index["disclaimer"]

    return f"""// GENERATED BY tools/scripts/gen_medicines.py. DO NOT EDIT BY HAND.
//
// Regenerate with:
//     python3 tools/scripts/gen_medicines.py --fetch
//
// The label text is in app/assets/medicines, compressed. This file carries only
// what the app needs before it opens that bundle. The phone makes no request
// for any of it: the fetch happens in the generator, and the app has no
// INTERNET permission at all (ADR-0004).

/// Bundled medicines reference: what is known before the bundle is opened.
///
/// The bundle in `app/assets/medicines` holds every drug's label sections and
/// the index the lookup searches. This file carries its checksum, its size and
/// the date of the export it was built from, so that a screen can say what it
/// is showing without loading any of it.
///
/// Includes:
///     - medicinesBundleSha256: Checksum of the bundle's files.
///     - medicinesFetched: Whether a bundle has been built at all.
///     - medicinesSnapshotDate: The date of the openFDA export.
///     - medicinesCount: How many drugs the bundle holds.
///     - medicinesChunkCount: How many compressed text chunks it has.
///     - medicinesJurisdiction: Where the labelling applies.
///     - medicinesDisclaimer: What the screen says about the source.
library;

/// SHA-256 over the files in `app/assets/medicines`: names, lengths, contents.
///
/// A drift guard, not a security boundary: `gen_medicines.py --check` fails CI
/// if the bundle and this file stop matching.
const String medicinesBundleSha256 =
    '{digest}';

/// Whether a bundle has been built from openFDA at all.
///
/// False in a repository where nobody has run `--fetch` yet. The app renders
/// an explanation rather than an empty screen in that case, and a release-gate
/// test reports it. Shipping an empty reference section silently would be
/// worse than not having one.
const bool medicinesFetched = {str(fetched).lower()};

/// The date of the openFDA export the bundle came from, or null if none did.
///
/// Displayed on the screen. Drug labelling changes, and a reference with no
/// date on it invites the reader to assume it is current.
// Nullable whichever state this file is generated in, so that the code reading
// it compiles in both.
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? medicinesSnapshotDate = {snapshot};

/// How many drugs the bundle holds.
const int medicinesCount = {count};

/// How many compressed text chunks the label sections are split into.
const int medicinesChunkCount = {chunks};

/// The jurisdiction this labelling comes from.
///
/// **US**, and the screen says so. Strengths, brand names, available
/// formulations and warnings differ everywhere else, and a user reading US
/// warnings about a box bought elsewhere is being quietly misinformed.
const String medicinesJurisdiction = 'US';

/// The notice openFDA asks to travel with the data.
const String medicinesDisclaimer =
    {dart_string(disclaimer)};
"""


def main() -> int:
    """Run the generator from the command line.

    Returns:
        int: 0 on success, 1 when a fetch fails or `--check` finds a stale or
        malformed file, and 2 for flags that cannot be combined.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fetch",
        action="store_true",
        help="download openFDA's label export and rebuild the selection and bundle",
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
        help="exit non-zero if a generated file is stale or malformed, and write nothing",
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
            sections = extract_sections(local, entries)
        except (urllib.error.URLError, TimeoutError, OSError, zipfile.BadZipFile) as error:
            # Reported rather than swallowed, and nothing committed is touched.
            # A bundle built from part of the export would silently drop every
            # drug whose labels all sat in the missing part.
            print(f"error: reading openFDA's export failed: {error}", file=sys.stderr)
            print("the committed artifacts have not been modified.", file=sys.stderr)
            return 1
        index, chunks = build_bundle(meta, entries, sections)
        SELECTION.parent.mkdir(parents=True, exist_ok=True)
        SELECTION.write_text(selection_json(meta, entries), encoding="utf-8")
        write_bundle(BUNDLE, index, chunks)
        print(
            f"wrote {SELECTION.relative_to(REPO_ROOT)} and {len(chunks)} chunks to "
            f"{BUNDLE.relative_to(REPO_ROOT)}: {len(entries)} drugs from "
            f"{meta['counts']['labels']} labels"
        )

    files = bundle_files(BUNDLE)
    generated = render(read_index(files[0]) if files else None, bundle_digest(files))

    if args.check:
        failed = False
        selection = None
        if SELECTION.exists():
            text = SELECTION.read_text(encoding="utf-8")
            problems = selection_problems(text)
            for problem in problems:
                print(
                    f"error: {SELECTION.relative_to(REPO_ROOT)}: {problem}. "
                    "Rerun `--fetch` rather than editing it.",
                    file=sys.stderr,
                )
            failed = bool(problems)
            selection = None if problems else json.loads(text)
        if files:
            problems = bundle_problems(files, selection)
            for problem in problems:
                print(f"error: {BUNDLE.relative_to(REPO_ROOT)}: {problem}.", file=sys.stderr)
            failed = failed or bool(problems)
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
        print(f"OK: the selection, the bundle and {OUTPUT.name} agree")
        return 0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(generated, encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(REPO_ROOT)} (sha256 {bundle_digest(files)[:12]}...)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
