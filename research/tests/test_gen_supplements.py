"""The herbal supplements reference and its generator (ADR-0023).

NCCIH's Herbs at a Glance fact sheets are in the public domain, and
`tools/scripts/gen_supplements.py` reads them into
app/assets/supplements/nccih_herbs.json. What is pinned here: what is taken
from a page and what is left out (its photograph is copyrighted), the names a
label could print a herb by, that nothing carried says how much of a herb to
take, and that the committed reference and its Dart agree.
"""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "tools" / "scripts" / "gen_supplements.py"

# A page laid out as NCCIH's are: a header outside the main element, then the
# title, the names, the photograph and its credit, the sections, and the
# statements at the foot.
PAGE = """<html><body>
<header><nav><a href="/health/st-johns-wort">St. John's Wort</a></nav></header>
<main>
<h1>St. John\u2019s Wort</h1>
<p>Common Names: St. John\u2019s wort, hypericum, Klamath weed</p>
<p>Latin Names: Hypericum perforatum</p>
<figure><img src="sjw.jpg" alt="St. John's wort">
<figcaption>\u00a9 A Photographer</figcaption></figure>
<h2>Background</h2>
<ul><li>St. John\u2019s wort is a plant with yellow flowers.</li></ul>
<h2>What Do We Know About Safety?</h2>
<ul style="list-style-type:disc">
<li>If you take any type of medicine, talk with your health care provider.
<ul style="list-style-type:circle">
<li>For example, <strong>it can weaken many medicines</strong> such as:
<ul style="list-style-type:square"><li>Birth control pills</li><li>Warfarin</li></ul>
</li></ul></li>
</ul>
<h2>Keep in Mind</h2>
<p>Take charge of your health.</p>
<h2>For More Information</h2>
<p>NCCIH Clearinghouse, toll-free 1-888-644-6226.</p>
<p>This publication is not copyrighted and is in the public domain. Duplication is encouraged.</p>
<p>NCCIH has provided this material for your information. It is not intended to substitute for
the medical expertise and advice of your health care provider(s).</p>
<div class="row"><div class="col"><b>Last Updated: </b>May 2025</div></div>
</main>
<footer><p>Footer text</p></footer>
</body></html>"""


