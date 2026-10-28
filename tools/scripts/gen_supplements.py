#!/usr/bin/env python3
"""Generate the herbal supplements reference from NCCIH's Herbs at a Glance.

The US National Center for Complementary and Integrative Health publishes a
fact sheet for each of some sixty herbs: what it is, what research has found,
and what is known about its safety, including the medicines it interacts
with. Each says it "is not copyrighted and is in the public domain." The app
carries them so that a herb can be read about, and compared with medicines in
the interaction checker, with no network at all (ADR-0004, ADR-0023).

As with the medicines (gen_medicines.py), the fetch happens here, on a
developer machine, and what it produces is committed. The phone never makes a
request.

Pipeline:
    1. Fetch the Herbs at a Glance index, and every page it links to.
    2. Keep the pages that are fact sheets: those with common and Latin names
       and the public-domain statement.
    3. Take each one's names, its sections from the background to "Keep in
       Mind", and when it was last updated. Its photograph, which is not in
       the public domain, its references and its links are left out.
    4. Work out, from its names, the words a label could print it by: what
       the interaction checker looks for (`match_terms`).
    5. Hold every section to the rule the Medication Guides are held to
       (ADR-0022): no instruction to take an amount of anything. A page that
       gave one would be left out whole. None does.
    6. Write app/assets/supplements/nccih_herbs.json, and the Dart that knows
       its checksum.

Usage:
    python3 tools/scripts/gen_supplements.py --fetch   # needs network
    python3 tools/scripts/gen_supplements.py           # regenerate the Dart only
    python3 tools/scripts/gen_supplements.py --check   # CI gate, writes nothing
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import sys
import time
import urllib.error
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET = REPO_ROOT / "app" / "assets" / "supplements" / "nccih_herbs.json"
OUTPUT = REPO_ROOT / "app" / "lib" / "data" / "reference" / "supplements_bundled.dart"

SCHEMA_VERSION = 1
BASE_URL = "https://www.nccih.nih.gov"
INDEX_URL = f"{BASE_URL}/health/herbsataglance"
HEADERS = {"User-Agent": "period-tracker-supplements-generator"}
FETCH_ATTEMPTS = 3
# Between two requests to NCCIH, so that sixty pages are not sixty at once.
FETCH_PAUSE = 0.5

# The sections carried, in the order every fact sheet has them. What follows,
# "For More Information" and the references, is links and citations.
SECTIONS: tuple[str, ...] = (
    "Background",
    "How Much Do We Know?",
    "What Have We Learned?",
    "What Do We Know About Safety?",
    "Keep in Mind",
)
SAFETY = "What Do We Know About Safety?"
PUBLIC_DOMAIN = "This publication is not copyrighted and is in the public domain."
# NCCIH's own words, carried with the pages as openFDA's are with the labels.
DISCLAIMER_START = "NCCIH has provided this material for your information."

# Elements whose text is never carried: styles, scripts, and the photograph
# with its credit, which is copyrighted.
SKIPPED = frozenset({"style", "script", "noscript", "svg", "figure", "figcaption"})
BLOCKS = frozenset({"p", "li"})
# What starts a list item, by how deep it is nested: the disc, circle and
# square the pages themselves draw.
MARKS = ("\u2022 ", "\u25e6 ", "\u25aa ")

# A note in parentheses that gives another name for the plant, rather than
# saying something about it: "(also known as Petasites officinalis or
# Tussilago hybrida)", "(synonym Crataegus oxycantha)". A Latin name listed
# outside parentheses can start the same way: "synonym Carduus marianus".
ANOTHER_NAME = re.compile(r"^(?:also known as|synonyms?)\s+", re.IGNORECASE)
# What separates the names in such a note.
NAME_LIST = re.compile(r",|;|\s+(?:or|and)\s+")
# A hybrid's "x", as in "Mentha x piperita".
HYBRID = re.compile(r"\sx\s")


def _guide_rules():
    """Import the Medication Guide rules from gen_medicines.py, its sibling."""
    path = Path(__file__).with_name("gen_medicines.py")
    spec = importlib.util.spec_from_file_location("gen_medicines", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"error: cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def words_only(text: str) -> str:
    """Collapse a run of whitespace to one space, and trim it."""
    return " ".join(text.split())


class FactSheet(HTMLParser):
    """Read one NCCIH page: its title, names, sections and date.

    Attributes:
        title (str): The page's heading.
        common (str): The text after "Common Names:".
        latin (str): The text after "Latin Names:".
        sections (`list[tuple[str, list[str]]]`): Each heading under the
            page's main element, and its paragraphs and list items. A list
            item starts with the mark the page draws for it: a bullet, a
            hollow one for an item nested in another, and a square for one
            nested deeper (`MARKS`).
        updated (str): The text after "Last Updated:".
        public_domain (bool): Whether the page says it is in the public domain.
        disclaimer (str): NCCIH's note that the page is not medical advice.
    """

    def __init__(self) -> None:
        """Start reading."""
        super().__init__(convert_charrefs=True)
        self.title = ""
        self.common = ""
        self.latin = ""
        self.sections: list[tuple[str, list[str]]] = []
        self.updated = ""
        self.public_domain = False
        self.disclaimer = ""
        self._main = False
        self._skip = 0
        self._tags: list[str] = []
        self._text: list[str] | None = None
        self._heading: list[str] | None = None
        self._label = ""
        self._lists = 0

    def handle_starttag(self, tag: str, _attrs: list[tuple[str, str | None]]) -> None:
        """Note where the page's text starts, and where each block does."""
        if tag == "main":
            self._main = True
        if not self._main:
            return
        if tag in SKIPPED:
            self._skip += 1
            return
        if self._skip:
            return
        if tag in ("ul", "ol"):
            # A list inside a list item ends the item's own text.
            self._flush()
            self._lists += 1
        if tag in ("h1", "h2"):
            self._heading = []
        elif tag in BLOCKS:
            self._flush()
            self._text = []
        self._tags.append(tag)

    def handle_endtag(self, tag: str) -> None:
        """Close a heading or a block."""
        if not self._main:
            return
        if tag in SKIPPED:
            self._skip = max(0, self._skip - 1)
            return
        if self._skip:
            return
        if tag == "main":
            self._flush()
            self._main = False
            return
        if tag in ("ul", "ol"):
            self._lists = max(0, self._lists - 1)
        if tag in ("h1", "h2") and self._heading is not None:
            heading = words_only("".join(self._heading))
            self._heading = None
            if tag == "h1" and not self.title:
                self.title = heading
            elif tag == "h2":
                self.sections.append((heading, []))
        elif tag in BLOCKS:
            self._flush()

    def handle_data(self, data: str) -> None:
        """Gather text into the heading or block it belongs to."""
        if not self._main or self._skip:
            return
        if self._heading is not None:
            self._heading.append(data)
        elif self._text is not None:
            self._text.append(data)
        elif "Last Updated:" in data:
            self._label = "updated"
        elif self._label == "updated" and data.strip():
            self.updated = words_only(data)
            self._label = ""

    def _flush(self) -> None:
        """End the block being gathered, and file it."""
        if self._text is None:
            return
        text = words_only("".join(self._text))
        self._text = None
        if not text:
            return
        if text.startswith("Common Names:"):
            self.common = text.removeprefix("Common Names:").strip()
        elif text.startswith("Latin Names:"):
            self.latin = text.removeprefix("Latin Names:").strip()
        elif text.startswith(PUBLIC_DOMAIN):
            self.public_domain = True
        elif text.startswith(DISCLAIMER_START):
            self.disclaimer = text
        elif text.startswith("Last Updated:"):
            # Where a page puts its date in a paragraph rather than after a
            # bold label: a date, not a line of its last section.
            self.updated = text.removeprefix("Last Updated:").strip()
        elif self.sections:
            mark = MARKS[min(self._lists, len(MARKS)) - 1] if self._lists else ""
            self.sections[-1][1].append(mark + text)


