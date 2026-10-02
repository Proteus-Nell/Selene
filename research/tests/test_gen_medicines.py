"""The medicines generator (tasks AND-31 and AND-07).

The generator is the only thing in this project that touches the network, and
it does so on a developer machine or in CI — never on the phone. What is tested
here is everything except the download: which label is chosen to stand for each
drug, the artifacts' shape, the determinism the `--check` gate depends on, and
the rendering of a populated snapshot.

The selection rules are tested on labels built here, one rule at a time, and the
committed selection is tested for the exact drugs the first version of the
generator got wrong: a text search found "levonorgestrel" inside a combined
pill's name, answered "zinc" with a diaper cream, and picked an injection label
for tranexamic acid tablets.

The last one matters more than it looks. The committed artifact is currently
unpopulated, so nothing else in the repository exercises the code path that
renders a real entry. A generator whose only tested case is the empty one is a
generator that will break the first time someone runs `--fetch`.
"""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]

# A realistic SHA-256, because the generated Dart's line breaking depends on it.
# A short fake digest fits on one line where a real one wraps, so a test using
# "deadbeef" would report the correct layout as wrong — which is exactly what it
# did before this constant existed.
DIGEST = "49cad45aaa0c88b3c020425afcaa77bbd496411f932e4bef1a770c0fa771e8f1"
SCRIPT = REPO_ROOT / "tools" / "scripts" / "gen_medicines.py"
ARTIFACT = REPO_ROOT / "artifacts" / "medicines" / "medicines_v1.json"
SELECTION = REPO_ROOT / "artifacts" / "medicines" / "selection_v1.json"