def load_generator():
    """Import the generator as a module, since it is a script, not a package."""
    spec = importlib.util.spec_from_file_location("gen_supplements", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def gen():
    return load_generator()


@pytest.fixture(scope="module")
def rules(gen):
    return gen._guide_rules()


@pytest.fixture(scope="module")
def page(gen) -> dict:
    herb = gen.parse_fact_sheet(PAGE, "st-johns-wort")
    assert herb is not None
    return herb


@pytest.fixture(scope="module")
def committed(gen) -> dict:
    if not gen.ASSET.exists():
        pytest.skip("no supplements reference has been fetched yet")
    return json.loads(gen.ASSET.read_text(encoding="utf-8"))


def herb_named(data: dict, key: str) -> dict:
    return next(herb for herb in data["herbs"] if herb["key"] == key)


def safety(herb: dict) -> list[str]:
    return next(blocks for heading, blocks in herb["sections"] if heading.endswith("Safety?"))


class TestReadingAPage:
    def test_takes_its_title_names_and_date(self, page: dict) -> None:
        assert page["name"] == "St. John\u2019s Wort"
        assert page["common_names"] == ["St. John\u2019s wort", "hypericum", "Klamath weed"]
        assert page["latin_names"] == ["Hypericum perforatum"]
        assert page["updated"] == "May 2025"
        assert page["url"] == "https://www.nccih.nih.gov/health/st-johns-wort"

    def test_a_date_in_a_paragraph_is_a_date_and_not_a_line(self, gen) -> None:
        page = PAGE.replace(
            '<div class="row"><div class="col"><b>Last Updated: </b>May 2025</div></div>',
            "<p>Last Updated: May 2025</p>",
        )
        herb = gen.parse_fact_sheet(page, "st-johns-wort")
        assert herb["updated"] == "May 2025"
        assert "Last Updated" not in json.dumps(herb["sections"])

    def test_keeps_the_sections_up_to_keep_in_mind(self, page: dict) -> None:
        # "For More Information" is phone numbers and links.
        headings = [heading for heading, _ in page["sections"]]
        assert headings == ["Background", "What Do We Know About Safety?", "Keep in Mind"]

    def test_a_list_item_starts_with_the_mark_the_page_draws(self, page: dict) -> None:
        assert safety(page) == [
            "\u2022 If you take any type of medicine, talk with your health care provider.",
            "\u25e6 For example, it can weaken many medicines such as:",
            "\u25aa Birth control pills",
            "\u25aa Warfarin",
        ]

    def test_a_paragraph_has_no_mark(self, page: dict) -> None:
        assert page["sections"][-1] == ["Keep in Mind", ["Take charge of your health."]]

    def test_leaves_out_the_photograph_and_its_credit(self, page: dict) -> None:
        # The photographs are not NCCIH's to put in the public domain.
        assert "\u00a9" not in json.dumps(page, ensure_ascii=False)
        assert "Photographer" not in json.dumps(page)

    def test_reads_nothing_outside_the_main_element(self, page: dict) -> None:
        text = json.dumps(page)
        assert "Footer text" not in text
        assert "1-888" not in text

    def test_keeps_the_disclaimer_for_the_reference_to_carry(self, page: dict) -> None:
        assert page["disclaimer"].startswith("NCCIH has provided this material")

    def test_a_page_not_in_the_public_domain_is_not_carried(self, gen) -> None:
        page = PAGE.replace("This publication is not copyrighted", "This publication is")
        assert gen.parse_fact_sheet(page, "st-johns-wort") is None

    def test_a_page_without_latin_names_is_not_a_fact_sheet(self, gen) -> None:
        page = PAGE.replace("<p>Latin Names: Hypericum perforatum</p>", "")
        assert gen.parse_fact_sheet(page, "st-johns-wort") is None

    def test_the_index_lists_each_page_once_in_order(self, gen) -> None:
        index = (
            '<a href="/health/acai">Acai</a> <a href="/health/aloe-vera">Aloe</a>'
            ' <a href="/health/acai">again</a> <a href="https://example.org/health/x">x</a>'
        )
        assert gen.fact_sheet_links(index) == ["acai", "aloe-vera"]


class TestNames:
    def test_a_comma_inside_parentheses_belongs_to_its_note(self, gen) -> None:
        listed = (
            "cat\u2019s claw, u\u00f1a de gato (not to be confused with cat\u2019s foot, "
            "which is different)"
        )
        assert gen.split_names(listed) == [
            "cat\u2019s claw",
            "u\u00f1a de gato (not to be confused with cat\u2019s foot, which is different)",
        ]

    def test_a_note_in_parentheses_is_not_looked_for(self, gen) -> None:
        terms = gen.match_terms("Acai", ["acai (pronounced AH-sigh-EE)"], ["Euterpe oleracea"])
        assert terms == ["acai", "euterpe oleracea"]

    def test_another_name_in_parentheses_is(self, gen) -> None:
        terms = gen.match_terms(
            "Butterbur",
            ["butterbur"],
            ["Petasites hybridus (also known as Petasites officinalis or Tussilago hybrida)"],
        )
        assert terms == [
            "butterbur",
            "petasites hybridus",
            "petasites officinalis",
            "tussilago hybrida",
        ]
        terms = gen.match_terms(
            "Hawthorn", [], ["Crataegus pinnatifida (synonym Crataegus oxycantha)"]
        )
        assert "crataegus oxycantha" in terms

    def test_a_listed_synonym_is_looked_for_without_the_word(self, gen) -> None:
        terms = gen.match_terms(
            "Turmeric", [], ["Curcuma longa", "synonym Curcuma domestica; Curcuma aromatica"]
        )
        assert terms == ["curcuma aromatica", "curcuma domestica", "curcuma longa", "turmeric"]

    def test_a_possessive_is_looked_for_with_and_without_its_apostrophe(self, gen) -> None:
        terms = gen.match_terms(
            "St. John\u2019s Wort", ["St. John\u2019s wort"], ["Hypericum perforatum"]
        )
        assert terms == ["hypericum perforatum", "st. john's wort", "st. johns wort"]

    def test_a_hybrid_is_looked_for_without_its_x(self, gen) -> None:
        terms = gen.match_terms("Peppermint Oil", ["peppermint"], ["Mentha x piperita"])
        assert "mentha x piperita" in terms
        assert "mentha piperita" in terms

    def test_an_abbreviation_is_not_looked_for(self, gen) -> None:
        # EPO is erythropoietin to a label, and a label naming it would be
        # said to name evening primrose oil.
        terms = gen.match_terms(
            "Evening Primrose Oil", ["evening primrose oil", "EPO"], ["Oenothera biennis"]
        )
        assert terms == ["evening primrose oil", "oenothera biennis"]


class TestProblems:
    def problems(self, gen, rules, edit) -> list[str]:
        herb = gen.parse_fact_sheet(PAGE, "st-johns-wort")
        edit(herb)
        return gen.herb_problems(herb, rules)

    def test_the_page_has_none(self, gen, rules) -> None:
        assert self.problems(gen, rules, lambda herb: None) == []

    def test_an_instruction_to_take_an_amount_is_one(self, gen, rules) -> None:
        def edit(herb: dict) -> None:
            herb["sections"][0][1].append("\u2022 Take 300 mg three times a day.")

        assert any("how much to take" in problem for problem in self.problems(gen, rules, edit))

    def test_so_is_one_nested_deep_in_a_list(self, gen, rules) -> None:
        # The square mark is not one the Medication Guide rules know.
        def edit(herb: dict) -> None:
            herb["sections"][1][1].append("\u25aa Take 2 capsules daily")

        assert any("how much to take" in problem for problem in self.problems(gen, rules, edit))

    def test_what_a_study_gave_is_not(self, gen, rules) -> None:
        # Goldenseal's sheet says what doses were studied, which tells nobody
        # what to take.
        sentence = (
            "\u2022 In small research studies, goldenseal has been administered at doses of "
            "about 3 g per day for short periods of time without serious harmful effects."
        )

        def edit(herb: dict) -> None:
            herb["sections"][1][1].append(sentence)

        assert self.problems(gen, rules, edit) == []

    def test_a_missing_safety_section_is_one(self, gen, rules) -> None:
        def edit(herb: dict) -> None:
            herb["sections"] = [section for section in herb["sections"] if section[0] != gen.SAFETY]

        assert any("What Do We Know" in problem for problem in self.problems(gen, rules, edit))

    def test_sections_out_of_order_are_one(self, gen, rules) -> None:
        def edit(herb: dict) -> None:
            herb["sections"].reverse()

        assert any("out of order" in problem for problem in self.problems(gen, rules, edit))

    def test_a_herb_with_nothing_to_look_for_is_one(self, gen, rules) -> None:
        def edit(herb: dict) -> None:
            herb["match"] = []

        assert any("look for" in problem for problem in self.problems(gen, rules, edit))

    def test_a_name_two_herbs_share_is_one(self, gen, rules, committed: dict) -> None:
        data = copy.deepcopy(committed)
        herb_named(data, "mugwort")["match"].append("st. john's wort")
        problems = gen.reference_problems(data, rules)
        assert '"st. john\'s wort" names both mugwort and st-johns-wort' in problems

    def test_a_lost_disclaimer_is_one(self, gen, rules, committed: dict) -> None:
        data = copy.deepcopy(committed)
        data["disclaimer"] = ""
        assert "it has lost NCCIH's disclaimer" in gen.reference_problems(data, rules)

    def test_herbs_out_of_order_are_one(self, gen, rules, committed: dict) -> None:
        data = copy.deepcopy(committed)
        data["herbs"].reverse()
        assert "its herbs are not each once, in key order" in gen.reference_problems(data, rules)


class TestTheCommittedReference:
    def test_is_fit_to_ship(self, gen, rules, committed: dict) -> None:
        assert gen.reference_problems(committed, rules) == []

    def test_is_formatted_as_the_generator_writes_it(self, gen, committed: dict) -> None:
        assert gen.ASSET.read_text(encoding="utf-8") == gen.reference_json(committed)

    def test_the_generated_dart_is_current(self, gen, committed: dict) -> None:
        digest = hashlib.sha256(gen.ASSET.read_bytes()).hexdigest()
        assert gen.OUTPUT.read_text(encoding="utf-8") == gen.render(committed, digest)

    def test_says_where_it_is_from(self, gen, committed: dict) -> None:
        assert committed["public_domain"] == gen.PUBLIC_DOMAIN
        assert committed["index_url"] == "https://www.nccih.nih.gov/health/herbsataglance"
        for herb in committed["herbs"]:
            assert herb["url"] == f"https://www.nccih.nih.gov/health/{herb['key']}"
            assert herb["updated"]

    def test_holds_the_herbs_a_period_tracker_is_asked_about(self, committed: dict) -> None:
        keys = {herb["key"] for herb in committed["herbs"]}
        assert {
            "black-cohosh",
            "chasteberry",
            "evening-primrose-oil",
            "red-clover",
            "st-johns-wort",
        } <= keys
        assert len(keys) >= 50

    def test_carries_no_photograph_credit(self, committed: dict) -> None:
        assert "\u00a9" not in json.dumps(committed, ensure_ascii=False)

    def test_st_johns_wort_names_the_pill_and_warfarin(self, committed: dict) -> None:
        blocks = safety(herb_named(committed, "st-johns-wort"))
        assert "\u25aa Birth control pills" in blocks
        assert any(block.startswith("\u25aa Warfarin") for block in blocks)

    def test_st_johns_wort_is_looked_for_as_labels_print_it(self, committed: dict) -> None:
        terms = herb_named(committed, "st-johns-wort")["match"]
        assert {"st. john's wort", "st. johns wort", "hypericum perforatum"} <= set(terms)

    def test_no_abbreviation_is_looked_for(self, gen, committed: dict) -> None:
        for herb in committed["herbs"]:
            assert "epo" not in herb["match"], herb["key"]
            for name in herb["common_names"] + herb["latin_names"]:
                if gen.is_abbreviation(name):
                    assert name.lower() not in herb["match"], herb["key"]


class TestRendering:
    def test_says_the_digest_count_and_date(self, gen) -> None:
        data = {"fetched": "2026-10-28", "herbs": [{}, {}]}
        text = gen.render(data, "ab" * 32)
        assert f"const String supplementsAssetSha256 =\n    '{'ab' * 32}';" in text
        assert "const int supplementsCount = 2;" in text
        assert "const String? supplementsFetchedDate = '2026-10-28';" in text

    def test_with_no_reference_there_is_no_date(self, gen) -> None:
        text = gen.render(None, "00" * 32)
        assert "const int supplementsCount = 0;" in text
        assert "const String? supplementsFetchedDate = null;" in text


class TestTheCommandLine:
    def run(self, *flags: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *flags],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_fetch_and_check_are_not_combined(self) -> None:
        assert self.run("--fetch", "--check").returncode == 2

    def test_check_passes_on_what_is_committed(self, committed: dict) -> None:
        result = self.run("--check")
        assert result.returncode == 0, result.stderr