def outside_parentheses(text: str, separators: str) -> list[str]:
    """Split `text` at each of `separators` that is not inside parentheses.

    Args:
        text (str): Some names, as a page lists them.
        separators (str): The characters to split at.

    Returns:
        `list[str]`: The parts, trimmed, leaving out any that are empty.
    """
    parts = []
    depth = start = 0
    for i, char in enumerate(text):
        if char == "(":
            depth += 1
        elif char == ")":
            depth = max(0, depth - 1)
        elif char in separators and depth == 0:
            parts.append(text[start:i])
            start = i + 1
    parts.append(text[start:])
    return [part.strip() for part in parts if part.strip()]


def split_names(text: str) -> list[str]:
    """Split a list of names on its commas, keeping none twice.

    A comma inside parentheses belongs to the note it is in: "uña de gato (not
    to be confused with cat's foot or devil's claw, which are different
    plants)" is one name.
    """
    return list(dict.fromkeys(outside_parentheses(text, ",")))


def unmarked(block: str) -> str:
    """Return a paragraph or list item without the mark that starts it."""
    for mark in MARKS:
        if block.startswith(mark):
            return block.removeprefix(mark)
    return block


def is_abbreviation(name: str) -> bool:
    """Whether `name` is written in capitals, as "EPO" is."""
    letters = [char for char in name if char.isalpha()]
    return bool(letters) and all(char.isupper() for char in letters)


