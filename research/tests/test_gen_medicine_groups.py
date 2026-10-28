"""The group names table and its generator (ADR-0021).

Labels name medicines by a group, "NSAIDs" or "combined hormonal
contraceptives", and `artifacts/medicines/groups_v1.json` says, from the
sources it cites, which drugs each group covers. What is pinned here: how a
rule decides what a drug is, that a malformed table is refused, that the
committed table agrees with the committed bundle, and that the drugs the table
was written to catch are caught while the ones it must not claim are not.

The last part reads the real bundle, because that is where this goes wrong: a
rule that is right on a drug built in a test can still take in every hormone
replacement product in the country.
"""

from __future__ import annotations

import copy
import importlib.util
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "tools" / "scripts" / "gen_medicine_groups.py"
DIGEST = "49cad45aaa0c88b3c020425afcaa77bbd496411f932e4bef1a770c0fa771e8f1"


def load_generator():
    """Import the generator as a module, since it is a script, not a package."""
    spec = importlib.util.spec_from_file_location("gen_medicine_groups", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def gen():
    return load_generator()


@pytest.fixture(scope="module")
def table(gen) -> dict:
    return json.loads(gen.TABLE.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def bundle(gen) -> tuple[dict, dict]:
    if not (gen.BUNDLE / gen.INDEX_NAME).exists():
        pytest.skip("no medicines bundle has been built yet")
    return gen.read_bundle(gen.BUNDLE)


@pytest.fixture(scope="module")
def resolved(gen, table: dict, bundle: tuple[dict, dict]) -> dict:
    return gen.resolve(table, *bundle)


def entry(key: str, *substances: str, routes: tuple[str, ...] = ("ORAL",)) -> dict:
    """Build an index row with only what the rules read."""
    return {"key": key, "substances": list(substances), "routes": list(routes), "match": []}


def resolver(gen, table: dict, entries: list[dict], uses: dict[str, str] | None = None):
    """A resolver over `entries`, each with the uses text `uses` gives it."""
    sections = {key: {"indications_and_usage": text} for key, text in (uses or {}).items()}
    return gen.Resolver(table, entries, sections)


def members(resolved: dict, name: str) -> set[str]:
    return next(set(g["members"]) for g in resolved["groups"] if g["name"] == name)


PREVENTS = "Indicated for use by females of reproductive potential to prevent pregnancy."


class TestWhatADrugContains:
    def test_a_salt_is_the_substance(self, gen, table: dict) -> None:
        naproxen = entry("naproxen-sodium.oral.otc", "NAPROXEN SODIUM")
        rules = resolver(gen, table, [naproxen])
        assert rules.select({"substances": ["naproxen"]}) == [naproxen["key"]]

    def test_a_name_inside_another_is_not_it(self, gen, table: dict) -> None:
        # Ethinyl estradiol is not estradiol, though its name ends with it.
        pill = entry("ee.oral.rx", "ETHINYL ESTRADIOL", "LEVONORGESTREL")
        rules = resolver(gen, table, [pill])
        assert rules.select({"substances": ["estradiol"]}) == []
        assert rules.select({"substances": ["ethinyl estradiol"]}) == [pill["key"]]

    def test_a_combination_contains_each_of_its_parts(self, gen, table: dict) -> None:
        excedrin = entry("aspirin+caffeine.oral.otc", "ASPIRIN", "CAFFEINE")
        rules = resolver(gen, table, [excedrin])
        assert rules.select({"substances": ["aspirin"]}) == [excedrin["key"]]

    def test_a_route_narrows_a_rule(self, gen, table: dict) -> None:
        tablets = entry("x.oral.rx", "X")
        patch = entry("x.transdermal.rx", "X", routes=("TRANSDERMAL",))
        rules = resolver(gen, table, [tablets, patch])
        assert rules.select({"substances": ["x"], "routes": ["ORAL"]}) == [tablets["key"]]


class TestWhatAContraceptiveIs:
    def test_one_whose_own_label_says_it_prevents_pregnancy(self, gen, table: dict) -> None:
        pill = entry("pill.oral.rx", "DROSPIRENONE", "ETHINYL ESTRADIOL")
        rules = resolver(gen, table, [pill], {pill["key"]: PREVENTS})
        assert rules.select({"contraceptive": "combined"}) == [pill["key"]]

    def test_not_one_that_mentions_contraception_anywhere_else(self, gen, table: dict) -> None:
        # Valproate's label tells women to use contraception, in its warnings.
        # Only a label's uses say what the drug is for.
        pill = entry("pill.oral.rx", "DROSPIRENONE", "ETHINYL ESTRADIOL")
        sections = {pill["key"]: {"warnings": "Use effective contraception."}}
        rules = gen.Resolver(table, [pill], sections)
        assert rules.select({"contraceptive": "any"}) == []

    def test_menopause_hormones_are_not_contraceptives(self, gen, table: dict) -> None:
        # The same two hormones as a pill, for a different use.
        hrt = entry("estradiol+norethindrone-acetate.oral.rx", "ESTRADIOL", "NORETHINDRONE ACETATE")
        uses = {hrt["key"]: "Treatment of moderate to severe vasomotor symptoms due to menopause."}
        rules = resolver(gen, table, [hrt], uses)
        assert rules.select({"contraceptive": "any"}) == []

    def test_combined_means_it_contains_an_estrogen(self, gen, table: dict) -> None:
        pill = entry("combined.oral.rx", "NORGESTIMATE", "ETHINYL ESTRADIOL")
        mini = entry("mini.oral.rx", "NORETHINDRONE")
        uses = {pill["key"]: PREVENTS, mini["key"]: PREVENTS}
        rules = resolver(gen, table, [pill, mini], uses)
        assert rules.select({"contraceptive": "combined"}) == [pill["key"]]
        assert rules.select({"contraceptive": "progestin-only"}) == [mini["key"]]
        assert rules.select({"contraceptive": "any"}) == [pill["key"], mini["key"]]

    def test_a_copper_iud_is_not_a_hormonal_one(self, gen, table: dict) -> None:
        copper = entry("copper.intrauterine.rx", "COPPER", routes=("INTRAUTERINE",))
        rules = resolver(gen, table, [copper], {copper["key"]: PREVENTS})
        assert rules.select({"contraceptive": "any"}) == []


class TestTheTableShape:
    def test_the_committed_table_is_well_formed(self, gen, table: dict) -> None:
        assert gen.table_problems(table) == []

    def test_two_groups_cannot_share_a_phrase(self, gen, table: dict) -> None:
        # Compared as words, as they are matched: "Non-steroidal" is
        # "non steroidal" either way.
        edited = copy.deepcopy(table)
        edited["groups"][1]["phrases"].append(edited["groups"][0]["phrases"][0].upper())
        assert any("share the phrase" in p for p in gen.table_problems(edited))

    def test_every_member_cites_a_source_the_table_lists(self, gen, table: dict) -> None:
        edited = copy.deepcopy(table)
        edited["groups"][0]["members"][0]["source"] = "somewhere"
        assert any("cites no source" in p for p in gen.table_problems(edited))

    def test_every_source_is_cited(self, gen, table: dict) -> None:
        edited = copy.deepcopy(table)
        edited["sources"]["unused"] = dict(edited["sources"]["epc-nsaid"])
        assert any("cited by nothing" in p for p in gen.table_problems(edited))

    def test_every_source_has_a_secure_address(self, gen, table: dict) -> None:
        edited = copy.deepcopy(table)
        edited["sources"]["epc-nsaid"]["url"] = "http://example.org"
        assert any("not https" in p for p in gen.table_problems(edited))

    def test_only_kinds_of_contraception_can_be_mapped(self, gen, table: dict) -> None:
        # Pregnancy and the rest have no substances to count as.
        edited = copy.deepcopy(table)
        edited["conditions"][0]["condition"] = "pregnancy"
        assert any("not a condition" in p for p in gen.table_problems(edited))

    def test_a_contraceptive_kind_is_one_of_three(self, gen, table: dict) -> None:
        edited = copy.deepcopy(table)
        edited["groups"][-1]["members"][0]["contraceptive"] = "barrier"
        assert any("contraceptive 'barrier'" in p for p in gen.table_problems(edited))


class TestTheTableAgainstTheBundle:
    def test_agrees_with_it(self, gen, table: dict, bundle: tuple[dict, dict]) -> None:
        assert gen.bundle_problems(table, *bundle) == []

    def test_a_typo_in_a_member_is_caught(self, gen, table: dict, bundle) -> None:
        edited = copy.deepcopy(table)
        edited["groups"][0]["members"][0]["substances"].append("ibuprofin")
        problems = gen.bundle_problems(edited, *bundle)
        assert any("no drug contains 'ibuprofin'" in p for p in problems)

    def test_an_absent_drug_that_arrives_is_caught(self, gen, table: dict, bundle) -> None:
        edited = copy.deepcopy(table)
        edited["groups"][0]["members"][1]["absent"].append("ibuprofen")
        problems = gen.bundle_problems(edited, *bundle)
        assert any("listed absent" in p for p in problems)

    def test_a_phrase_no_label_prints_is_caught(self, gen, table: dict, bundle) -> None:
        edited = copy.deepcopy(table)
        edited["groups"][0]["phrases"].append("pain relievers of the propionic sort")
        problems = gen.bundle_problems(edited, *bundle)
        assert any("no label prints" in p for p in problems)

    def test_the_generated_dart_is_current(self, gen, resolved: dict) -> None:
        generated = gen.render(resolved, gen.bundle_digest(gen.BUNDLE))
        assert gen.OUTPUT.read_text(encoding="utf-8") == generated, (
            "medicine_groups_bundled.dart is stale: run tools/scripts/gen_medicine_groups.py"
        )


class TestWhatTheGroupsCover:
    """The cases the table exists for, and the ones it must not claim."""

    def test_the_pill_is_every_kind_of_hormonal_contraceptive_it_should_be(
        self, resolved: dict
    ) -> None:
        yaz = "drospirenone+ethinyl-estradiol.oral.rx"
        for name in (
            "combined hormonal contraceptives",
            "combined oral contraceptives",
            "oral contraceptives",
            "hormonal contraceptives",
        ):
            assert yaz in members(resolved, name), name
        assert yaz not in members(resolved, "progestin-only contraceptives")

    def test_the_ring_and_the_patch_are_combined_but_not_oral(self, resolved: dict) -> None:
        for ring_or_patch in (
            "ethinyl-estradiol+etonogestrel.vaginal.rx",
            "ethinyl-estradiol+norelgestromin.transdermal.rx",
        ):
            assert ring_or_patch in members(resolved, "combined hormonal contraceptives")
            assert ring_or_patch not in members(resolved, "combined oral contraceptives")
            assert ring_or_patch not in members(resolved, "oral contraceptives")

    def test_the_iud_and_the_implant_are_progestin_only(self, resolved: dict) -> None:
        for device in ("levonorgestrel.intrauterine.rx", "etonogestrel.subcutaneous.rx"):
            assert device in members(resolved, "progestin-only contraceptives")
            assert device in members(resolved, "hormonal contraceptives")
            assert device not in members(resolved, "progestin-only pills")
            assert device not in members(resolved, "oral contraceptives")

    def test_no_menopause_or_fibroid_hormone_is_a_contraceptive(self, resolved: dict) -> None:
        for product in (
            "estradiol.oral.rx",
            "estradiol+norethindrone-acetate.oral.rx",
            "estrogens-conjugated+medroxyprogesterone-acetate.oral.rx",
            "elagolix+estradiol+norethisterone.oral.rx",
            "medroxyprogesterone-acetate.oral.rx",
        ):
            assert product not in members(resolved, "hormonal contraceptives"), product

    def test_every_contraceptive_left_out_is_left_out_for_a_reason(
        self, gen, table: dict, bundle: tuple[dict, dict], resolved: dict
    ) -> None:
        # Every drug whose own uses mention contraception, outside the
        # hormonal groups, named with why. A new pill whose hormones the table
        # does not list fails here, rather than missing every flag in silence.
        accounted = {
            "citric-acid-monohydrate+lactic-acid-l+potassium-bitartrate.vaginal.rx": "no hormone",
            "clomiphene-citrate.oral.rx": "a fertility drug",
            "copper.intrauterine.rx": "the copper IUD",
            "divalproex-sodium.oral.rx": "its uses advise contraception",
            "nonoxynol-9.vaginal.otc": "a spermicide",
            "pyridoxine-hydrochloride.intramuscular+intravenous.rx": "mentions the pill",
            "ulipristal-acetate.oral.rx": "a progesterone receptor modulator",
            "valproate-sodium.intravenous.rx": "its uses advise contraception",
            "valproic-acid.oral.rx": "its uses advise contraception",
        }
        index, sections = bundle
        rules = gen.Resolver(table, index["entries"], sections)
        hormonal = members(resolved, "hormonal contraceptives")
        left_out = {
            e["key"]
            for e in index["entries"]
            if rules.is_contraceptive(e) and e["key"] not in hormonal
        }
        assert left_out == set(accounted)

    def test_tilia_fe_is_a_pill_though_the_bundle_abbreviates_it(self, resolved: dict) -> None:
        assert "ee+ferrous-fumarate+ndac.unspecified.rx" in members(
            resolved, "combined hormonal contraceptives"
        )

    def test_an_nsaid_on_the_shelf_and_on_prescription(self, resolved: dict) -> None:
        nsaids = members(resolved, "NSAIDs")
        for product in ("ibuprofen.oral.otc", "naproxen-sodium.oral.otc", "mefenamic-acid.oral.rx"):
            assert product in nsaids, product
        assert "acetaminophen.oral.otc" not in nsaids

    def test_trazodone_is_not_an_ssri(self, resolved: dict) -> None:
        # The FDA's "Serotonin Reuptake Inhibitor" class takes in trazodone and
        # nefazodone, which is why SSRIs come from the FDA's list of them.
        ssris = members(resolved, "SSRIs")
        assert not any(key.startswith(("trazodone", "nefazodone")) for key in ssris)
        assert "fluvoxamine-maleate.oral.rx" in ssris

    def test_every_triptan_the_fda_classes_as_one(self, resolved: dict) -> None:
        triptans = members(resolved, "triptans")
        for name in ("almotriptan", "eletriptan", "frovatriptan", "naratriptan", "rizatriptan"):
            assert any(name in key for key in triptans), name


class TestWhatAConditionCountsAs:
    def by_condition(self, resolved: dict) -> dict[str, dict]:
        return {c["condition"]: c for c in resolved["conditions"]}

    def test_every_kind_of_contraception_is_mapped(self, resolved: dict, gen) -> None:
        assert set(self.by_condition(resolved)) == gen.CONDITIONS

    def test_the_combined_pill_is_every_combined_pill(self, resolved: dict) -> None:
        pill = self.by_condition(resolved)["hormonalContraceptionCombined"]
        assert "drospirenone+ethinyl-estradiol.oral.rx" in pill["kind"]
        assert "ethinyl-estradiol+etonogestrel.vaginal.rx" not in pill["kind"]
        assert "combined hormonal contraceptives" in pill["groups"]
        # Not every combined pill has ethinyl estradiol: Natazia and
        # Nextstellis do not. So the condition counts as no one substance.
        assert pill["names"] == []

    def test_the_hormonal_iud_and_the_implant_are_their_progestins(self, resolved: dict) -> None:
        conditions = self.by_condition(resolved)
        assert conditions["hormonalIud"]["names"] == ["levonorgestrel"]
        assert conditions["contraceptiveImplant"]["names"] == ["etonogestrel"]
        # The injection is subcutaneous too, and is not an implant.
        assert conditions["contraceptiveImplant"]["kind"] == ["etonogestrel.subcutaneous.rx"]

    def test_the_mini_pill_is_a_progestin_only_pill(self, resolved: dict) -> None:
        mini = self.by_condition(resolved)["hormonalContraceptionProgestogen"]
        assert "progestin-only pills" in mini["groups"]
        assert "combined oral contraceptives" not in mini["groups"]
        assert "norgestrel.oral.otc" in mini["kind"]


class TestRendering:
    def test_is_deterministic(self, gen, resolved: dict) -> None:
        assert gen.render(resolved, DIGEST) == gen.render(resolved, DIGEST)

    def test_refuses_what_would_end_the_raw_string(self, gen) -> None:
        with pytest.raises(SystemExit):
            gen.render({"groups": [{"name": "'''"}]}, DIGEST)

    def test_the_json_in_it_is_the_resolved_table(self, gen, resolved: dict) -> None:
        dart = gen.render(resolved, DIGEST)
        body = dart.split("r'''\n", 1)[1].rsplit("\n''';", 1)[0]
        assert json.loads(body) == resolved
        assert f"'{DIGEST}'" in dart

    def test_renders_formatted(self, gen, resolved: dict) -> None:
        # `--check` compares the file byte for byte, and the repository's
        # format gate rewrites anything unformatted; the two must not fight.
        dart = shutil.which("dart")
        if dart is None:
            pytest.skip("dart is not on PATH")
        with tempfile.TemporaryDirectory(dir=REPO_ROOT / "app") as directory:
            path = Path(directory) / "generated.dart"
            path.write_text(gen.render(resolved, DIGEST), encoding="utf-8")
            result = subprocess.run(
                [dart, "format", "--output=none", "--set-exit-if-changed", str(path)],
                capture_output=True,
                check=False,
            )
        assert result.returncode == 0, result.stdout.decode()