def load_generator():
    """Import the generator as a module, since it is a script, not a package."""
    spec = importlib.util.spec_from_file_location("gen_medicines", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def gen():
    return load_generator()


@pytest.fixture(scope="module")
def artifact() -> dict:
    return json.loads(ARTIFACT.read_text(encoding="utf-8"))


class TestTheCommittedArtifact:
    def test_exists_and_is_readable(self, artifact: dict) -> None:
        assert artifact["schema_version"] == 1

    def test_declares_its_jurisdiction(self, artifact: dict) -> None:
        # US labelling. Strengths, brand names and warnings differ everywhere
        # else, and a reader applying US warnings to a box bought elsewhere is
        # being quietly misinformed. The screen says so; this is what it reads.
        assert artifact["jurisdiction"] == "US"

    def test_carries_the_openfda_disclaimer(self, artifact: dict) -> None:
        assert "openFDA" in artifact["disclaimer"]

    def test_says_whether_it_has_actually_been_fetched(
        self, artifact: dict
    ) -> None:
        # The unpopulated state is visible in the repository rather than being
        # a missing file someone might mistake for an oversight.
        assert artifact["snapshot_status"] in {"fetched", "not_fetched"}
        if artifact["snapshot_status"] == "not_fetched":
            assert artifact["snapshot_date"] is None
            assert artifact["entries"] == []
        else:
            assert artifact["snapshot_date"]
            assert artifact["entries"]


class TestRendering:
    def test_renders_a_populated_snapshot(self, gen) -> None:
        # The path nothing else exercises while the artifact is empty.
        payload = {
            "schema_version": 1,
            "source": "openFDA /drug/label",
            "jurisdiction": "US",
            "snapshot_status": "fetched",
            "snapshot_date": "2026-08-21",
            "disclaimer": "Data from openFDA.",
            "entries": [
                {
                    "key": "ibuprofen",
                    "generic_name": "ibuprofen",
                    "brand_names": ["Advil", "Motrin"],
                    "sections": {
                        "purpose": "Pain reliever.",
                        "warnings": "Ask a doctor before use if...",
                    },
                }
            ],
        }
        dart = gen.render(payload, DIGEST)

        assert "const bool medicinesFetched = true;" in dart
        assert "const String? medicinesSnapshotDate = '2026-08-21';" in dart
        assert "key: 'ibuprofen'" in dart
        assert "'Advil'" in dart
        assert "'purpose': 'Pain reliever.'" in dart

    def test_escapes_what_dart_would_otherwise_choke_on(self, gen) -> None:
        # Label text is prose written by someone else. It contains apostrophes
        # constantly, and a dollar sign in a Dart single-quoted string is string
        # interpolation — an unescaped one is either a compile error or, worse,
        # a silently different string.
        payload = {
            "schema_version": 1,
            "source": "openFDA /drug/label",
            "jurisdiction": "US",
            "snapshot_status": "fetched",
            "snapshot_date": "2026-08-21",
            "disclaimer": "d",
            "entries": [
                {
                    "key": "k",
                    "generic_name": "g",
                    "brand_names": [],
                    "sections": {
                        "warnings": "doctor's advice, $5, back\\slash\nnewline"
                    },
                }
            ],
        }
        dart = gen.render(payload, DIGEST)

        assert "doctor\\'s advice" in dart
        assert "\\$5" in dart
        assert "back\\\\slash" in dart
        assert "\\n" in dart
        # And no raw newline escaped into the middle of a literal.
        assert "newline'" in dart

    def test_refuses_a_schema_version_it_does_not_know(self, gen) -> None:
        with pytest.raises(SystemExit):
            gen.render({"schema_version": 99, "entries": []}, DIGEST)

    def test_is_deterministic(self, gen, artifact: dict) -> None:
        # The whole --check gate rests on this. A generator that reordered a
        # map between runs would fail CI on an unchanged artifact, and the
        # first fix anyone reaches for is deleting the gate.
        first = gen.render(artifact, "digest")
        second = gen.render(artifact, "digest")
        assert first == second


class TestFormatting:
    """The generated Dart must already be `dart format` clean.

    Not cosmetic. `--check` compares the file byte for byte against a fresh
    render, and the repository's format gate rewrites anything unformatted. A
    generator whose output the formatter touches makes those two fight — format
    the file and `--check` fails, regenerate and format fails — and the first
    thing anyone reaches for is deleting one of them.

    The empty case is covered by the committed artifact. The **populated** case
    is covered here and nowhere else, because until someone runs `--fetch` there
    is no populated file in the repository to format. That is exactly the shape
    of bug that waits until the day it is least welcome.
    """

    @staticmethod
    def _dart_format_clean(source: str) -> bool | None:
        """True if `dart format` leaves `source` alone, None if dart is absent."""
        import shutil
        import subprocess
        import tempfile

        dart = shutil.which("dart")
        if dart is None:
            return None
        # Formatted *inside* the app package, not in /tmp. `dart format`
        # resolves the language version from the enclosing package, and outside
        # one it falls back to a default that formats differently — which made
        # this check fail on output that was in fact correct.
        app = REPO_ROOT / "app"
        with tempfile.TemporaryDirectory(dir=app) as directory:
            path = Path(directory) / "generated.dart"
            path.write_text(source, encoding="utf-8")
            result = subprocess.run(
                [
                    dart,
                    "format",
                    "--output=none",
                    "--set-exit-if-changed",
                    str(path),
                ],
                capture_output=True,
                check=False,
            )
            return result.returncode == 0

    def test_a_populated_render_is_already_formatted(self, gen) -> None:
        payload = {
            "schema_version": 1,
            "source": "openFDA /drug/label",
            "jurisdiction": "US",
            "snapshot_status": "fetched",
            "snapshot_date": "2026-08-21",
            "disclaimer": "Data from openFDA. " * 12,
            "entries": [
                {
                    "key": key,
                    "generic_name": generic,
                    "brand_names": ["Brand One", "Brand Two"],
                    "sections": {
                        "purpose": "A purpose sentence that runs on for a "
                        "while, the way real label text does.",
                        "warnings": "A warnings paragraph. " * 8,
                    },
                }
                for key, generic in (
                    ("ibuprofen.oral.otc", "IBUPROFEN"),
                    ("tranexamic-acid.oral.rx", "TRANEXAMIC ACID"),
                    ("levonorgestrel.oral.otc", "LEVONORGESTREL"),
                    ("ferrous-sulfate.oral.otc", "FERROUS SULFATE"),
                )
            ],
        }
        clean = self._dart_format_clean(gen.render(payload, DIGEST))
        if clean is None:
            pytest.skip("dart is not on PATH")
        assert clean, (
            "the generated Dart is not `dart format` clean, so --check and the "
            "repository's format gate will fight the moment someone runs --fetch"
        )

    def test_the_empty_render_is_too(self, gen, artifact: dict) -> None:
        clean = self._dart_format_clean(gen.render(artifact, DIGEST))
        if clean is None:
            pytest.skip("dart is not on PATH")
        assert clean


def raw_label(
    *,
    generic: str = "IBUPROFEN",
    substances: tuple[str, ...] = ("IBUPROFEN",),
    routes: tuple[str, ...] = ("ORAL",),
    product_type: str = "HUMAN OTC DRUG",
    brands: tuple[str, ...] = ("Advil",),
    sections: tuple[str, ...] = ("warnings", "do_not_use"),
    original: bool = True,
    application: str = "NDA020402",
    effective: str = "20250101",
    set_id: str = "set-a",
    label_id: str = "id-a",
    **fields: list[str],
) -> dict:
    """Build a label shaped like one in openFDA's export.

    An empty `substances` or `routes` leaves the field out, the way openFDA does
    for kits.
    """
    openfda: dict = {
        "product_type": [product_type],
        "generic_name": [generic],
        "brand_name": list(brands),
        "application_number": [application],
        "manufacturer_name": ["Maker"],
    }
    if substances:
        openfda["substance_name"] = list(substances)
    if routes:
        openfda["route"] = list(routes)
    if original:
        openfda["is_original_packager"] = [True]
    label = {"openfda": openfda, "effective_time": effective, "set_id": set_id, "id": label_id}
    for section in sections:
        label[section] = ["Text."]
    label.update(fields)
    return label


def drugs(gen, *labels: dict) -> dict:
    """Select from `labels` and return the drugs by key."""
    records = []
    for label in labels:
        reason, record = gen.summarise(label)
        assert reason is None, f"unexpectedly skipped: {reason}"
        records.append(record)
    entries, _ = gen.select(records)
    return {entry["key"]: entry for entry in entries}


RX = "HUMAN PRESCRIPTION DRUG"
RX_SAFETY = ("warnings_and_cautions", "drug_interactions")


class TestWhatIsSkipped:
    def test_a_label_openfda_cannot_link_to_a_product(self, gen) -> None:
        # Two thirds of the export. Without a link there is no generic name,
        # route or product type to identify the drug by.
        assert gen.summarise({"openfda": {}, "set_id": "s", "id": "i"}) == (
            gen.SKIP_UNLINKED,
            None,
        )

    def test_anything_but_a_human_drug(self, gen) -> None:
        label = raw_label(product_type="CELLULAR THERAPY")
        assert gen.summarise(label)[0] == gen.SKIP_OTHER_TYPE

    def test_one_label_for_several_products(self, gen) -> None:
        label = raw_label()
        label["openfda"]["generic_name"] = ["IBUPROFEN", "FAMOTIDINE"]
        assert gen.summarise(label)[0] == gen.SKIP_MULTI_PRODUCT

    @pytest.mark.parametrize(
        "fields",
        [
            {"spl_product_data_elements": ["Arnica ARNICA MONTANA 30 [hp_C]"]},
            {"active_ingredient": ["Arnica montana 30C HPUS"]},
            {"purpose": ["Homeopathic remedy for bruising"]},
            {"generic": "ARNICA MONTANA 30C"},
        ],
    )
    def test_homeopathic_products(self, gen, fields: dict) -> None:
        # Potencies rather than doses, and nothing about interactions. Over five
        # thousand of them would otherwise sit between the drugs in every search.
        label = raw_label(**fields)
        assert gen.summarise(label)[0] == gen.SKIP_HOMEOPATHIC

    def test_carbon_13_is_not_a_potency(self, gen) -> None:
        # "13C" on a prescription label is an isotope, in a breath test for
        # H. pylori, not a homeopathic dilution.
        label = raw_label(
            generic="CITRIC ACID ANHYDROUS AND 13C UREA",
            substances=("CITRIC ACID ANHYDROUS", "UREA C-13"),
            product_type=RX,
            sections=RX_SAFETY,
        )
        assert gen.summarise(label)[0] is None


class TestWhatADrugIs:
    def test_a_combined_pill_is_not_emergency_contraception(self, gen) -> None:
        # The bug that started this: a text search for "levonorgestrel" matched
        # the combined pill, because its name contains the word.
        found = drugs(
            gen,
            raw_label(generic="LEVONORGESTREL", substances=("LEVONORGESTREL",)),
            raw_label(
                generic="LEVONORGESTREL AND ETHINYL ESTRADIOL",
                substances=("LEVONORGESTREL", "ETHINYL ESTRADIOL"),
                product_type=RX,
                sections=RX_SAFETY,
                set_id="set-b",
            ),
        )
        assert set(found) == {
            "levonorgestrel.oral.otc",
            "ethinyl-estradiol+levonorgestrel.oral.rx",
        }
        assert found["levonorgestrel.oral.otc"]["substances"] == ["LEVONORGESTREL"]

    def test_tablets_and_injections_are_different_drugs(self, gen) -> None:
        tablets, injection = (
            raw_label(
                generic="TRANEXAMIC ACID",
                substances=("TRANEXAMIC ACID",),
                routes=(route,),
                product_type=RX,
                sections=RX_SAFETY,
                set_id=route,
            )
            for route in ("ORAL", "INTRAVENOUS")
        )
        assert set(drugs(gen, tablets, injection)) == {
            "tranexamic-acid.oral.rx",
            "tranexamic-acid.intravenous.rx",
        }

    def test_prescription_and_over_the_counter_are_different_drugs(self, gen) -> None:
        # Different labels entirely: the professional label and the Drug Facts.
        prescription = raw_label(product_type=RX, sections=RX_SAFETY, set_id="set-b")
        assert set(drugs(gen, raw_label(), prescription)) == {
            "ibuprofen.oral.otc",
            "ibuprofen.oral.rx",
        }

    def test_a_name_is_not_an_identity(self, gen) -> None:
        # The same product, worded three ways. Grouping by name made each a drug.
        substances = ("PRAMOXINE HYDROCHLORIDE", "ZINC ACETATE")
        found = drugs(
            gen,
            *(
                raw_label(generic=name, substances=substances, set_id=f"set-{i}")
                for i, name in enumerate(
                    (
                        "ZINC ACETATE AND PRAMOXINE HCL",
                        "ZINC ACETATE AND PRAMOXINE HCL",
                        "PRAMOXINE HYDROCHLORIDE, ZINC ACETATE",
                    )
                )
            ),
        )
        (drug,) = found.values()
        assert drug["labels"] == 3
        assert drug["name"] == "ZINC ACETATE AND PRAMOXINE HCL"

    def test_a_pill_pack_is_known_by_the_ingredients_in_its_name(self, gen) -> None:
        # Kits list no substances and no route. Every pill pack used to become a
        # drug of its own, named however its label happened to be worded.
        listed = raw_label(
            generic="LEVONORGESTREL AND ETHINYL ESTRADIOL",
            substances=("LEVONORGESTREL", "ETHINYL ESTRADIOL"),
            product_type=RX,
            sections=RX_SAFETY,
        )
        pack = raw_label(
            generic="LEVONORGESTREL AND ETHINYL ESTRADIOL AND ETHINYL ESTRADIOL",
            substances=(),
            routes=(),
            product_type=RX,
            sections=RX_SAFETY,
            set_id="set-b",
            package_label_principal_display_panel=["3 blister cards of 28 tablets"],
        )
        found = drugs(gen, listed, pack)
        assert set(found) == {"ethinyl-estradiol+levonorgestrel.oral.rx"}
        assert found["ethinyl-estradiol+levonorgestrel.oral.rx"]["labels"] == 2


class TestRoutes:
    @staticmethod
    def _pack(**fields) -> dict:
        return raw_label(
            generic="NORGESTIMATE AND ETHINYL ESTRADIOL",
            substances=(),
            routes=(),
            product_type=RX,
            sections=RX_SAFETY,
            **fields,
        )

    def test_a_carton_that_says_tablets_is_oral(self, gen) -> None:
        pack = self._pack(package_label_principal_display_panel=["28 Tablets"])
        assert set(drugs(gen, pack)) == {"ethinyl-estradiol+norgestimate.oral.rx"}

    def test_a_vaginal_tablet_is_not_taken_to_be_oral(self, gen) -> None:
        label = raw_label(package_label_principal_display_panel=["6 vaginal tablets"])
        assert not gen.says_tablets(label)

    def test_a_placeholder_carton_takes_its_drugs_usual_route(self, gen) -> None:
        # Some cartons are literally "Add image transcription here". Nine in ten
        # of the drug's other labels say oral, so this one is oral too.
        labelled = [
            self._pack(
                set_id=f"set-{i}",
                package_label_principal_display_panel=["28 Tablets"],
            )
            for i in range(9)
        ]
        patch = self._pack(set_id="set-patch")
        patch["openfda"]["route"] = ["TRANSDERMAL"]
        placeholder = self._pack(
            set_id="set-z",
            package_label_principal_display_panel=["Add image transcription here"],
        )
        found = drugs(gen, *labelled, patch, placeholder)
        assert found["ethinyl-estradiol+norgestimate.oral.rx"]["labels"] == 10

    def test_no_route_is_guessed_when_the_drug_has_two(self, gen) -> None:
        oral = self._pack(set_id="set-oral")
        oral["openfda"]["route"] = ["ORAL"]
        patch = self._pack(set_id="set-patch")
        patch["openfda"]["route"] = ["TRANSDERMAL"]
        unknown = self._pack(set_id="set-z")
        assert "ethinyl-estradiol+norgestimate.unspecified.rx" in drugs(gen, oral, patch, unknown)


class TestWhichLabelStandsForADrug:
    @staticmethod
    def _picked(gen, *labels: dict) -> str:
        (drug,) = drugs(gen, *labels).values()
        return drug["label"]["set_id"]

    def test_safety_information_comes_first(self, gen) -> None:
        # A repackager's complete copy beats the maker's label with nothing to
        # say about interactions: the drug's page is built from this label.
        thin = raw_label(sections=("warnings",), set_id="maker")
        full = raw_label(original=False, set_id="repackager")
        assert self._picked(gen, thin, full) == "repackager"

    def test_the_maker_over_a_repackager(self, gen) -> None:
        maker = raw_label(set_id="maker")
        copy = raw_label(original=False, set_id="repackager", effective="20260101")
        assert self._picked(gen, copy, maker) == "maker"

    def test_the_reference_label_over_a_generic(self, gen) -> None:
        reference = raw_label(set_id="nda")
        generic = raw_label(application="ANDA078682", set_id="anda", effective="20260101")
        assert self._picked(gen, generic, reference) == "nda"

    def test_the_newest_label(self, gen) -> None:
        old = raw_label(set_id="old", effective="20190101")
        new = raw_label(set_id="new", effective="20260101")
        assert self._picked(gen, old, new) == "new"

    def test_ties_are_broken_the_same_way_every_run(self, gen) -> None:
        first, second = raw_label(set_id="aaa"), raw_label(set_id="bbb")
        assert self._picked(gen, first, second) == "aaa"
        assert self._picked(gen, second, first) == "aaa"

    def test_a_drug_with_nothing_to_show_is_left_out(self, gen) -> None:
        records = [gen.summarise(raw_label(sections=()))[1]]
        assert gen.select(records) == ([], 1)


class TestNamesAndKeys:
    @pytest.mark.parametrize(
        ("name", "expected"),
        [
            (
                "LEVONORGESTREL / ETHINYL ESTRADIOL AND ETHINYL ESTRADIOL",
                ("ETHINYL ESTRADIOL", "LEVONORGESTREL"),
            ),
            (
                "DROSPIRENONE/ETHINYL ESTRADIOL/LEVOMEFOLATE CALCIUM AND LEVOMEFOLATE CALCIUM",
                ("DROSPIRENONE", "ETHINYL ESTRADIOL", "LEVOMEFOLATE CALCIUM"),
            ),
            (
                "NORETHINDRONE ACETATE AND ETHINYL ESTRADIOL 1 MG/0.02 MG AND FERROUS FUMARATE",
                ("ETHINYL ESTRADIOL", "FERROUS FUMARATE", "NORETHINDRONE ACETATE"),
            ),
            (
                "NITROFURANTOIN (MONOHYDRATE/MACROCRYSTALS)",
                ("NITROFURANTOIN (MONOHYDRATE/MACROCRYSTALS)",),
            ),
            (
                "LEVONORGESTREL AND ETHINYL ESTRADIOL TABLETS",
                ("ETHINYL ESTRADIOL", "LEVONORGESTREL"),
            ),
        ],
    )
    def test_substances_from_a_name(self, gen, name: str, expected: tuple) -> None:
        assert gen.substances_from_name(name) == expected

    def test_brands_are_merged_and_the_generic_name_is_not_one(self, gen) -> None:
        found = drugs(
            gen,
            raw_label(brands=("Advil", "Ibuprofen"), set_id="a"),
            raw_label(brands=("ADVIL", "Motrin IB"), set_id="b"),
            raw_label(brands=("Advil",), set_id="c"),
        )
        assert found["ibuprofen.oral.otc"]["brands"] == ["Advil", "Motrin IB"]

    def test_a_long_key_is_shortened_but_kept_unique(self, gen) -> None:
        many = tuple(f"ingredient-{i}" for i in range(40))
        other = (*many[:-1], "ingredient-x")
        first = gen.entry_key(many, ("TOPICAL",), "otc")
        second = gen.entry_key(other, ("TOPICAL",), "otc")
        assert len(first) <= gen.KEY_LIMIT + len(".topical.otc")
        assert first != second

    def test_two_drugs_that_would_share_a_key_are_refused(self, gen) -> None:
        # Refused rather than letting one silently replace the other.
        one = raw_label(routes=("INTRA-VENOUS",), set_id="a")
        two = raw_label(routes=("INTRA VENOUS",), set_id="b")
        with pytest.raises(SystemExit):
            drugs(gen, one, two)


class TestTheSelectionFile:
    def test_one_drug_per_line_and_still_one_json_document(self, gen) -> None:
        prescription = raw_label(product_type=RX, sections=RX_SAFETY)
        entries = list(drugs(gen, raw_label(), prescription).values())
        text = gen.selection_json({"schema_version": 1}, entries)
        assert json.loads(text)["entries"] == entries
        assert len(text.splitlines()) == len(entries) + 3

    def test_the_check_accepts_its_own_output(self, gen) -> None:
        entries = list(drugs(gen, raw_label()).values())
        text = gen.selection_json({"schema_version": gen.SELECTION_SCHEMA_VERSION}, entries)
        assert gen.selection_problems(text) == []

    def test_the_check_refuses_a_reformatted_file(self, gen) -> None:
        entries = list(drugs(gen, raw_label()).values())
        text = gen.selection_json({"schema_version": gen.SELECTION_SCHEMA_VERSION}, entries)
        edited = json.dumps(json.loads(text), indent=2)
        assert gen.selection_problems(edited)

    def test_a_partition_holding_the_wrong_count_is_refused(self, gen, tmp_path: Path) -> None:
        # A short download would silently drop every drug whose labels all sat
        # in the missing part.
        import zipfile

        path = tmp_path / "drug-label-0001-of-0001.json.zip"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("drug-label.json", json.dumps({"results": [raw_label()]}))
        assert len(gen.read_partition(path, 1)) == 1
        with pytest.raises(SystemExit):
            gen.read_partition(path, 2)


class TestTheSectionsCarried:
    def test_carries_no_dosing_section(self, gen) -> None:
        # Deliberate. A dose read off a US label and applied to a box bought
        # elsewhere is the specific harm this feature has to avoid rather than
        # cause, so dosing is not carried at all: not carried and hidden, which
        # would leave it one edit away from being shown.
        fields = set(gen.RX_SECTIONS) | set(gen.OTC_SECTIONS)
        assert not any("dosage" in field for field in fields)


@pytest.fixture(scope="module")
def selection() -> dict:
    if not SELECTION.exists():
        pytest.skip("no selection has been fetched yet")
    return json.loads(SELECTION.read_text(encoding="utf-8"))


class TestTheCommittedSelection:
    def test_is_well_formed(self, gen) -> None:
        if not SELECTION.exists():
            pytest.skip("no selection has been fetched yet")
        assert gen.selection_problems(SELECTION.read_text(encoding="utf-8")) == []

    def test_every_label_is_accounted_for(self, selection: dict) -> None:
        counts = selection["meta"]["counts"]
        skipped = sum(
            counts[reason]
            for reason in ("unlinked", "other_product_type", "multi_product", "homeopathic")
        )
        assert counts["labels"] == skipped + counts["considered"]
        assert counts["drugs"] == len(selection["entries"])

    def test_every_drug_names_the_label_it_came_from(self, selection: dict) -> None:
        for entry in selection["entries"]:
            label = entry["label"]
            assert label["set_id"] and label["id"], entry["key"]
            assert label["effective_time"].isdigit(), entry["key"]

    def test_the_drugs_the_first_version_got_wrong(self, selection: dict) -> None:
        found = {entry["key"]: entry for entry in selection["entries"]}
        # Emergency contraception is levonorgestrel alone, not a combined pill.
        assert found["levonorgestrel.oral.otc"]["substances"] == ["LEVONORGESTREL"]
        # The tablets for heavy bleeding, and the injection, are two drugs.
        assert "tranexamic-acid.oral.rx" in found
        assert "tranexamic-acid.intravenous.rx" in found
        # The progestogen-only pill is norethindrone alone.
        assert found["norethindrone.oral.rx"]["substances"] == ["NORETHINDRONE"]
        # And the combined pill is one drug, not one per pack design.
        assert found["ethinyl-estradiol+levonorgestrel.oral.rx"]["labels"] > 10