def match_terms(name: str, common: list[str], latin: list[str]) -> list[str]:
    """Every name a medicine's label could print a herb by.

    What the interaction checker looks for in labels (ADR-0023), from NCCIH's
    own names for the herb: its title, its common names and its Latin ones. A
    note in parentheses is left out, "acai (pronounced AH-sigh-EE)", unless
    it gives another name, "(synonym Crataegus oxycantha)".

    Each name is in lower case, with a straight apostrophe. One with a
    possessive is there without its apostrophe too, as labels print "St.
    Johns Wort", and a hybrid without its "x", as they print "Mentha
    piperita". An abbreviation is left out: "EPO" is evening primrose oil's,
    and erythropoietin's too.

    Args:
        name (str): The page's title.
        common (`list[str]`): Its common names, as the page lists them.
        latin (`list[str]`): Its Latin names, likewise.

    Returns:
        `list[str]`: The names, sorted, each once.
    """
    found = []
    for listed in (name, *common, *latin):
        for part in outside_parentheses(listed, ";"):
            for note in re.findall(r"\(([^()]*)\)", part):
                if ANOTHER_NAME.match(note.strip()):
                    found.extend(NAME_LIST.split(ANOTHER_NAME.sub("", note.strip())))
            found.append(ANOTHER_NAME.sub("", re.sub(r"\([^()]*\)", " ", part).strip()))
    terms = set()
    for candidate in found:
        candidate = words_only(candidate.replace("\u2019", "'").replace("\u2018", "'"))
        if not candidate or is_abbreviation(candidate):
            continue
        term = candidate.lower()
        terms.add(term)
        if "'s" in term:
            terms.add(term.replace("'s", "s"))
        if HYBRID.search(term):
            terms.add(HYBRID.sub(" ", term))
    return sorted(terms)


def parse_fact_sheet(html: str, slug: str) -> dict | None:
    """Read a page, if it is a herb's fact sheet.

    Args:
        html (str): The page.
        slug (str): Its path under /health/: "st-johns-wort".

    Returns:
        dict | None: The herb, or None for a page that is not a fact sheet:
        one without common and Latin names, or without the public-domain
        statement, whose text this project may not carry.
    """
    page = FactSheet()
    page.feed(html)
    page.close()
    if not (page.common and page.latin and page.public_domain and page.title):
        return None
    kept = [[heading, blocks] for heading, blocks in page.sections if heading in SECTIONS]
    common = split_names(page.common)
    latin = split_names(page.latin)
    return {
        "common_names": common,
        "disclaimer": page.disclaimer,
        "key": slug,
        "latin_names": latin,
        "match": match_terms(page.title, common, latin),
        "name": page.title,
        "sections": kept,
        "updated": page.updated,
        "url": f"{BASE_URL}/health/{slug}",
    }


def fact_sheet_links(index_html: str) -> list[str]:
    """List every page the index links to, by its slug, in order, once each."""
    return list(dict.fromkeys(re.findall(r'href="/health/([a-z0-9-]+)"', index_html)))


def herb_problems(herb: dict, rules) -> list[str]:
    """Check one herb is whole, and gives no amount to take.

    Args:
        herb (dict): From `parse_fact_sheet`.
        rules: gen_medicines.py, for the Medication Guide rules.

    Returns:
        `list[str]`: What is wrong with it.
    """
    problems = []
    headings = [heading for heading, _ in herb["sections"]]
    for needed in ("Background", SAFETY):
        if needed not in headings:
            problems.append(f"{herb['key']} has no {needed!r}")
    if headings != sorted(headings, key=SECTIONS.index):
        problems.append(f"{herb['key']}'s sections are out of order")
    for heading, blocks in herb["sections"]:
        if not blocks:
            problems.append(f"{herb['key']}: {heading!r} is empty")
        for block in blocks:
            # Without its mark, which the guide rules do not all know.
            block = unmarked(block)
            for sentence in rules.GUIDE_SENTENCE.split(block):
                sentence = sentence.strip()
                if rules.GUIDE_DOSE_INSTRUCTION.search(sentence) and rules.GUIDE_AMOUNT.search(
                    sentence
                ):
                    problems.append(f"{herb['key']} says how much to take: {sentence[:80]!r}")
            found = rules.GUIDE_DOSING.search(block)
            if found:
                problems.append(f"{herb['key']} gives dosing: {found.group(0)!r}")
    if not herb["updated"]:
        problems.append(f"{herb['key']} has no date")
    if not herb["common_names"] or not herb["latin_names"]:
        problems.append(f"{herb['key']} has no names")
    if not herb.get("match"):
        problems.append(f"{herb['key']} has no names to look for in a label")
    for term in herb.get("match", []):
        if not re.search(r"[a-z]", term) or term != term.lower():
            problems.append(f"{herb['key']} would be looked for as {term!r}")
    return problems


def reference_problems(data: dict, rules) -> list[str]:
    """Check the whole reference, as it would be committed.

    Args:
        data (dict): The reference.
        rules: gen_medicines.py, for the Medication Guide rules.

    Returns:
        `list[str]`: What is wrong with it. Empty for one fit to ship.
    """
    if data.get("schema_version") != SCHEMA_VERSION:
        return [f"schema_version is not {SCHEMA_VERSION}"]
    herbs = data.get("herbs") or []
    problems = [] if herbs else ["it holds no herbs"]
    if not str(data.get("disclaimer", "")).startswith(DISCLAIMER_START):
        problems.append("it has lost NCCIH's disclaimer")
    keys = [herb["key"] for herb in herbs]
    if keys != sorted(keys) or len(set(keys)) != len(keys):
        problems.append("its herbs are not each once, in key order")
    owners: dict[str, str] = {}
    for herb in herbs:
        problems.extend(herb_problems(herb, rules))
        # A label naming one of these would be said to name both herbs.
        for term in herb.get("match", []):
            owner = owners.setdefault(term, herb["key"])
            if owner != herb["key"]:
                problems.append(f"{term!r} names both {owner} and {herb['key']}")
    return problems


def reference_json(data: dict) -> str:
    """Render the reference as committed: indented, keys sorted, UTF-8."""
    return json.dumps(data, indent=1, sort_keys=True, ensure_ascii=False) + "\n"


def fetch(url: str) -> str:
    """Fetch a page, trying again on a failure, and decode it.

    Args:
        url (str): The page.

    Returns:
        str: Its text.

    Raises:
        urllib.error.URLError: When every attempt failed.
    """
    for attempt in range(FETCH_ATTEMPTS):
        try:
            request = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read().decode("utf-8")
        except (urllib.error.URLError, TimeoutError):
            if attempt == FETCH_ATTEMPTS - 1:
                raise
            time.sleep(2**attempt)
    raise AssertionError("unreachable")


def build(fetched: str) -> dict:
    """Fetch every fact sheet, and assemble the reference.

    Args:
        fetched (str): Today's date, `YYYY-MM-DD`, recorded in the reference.

    Returns:
        dict: The reference.
    """
    index = fetch(INDEX_URL)
    herbs = []
    for slug in fact_sheet_links(index):
        time.sleep(FETCH_PAUSE)
        herb = parse_fact_sheet(fetch(f"{BASE_URL}/health/{slug}"), slug)
        if herb is not None:
            herbs.append(herb)
    herbs.sort(key=lambda herb: herb["key"])
    # Carried once, for every page: each prints the same words.
    disclaimers = {herb.pop("disclaimer") for herb in herbs}
    if len(disclaimers) != 1:
        raise SystemExit(f"error: the pages carry {len(disclaimers)} different disclaimers")
    return {
        "disclaimer": disclaimers.pop(),
        "fetched": fetched,
        "herbs": herbs,
        "index_url": INDEX_URL,
        "public_domain": PUBLIC_DOMAIN,
        "schema_version": SCHEMA_VERSION,
        "source": "National Center for Complementary and Integrative Health, Herbs at a Glance",
    }


def dart_string(value: str) -> str:
    """Render `value` as a Dart single-quoted literal."""
    escaped = (
        value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$").replace("\n", "\\n")
    )
    return f"'{escaped}'"


def render(data: dict | None, digest: str) -> str:
    """Return the full text of the generated Dart file.

    Args:
        data (dict | None): The reference, or None when none was fetched.
        digest (str): SHA-256 of the committed asset's bytes.

    Returns:
        str: The file's text, already `dart format` clean.
    """
    fetched = "null" if data is None else dart_string(data["fetched"])
    count = 0 if data is None else len(data["herbs"])
    return f"""// GENERATED BY tools/scripts/gen_supplements.py. DO NOT EDIT BY HAND.
//
// Regenerate with:
//     python3 tools/scripts/gen_supplements.py --fetch
//
// The fact sheets are in app/assets/supplements/nccih_herbs.json. The phone
// makes no request for any of them (ADR-0004, ADR-0023).

/// Bundled herbal supplements: what is known before the asset is opened.
///
/// Includes:
///     - supplementsAssetSha256: Checksum of the asset.
///     - supplementsCount: How many herbs it holds.
///     - supplementsFetchedDate: When NCCIH's pages were read.
library;

/// SHA-256 of `app/assets/supplements/nccih_herbs.json`.
///
/// A drift guard: `gen_supplements.py --check` fails CI when the asset and
/// this file stop matching.
const String supplementsAssetSha256 =
    '{digest}';

/// How many herbs the asset holds.
const int supplementsCount = {count};

/// When NCCIH's pages were read, `YYYY-MM-DD`, or null if they never were.
// Nullable whichever state this file is generated in, so that the code reading
// it compiles in both.
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? supplementsFetchedDate = {fetched};
"""


def main() -> int:
    """Run the generator from the command line.

    Returns:
        int: 0 on success, 1 when a fetch fails or `--check` finds a problem,
        and 2 for flags that cannot be combined.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true", help="read NCCIH's pages again")
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if the asset is unfit to ship or the Dart is stale",
    )
    args = parser.parse_args()
    if args.fetch and args.check:
        print("error: --fetch and --check are mutually exclusive", file=sys.stderr)
        return 2
    rules = _guide_rules()

    if args.fetch:
        try:
            data = build(time.strftime("%Y-%m-%d"))
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            print(f"error: reading NCCIH's pages failed: {error}", file=sys.stderr)
            print("the committed asset has not been modified.", file=sys.stderr)
            return 1
        problems = reference_problems(data, rules)
        for problem in problems:
            print(f"error: {problem}.", file=sys.stderr)
        if problems:
            print("the committed asset has not been modified.", file=sys.stderr)
            return 1
        ASSET.parent.mkdir(parents=True, exist_ok=True)
        ASSET.write_text(reference_json(data), encoding="utf-8")
        print(f"wrote {ASSET.relative_to(REPO_ROOT)}: {len(data['herbs'])} herbs")

    data = json.loads(ASSET.read_text(encoding="utf-8")) if ASSET.exists() else None
    digest = hashlib.sha256(ASSET.read_bytes() if ASSET.exists() else b"").hexdigest()
    generated = render(data, digest)

    if args.check:
        failed = False
        if data is not None:
            text = ASSET.read_text(encoding="utf-8")
            problems = reference_problems(data, rules)
            if text != reference_json(data):
                problems.append("it is not formatted as the generator writes it")
            for problem in problems:
                print(f"error: {ASSET.relative_to(REPO_ROOT)}: {problem}.", file=sys.stderr)
            failed = bool(problems)
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != generated:
            print(
                f"error: {OUTPUT.relative_to(REPO_ROOT)} is stale. Run "
                "`python3 tools/scripts/gen_supplements.py` and commit the result.",
                file=sys.stderr,
            )
            failed = True
        if failed:
            return 1
        print(f"OK: the supplements asset and {OUTPUT.name} agree")
        return 0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(generated, encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
