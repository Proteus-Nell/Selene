"""The medicines generator (tasks AND-31 and AND-07).

The generator is the only thing in this project that touches the network, and
it does so on a developer machine or in CI — never on the phone. What is tested
here is everything except the download: which label is chosen to stand for each
drug, how its text is packed into the bundle the app reads, the determinism the
`--check` gate depends on, and the rendering of the generated Dart.

The selection rules are tested on labels built here, one rule at a time, and the
committed selection is tested for the exact drugs the first version of the
generator got wrong: a text search found "levonorgestrel" inside a combined
pill's name, answered "zinc" with a diaper cream, and picked an injection label
for tranexamic acid tablets.
"""

from __future__ import annotations

import importlib.util
import io
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
SELECTION = REPO_ROOT / "artifacts" / "medicines" / "selection_v2.json"
BUNDLE = REPO_ROOT / "app" / "assets" / "medicines"
GENERATED = REPO_ROOT / "app" / "lib" / "data" / "reference" / "medicines_bundled.dart"


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


def index_for(count: int = 3) -> dict:
    """Build an index shaped like the bundle's, for rendering."""
    return {
        "chunks": 1,
        "disclaimer": "Data from openFDA. " * 12,
        "entries": [{"key": f"drug-{i}.oral.rx"} for i in range(count)],
        "export_date": "2026-10-02",
        "jurisdiction": "US",
        "schema_version": 2,
    }


class TestRendering:
    def test_renders_a_built_bundle(self, gen) -> None:
        dart = gen.render(index_for(), DIGEST)

        assert "const bool medicinesFetched = true;" in dart
        assert "const String? medicinesSnapshotDate = '2026-10-02';" in dart
        assert "const int medicinesCount = 3;" in dart
        assert "const int medicinesChunkCount = 1;" in dart
        assert DIGEST in dart

    def test_renders_the_absence_of_one(self, gen) -> None:
        # The unbuilt state is visible rather than looking like an empty result.
        dart = gen.render(None, gen.bundle_digest([]))

        assert "const bool medicinesFetched = false;" in dart
        assert "const String? medicinesSnapshotDate = null;" in dart
        assert "const int medicinesCount = 0;" in dart

    def test_escapes_what_dart_would_otherwise_choke_on(self, gen) -> None:
        # A dollar sign in a Dart single-quoted string is interpolation: an
        # unescaped one is either a compile error or a silently different string.
        index = index_for()
        index["disclaimer"] = "doctor's advice, $5, back\\slash\nnewline"
        dart = gen.render(index, DIGEST)

        assert "doctor\\'s advice" in dart
        assert "\\$5" in dart
        assert "back\\\\slash" in dart
        assert "\\n" in dart

    def test_refuses_a_schema_version_it_does_not_know(self, gen) -> None:
        index = index_for()
        index["schema_version"] = 99
        with pytest.raises(SystemExit):
            gen.render(index, DIGEST)

    def test_is_deterministic(self, gen) -> None:
        # The whole --check gate rests on this.
        assert gen.render(index_for(), DIGEST) == gen.render(index_for(), DIGEST)


class TestFormatting:
    """The generated Dart must already be `dart format` clean.

    Not cosmetic. `--check` compares the file byte for byte against a fresh
    render, and the repository's format gate rewrites anything unformatted. A
    generator whose output the formatter touches makes those two fight — format
    the file and `--check` fails, regenerate and format fails — and the first
    thing anyone reaches for is deleting one of them.

    Both states are covered here, because the committed file only ever shows
    one of them.
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

    def test_a_built_bundle_renders_formatted(self, gen) -> None:
        clean = self._dart_format_clean(gen.render(index_for(), DIGEST))
        if clean is None:
            pytest.skip("dart is not on PATH")
        assert clean, (
            "the generated Dart is not `dart format` clean, so --check and the "
            "repository's format gate will fight the moment someone runs --fetch"
        )

    def test_no_bundle_renders_formatted_too(self, gen) -> None:
        clean = self._dart_format_clean(gen.render(None, gen.bundle_digest([])))
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
    classes: tuple[str, ...] = (),
    **fields: list[str],
) -> dict:
    """Build a label shaped like one in openFDA's export.

    An empty `substances` or `routes` leaves the field out, the way openFDA does
    for kits, and so does an empty `classes`, the way it does for most labels.
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
    if classes:
        openfda["pharm_class_epc"] = list(classes)
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


NSAID = "Nonsteroidal Anti-inflammatory Drug [EPC]"


class TestClasses:
    def test_a_class_is_named_without_its_tag(self, gen) -> None:
        found = drugs(gen, raw_label(classes=(NSAID,)))
        assert found["ibuprofen.oral.otc"]["classes"] == ["Nonsteroidal Anti-inflammatory Drug"]

    def test_a_drug_takes_the_classes_of_all_its_labels(self, gen) -> None:
        found = drugs(
            gen,
            raw_label(set_id="a", classes=(NSAID,)),
            raw_label(set_id="b", classes=("Analgesic [EPC]",)),
            raw_label(set_id="c"),
        )
        assert found["ibuprofen.oral.otc"]["classes"] == [
            "Analgesic",
            "Nonsteroidal Anti-inflammatory Drug",
        ]

    def test_a_substance_carries_its_class_to_labels_that_leave_it_out(self, gen) -> None:
        # Most labels carry no class. A drugstore's ibuprofen is an NSAID
        # because ibuprofen is, which the prescription label says.
        found = drugs(
            gen,
            raw_label(set_id="otc"),
            raw_label(product_type=RX, sections=RX_SAFETY, set_id="rx", classes=(NSAID,)),
            raw_label(
                generic="IBUPROFEN AND FAMOTIDINE",
                substances=("FAMOTIDINE", "IBUPROFEN"),
                set_id="combination",
            ),
        )
        nsaid = ["Nonsteroidal Anti-inflammatory Drug"]
        assert found["ibuprofen.oral.otc"]["classes"] == nsaid
        assert found["famotidine+ibuprofen.oral.otc"]["classes"] == nsaid

    def test_a_combination_lends_no_class_to_its_parts(self, gen) -> None:
        # Its class could belong to either ingredient.
        found = drugs(
            gen,
            raw_label(set_id="ibuprofen"),
            raw_label(generic="FAMOTIDINE", substances=("FAMOTIDINE",), set_id="famotidine"),
            raw_label(
                generic="IBUPROFEN AND FAMOTIDINE",
                substances=("FAMOTIDINE", "IBUPROFEN"),
                set_id="combination",
                classes=("Histamine-2 Receptor Antagonist [EPC]", NSAID),
            ),
        )
        assert found["ibuprofen.oral.otc"]["classes"] == []
        assert found["famotidine.oral.otc"]["classes"] == []


def _salted(name: str) -> list[dict]:
    """Labels for enough drugs ending in `name` that it reads as a salt word."""
    return [
        raw_label(generic=f"DRUG{i} {name}", substances=(f"DRUG{i} {name}",), set_id=f"s{i}")
        for i in range(8)
    ]


class TestWhatOtherLabelsCallADrug:
    def test_its_substances_by_name(self, gen) -> None:
        found = drugs(
            gen,
            raw_label(
                generic="LEVONORGESTREL AND ETHINYL ESTRADIOL",
                substances=("ETHINYL ESTRADIOL", "LEVONORGESTREL"),
                product_type=RX,
                sections=RX_SAFETY,
            ),
        )
        (drug,) = found.values()
        assert drug["match"] == ["ethinyl estradiol", "levonorgestrel"]

    def test_and_without_its_salt(self, gen) -> None:
        # A label warning about naproxen sodium says "naproxen".
        found = drugs(
            gen,
            raw_label(generic="NAPROXEN SODIUM", substances=("NAPROXEN SODIUM",), set_id="n"),
            *_salted("SODIUM"),
        )
        assert found["naproxen-sodium.oral.otc"]["match"] == ["naproxen", "naproxen sodium"]

    def test_salt_is_read_off_the_data(self, gen) -> None:
        # One name ending in a word does not make that word a salt.
        found = drugs(gen, raw_label(generic="NAPROXEN SODIUM", substances=("NAPROXEN SODIUM",)))
        assert found["naproxen-sodium.oral.otc"]["match"] == ["naproxen sodium"]

    def test_not_by_a_base_two_substances_share(self, gen) -> None:
        # "ESTRADIOL VALERATE" is not cut to "estradiol" while another
        # substance starting "ESTRADIOL" is something else.
        found = drugs(
            gen,
            raw_label(generic="ESTRADIOL VALERATE", substances=("ESTRADIOL VALERATE",), set_id="v"),
            raw_label(generic="ESTRADIOL BENZOATE", substances=("ESTRADIOL BENZOATE",), set_id="b"),
            *_salted("VALERATE"),
        )
        assert found["estradiol-valerate.oral.otc"]["match"] == ["estradiol valerate"]

    def test_not_by_a_base_too_short_to_be_a_drug(self, gen) -> None:
        found = drugs(
            gen,
            raw_label(generic="TEA ROOT", substances=("TEA ROOT",), set_id="t"),
            *_salted("ROOT"),
        )
        assert found["tea-root.oral.otc"]["match"] == ["tea root"]

    def test_not_by_a_salt_alone(self, gen) -> None:
        found = drugs(
            gen,
            raw_label(generic="SODIUM CHLORIDE", substances=("SODIUM CHLORIDE",), set_id="c"),
            *_salted("CHLORIDE"),
            *_salted("SODIUM"),
        )
        assert found["sodium-chloride.oral.otc"]["match"] == ["sodium chloride"]

    def test_not_by_a_name_read_off_a_title(self, gen) -> None:
        # A kit's substances come from its name when openFDA lists none, and
        # "DAY" would be found in nearly every label there is.
        found = drugs(
            gen,
            raw_label(generic="DAY AND NIGHT COLD RELIEF", substances=(), set_id="kit"),
        )
        assert found["day+night-cold-relief.oral.otc"]["match"] == []

    def test_but_by_one_another_label_lists(self, gen) -> None:
        # A pill pack lists no substances, but levonorgestrel is listed on
        # labels of its own.
        found = drugs(
            gen,
            raw_label(
                generic="LEVONORGESTREL AND ETHINYL ESTRADIOL",
                substances=(),
                product_type=RX,
                sections=RX_SAFETY,
                set_id="kit",
            ),
            raw_label(generic="LEVONORGESTREL", substances=("LEVONORGESTREL",), set_id="ec"),
        )
        assert found["ethinyl-estradiol+levonorgestrel.oral.rx"]["match"] == ["levonorgestrel"]

    def test_not_by_a_number(self, gen) -> None:
        found = drugs(gen, raw_label(generic="5", substances=("5",)))
        assert found["5.oral.otc"]["match"] == []


class _Response:
    """A stand-in for an HTTP response: a body, and the length it announced."""

    def __init__(self, body: bytes, announced: int) -> None:
        self._body = io.BytesIO(body)
        self.headers = {"Content-Length": str(announced)}

    def read(self, size: int = -1) -> bytes:
        return self._body.read(size)

    def __enter__(self) -> _Response:
        return self

    def __exit__(self, *_) -> None:
        return None


def _zip_bytes() -> bytes:
    """A small, whole zip file."""
    import zipfile

    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("part.json", json.dumps({"results": []}) * 50)
    return buffer.getvalue()


class TestDownloading:
    def test_a_transfer_cut_short_is_fetched_again(self, gen, tmp_path: Path, monkeypatch) -> None:
        # Python's HTTP client returns quietly when a connection closes early,
        # which once left three partitions short and failed the run as a zip
        # that could not be opened.
        whole = _zip_bytes()
        bodies = iter([whole[: len(whole) // 2], whole])
        calls = []

        def urlopen(request, timeout):
            calls.append(request.full_url)
            return _Response(next(bodies), len(whole))

        monkeypatch.setattr(gen.urllib.request, "urlopen", urlopen)
        path = tmp_path / "part.json.zip"
        gen.fetch_partition("https://example.test/part.json.zip", path, 0.0)
        assert path.read_bytes() == whole
        assert len(calls) == 2

    def test_one_that_never_arrives_whole_is_refused(
        self, gen, tmp_path: Path, monkeypatch
    ) -> None:
        whole = _zip_bytes()
        monkeypatch.setattr(
            gen.urllib.request,
            "urlopen",
            lambda request, timeout: _Response(whole[:-10], len(whole)),
        )
        path = tmp_path / "part.json.zip"
        with pytest.raises(gen.IncompleteDownloadError):
            gen.fetch_partition("https://example.test/part.json.zip", path, 0.0)
        # Nothing is left for the next run to mistake for a download.
        assert list(tmp_path.iterdir()) == []

    def test_a_short_file_in_the_cache_is_fetched_again(
        self, gen, tmp_path: Path, monkeypatch
    ) -> None:
        whole = _zip_bytes()
        (tmp_path / "part.json.zip").write_bytes(whole[:-10])
        monkeypatch.setattr(
            gen.urllib.request,
            "urlopen",
            lambda request, timeout: _Response(whole, len(whole)),
        )
        partitions = [
            {"file": "https://example.test/part.json.zip", "size_mb": "0.00", "records": "0"}
        ]
        gen.download_partitions(tmp_path, partitions)
        assert (tmp_path / "part.json.zip").read_bytes() == whole

    def test_a_whole_file_in_the_cache_is_not_fetched_again(
        self, gen, tmp_path: Path, monkeypatch
    ) -> None:
        (tmp_path / "part.json.zip").write_bytes(_zip_bytes())

        def urlopen(request, timeout):
            raise AssertionError("fetched a partition that was already whole")

        monkeypatch.setattr(gen.urllib.request, "urlopen", urlopen)
        partitions = [
            {"file": "https://example.test/part.json.zip", "size_mb": "0.00", "records": "0"}
        ]
        assert gen.download_partitions(tmp_path, partitions) == [(tmp_path / "part.json.zip", 0)]


class TestTheSelectionFile:
    def test_one_drug_per_line_and_still_one_json_document(self, gen) -> None:
        prescription = raw_label(product_type=RX, sections=RX_SAFETY)
        entries = list(drugs(gen, raw_label(), prescription).values())
        text = gen.selection_json({"schema_version": gen.SELECTION_SCHEMA_VERSION}, entries)
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


def bundle_of(gen, labels_and_sections: list[tuple[dict, list[list[str]]]]):
    """Select from labels and pack the given sections, as `--fetch` would."""
    records = [gen.summarise(label)[1] for label, _ in labels_and_sections]
    entries, _ = gen.select(records)
    by_set = {label["set_id"]: text for label, text in labels_and_sections}
    sections = {entry["key"]: by_set[entry["label"]["set_id"]] for entry in entries}
    meta = {"export_date": "2026-10-02", "jurisdiction": "US"}
    index, chunks = gen.build_bundle(meta, entries, sections)
    return entries, index, chunks


def unpacked(gen, index: bytes, chunks: list[bytes]) -> tuple[dict, list[list[str]]]:
    """Decompress an index and its chunks into lines."""
    zlib = gen.zlib
    lines = [zlib.decompress(chunk).decode().split("\n") for chunk in chunks]
    return json.loads(zlib.decompress(index)), lines


THREE_DRUGS = [
    (raw_label(set_id="a"), [["purpose", "Pain reliever."], ["warnings", "Allergy alert."]]),
    (
        raw_label(generic="NAPROXEN", substances=("NAPROXEN",), set_id="b"),
        [["warnings", "Stomach bleeding warning."]],
    ),
    (
        raw_label(
            generic="TRANEXAMIC ACID",
            substances=("TRANEXAMIC ACID",),
            product_type=RX,
            sections=RX_SAFETY,
            set_id="c",
        ),
        [["warnings_and_cautions", "Risk of thrombosis."], ["drug_interactions", "7 DRUG..."]],
    ),
]


class TestTheBundle:
    def test_every_drug_points_at_its_own_text(self, gen) -> None:
        _, index, chunks = bundle_of(gen, THREE_DRUGS)
        parsed, lines = unpacked(gen, index, chunks)
        for row in parsed["entries"]:
            assert json.loads(lines[row["chunk"]][row["line"]])["key"] == row["key"]

    def test_sections_keep_their_order_and_their_words(self, gen) -> None:
        # Nothing is reworded, reordered or cut on the way into the app.
        _, index, chunks = bundle_of(gen, THREE_DRUGS)
        parsed, lines = unpacked(gen, index, chunks)
        row = next(r for r in parsed["entries"] if r["key"] == "tranexamic-acid.oral.rx")
        record = json.loads(lines[row["chunk"]][row["line"]])
        assert record["sections"] == THREE_DRUGS[2][1]

    def test_a_chunk_ends_once_it_is_full(self, gen, monkeypatch) -> None:
        monkeypatch.setattr(gen, "CHUNK_TARGET", 1)
        _, index, chunks = bundle_of(gen, THREE_DRUGS)
        parsed, _ = unpacked(gen, index, chunks)
        assert len(chunks) == 3
        assert parsed["chunks"] == 3
        assert [row["line"] for row in parsed["entries"]] == [0, 0, 0]

    def test_the_index_says_where_the_text_came_from(self, gen) -> None:
        _, index, chunks = bundle_of(gen, THREE_DRUGS)
        parsed, _ = unpacked(gen, index, chunks)
        assert parsed["export_date"] == "2026-10-02"
        assert parsed["jurisdiction"] == "US"
        assert all(row["label"]["set_id"] for row in parsed["entries"])

    def test_the_index_carries_how_many_labels_each_drug_had(self, gen) -> None:
        # The app ranks search ties by it, so that the form most widely sold
        # comes first.
        entries, index, chunks = bundle_of(gen, THREE_DRUGS)
        parsed, _ = unpacked(gen, index, chunks)
        labels = {row["key"]: row["labels"] for row in parsed["entries"]}
        assert labels == {entry["key"]: entry["labels"] for entry in entries}

    def test_the_index_carries_what_the_interaction_checker_looks_for(self, gen) -> None:
        entries, index, chunks = bundle_of(gen, THREE_DRUGS)
        parsed, _ = unpacked(gen, index, chunks)
        assert [(row["classes"], row["match"]) for row in parsed["entries"]] == [
            (entry["classes"], entry["match"]) for entry in entries
        ]
        assert ["naproxen"] in [row["match"] for row in parsed["entries"]]

    def test_match_terms_that_are_not_the_selections_are_found(self, gen, tmp_path: Path) -> None:
        entries, index, chunks = bundle_of(gen, THREE_DRUGS)
        gen.write_bundle(tmp_path, index, chunks)
        changed = [{**entry, "match": []} for entry in entries]
        other = {"meta": {"export_date": "2026-10-02"}, "entries": changed}
        assert gen.bundle_problems(gen.bundle_files(tmp_path), other) == [
            "its classes or match terms are not the selection's"
        ]

    def test_is_byte_for_byte_repeatable(self, gen) -> None:
        # --check compares checksums, so a rebuild from the same export must
        # produce the same bytes or every refresh looks like a change.
        assert bundle_of(gen, THREE_DRUGS)[1:] == bundle_of(gen, THREE_DRUGS)[1:]

    def test_a_smaller_bundle_leaves_no_stale_chunks(self, gen, tmp_path: Path) -> None:
        gen.write_bundle(tmp_path, b"index", [b"one", b"two", b"three"])
        gen.write_bundle(tmp_path, b"index", [b"one"])
        assert [p.name for p in gen.bundle_files(tmp_path)] == [
            "index.json.zlib",
            "labels-000.jsonl.zlib",
        ]

    def test_the_digest_covers_every_file(self, gen, tmp_path: Path) -> None:
        gen.write_bundle(tmp_path, b"index", [b"one", b"two"])
        before = gen.bundle_digest(gen.bundle_files(tmp_path))
        (tmp_path / "labels-001.jsonl.zlib").write_bytes(b"TWO")
        assert gen.bundle_digest(gen.bundle_files(tmp_path)) != before

    def test_a_line_out_of_place_is_found(self, gen, tmp_path: Path) -> None:
        _, index, chunks = bundle_of(gen, THREE_DRUGS)
        lines = gen.zlib.decompress(chunks[0]).decode().split("\n")
        swapped = gen.zlib.compress("\n".join(reversed(lines)).encode())
        gen.write_bundle(tmp_path, index, [swapped])
        assert gen.bundle_problems(gen.bundle_files(tmp_path), None)

    def test_a_bundle_from_another_selection_is_found(self, gen, tmp_path: Path) -> None:
        entries, index, chunks = bundle_of(gen, THREE_DRUGS)
        gen.write_bundle(tmp_path, index, chunks)
        files = gen.bundle_files(tmp_path)
        same = {"meta": {"export_date": "2026-10-02"}, "entries": entries}
        assert gen.bundle_problems(files, same) == []
        other = {"meta": {"export_date": "2026-10-02"}, "entries": entries[:2]}
        assert gen.bundle_problems(files, other)


class TestExtractingSections:
    def test_paragraphs_are_kept_as_published(self, gen) -> None:
        label = {"warnings": ["  First paragraph. ", "", "Second paragraph."]}
        assert gen.section_text(label, "warnings") == "First paragraph.\n\nSecond paragraph."

    def test_only_the_chosen_label_is_read(self, gen, tmp_path: Path) -> None:
        import zipfile

        chosen = raw_label(set_id="chosen", label_id="id-chosen", purpose=["Chosen."])
        other = raw_label(set_id="other", label_id="id-other", purpose=["Not chosen."])
        path = tmp_path / "part.json.zip"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("part.json", json.dumps({"results": [chosen, other]}))
        entries, _ = gen.select([gen.summarise(chosen)[1]])

        sections, guides, outcomes = gen.extract_sections([(path, 2)], entries)
        assert ["purpose", "Chosen."] in sections["ibuprofen.oral.otc"]
        assert guides == {}
        assert outcomes == {"none": 1}

    def test_a_chosen_label_missing_from_the_export_is_refused(self, gen, tmp_path: Path) -> None:
        import zipfile

        path = tmp_path / "part.json.zip"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("part.json", json.dumps({"results": []}))
        entries, _ = gen.select([gen.summarise(raw_label())[1]])
        with pytest.raises(SystemExit):
            gen.extract_sections([(path, 0)], entries)


GUIDE = (
    "Medication Guide SERTRALINE TABLETS "
    "What is the most important information I should know about sertraline tablets? "
    "Sertraline may cause serious side effects. Call your healthcare provider. "
    "What are sertraline tablets? Sertraline is a prescription medicine used to treat "
    "depression. "
    "Who should not take sertraline tablets? Do not take sertraline if you take an MAOI. "
    "What should I tell my healthcare provider before taking sertraline tablets? "
    "Tell your healthcare provider if you are pregnant. "
    "How should I take sertraline tablets? • Take sertraline exactly as prescribed. "
    "• Take 1 tablet each morning. "
    "What should I avoid while taking sertraline tablets? Do not drink alcohol. "
    "What are the possible side effects of sertraline tablets? Nausea. "
    'See "What is the most important information I should know about sertraline tablets?" '
    "How should I store sertraline tablets? Store at room temperature. "
    "What are the ingredients in sertraline tablets? Sertraline hydrochloride."
)


def guide_label(text: str = GUIDE) -> dict:
    """A label with `text` as its Medication Guide."""
    return raw_label(product_type=RX, sections=RX_SAFETY, spl_medguide=[text])


class TestMedicationGuides:
    """The guide's safety sections, and never its dosing (ADR-0022).

    A Medication Guide is the FDA's patient leaflet, and one of its sections
    says how to take the medicine: a dose, which this app never shows. What
    is pinned here is that only the safety sections are carried, and that a
    guide whose dosing cannot be cleanly left out is left out whole.
    """

    def test_carries_its_safety_sections_in_order(self, gen) -> None:
        guide, outcome = gen.medication_guide(guide_label())
        assert outcome == "carried"
        assert [heading for heading, _ in guide] == [
            "What is the most important information I should know about sertraline tablets?",
            "What are sertraline tablets?",
            "Who should not take sertraline tablets?",
            "What should I tell my healthcare provider before taking sertraline tablets?",
            "What should I avoid while taking sertraline tablets?",
            "What are the possible side effects of sertraline tablets?",
        ]

    def test_never_how_to_take_it_nor_how_to_store_it(self, gen) -> None:
        guide, _ = gen.medication_guide(guide_label())
        carried = " ".join(heading + " " + text for heading, text in guide)
        assert "1 tablet each morning" not in carried
        assert "How should I take" not in carried
        assert "Store at room temperature" not in carried
        assert "ingredients" not in carried

    def test_a_quoted_heading_is_a_cross_reference(self, gen) -> None:
        # 'See "What is the most important..."' is the guide pointing back at a
        # heading. Taken for one, it would end the side effects there.
        guide, _ = gen.medication_guide(guide_label())
        side_effects = dict(guide)["What are the possible side effects of sertraline tablets?"]
        assert side_effects.startswith("Nausea.")
        assert "See" in side_effects

    def test_with_the_words_as_published(self, gen) -> None:
        guide, _ = gen.medication_guide(guide_label())
        assert dict(guide)["Who should not take sertraline tablets?"] == (
            "Do not take sertraline if you take an MAOI."
        )

    def test_a_missed_dose_left_in_a_safety_section_leaves_the_guide_out(self, gen) -> None:
        # The heading before it was not recognised, so how to take it ran on
        # into the section before, which would be carried.
        text = GUIDE.replace(
            "Tell your healthcare provider if you are pregnant. ",
            "Tell your healthcare provider if you are pregnant. If you miss a dose, "
            "take it as soon as you remember. ",
        )
        assert gen.medication_guide(guide_label(text)) == (None, "dosing")

    def test_so_does_a_how_often(self, gen) -> None:
        text = GUIDE.replace("Do not drink alcohol.", "Use 2 inhalations 2 times each day.")
        assert gen.medication_guide(guide_label(text)) == (None, "dosing")

    def test_so_does_an_instruction_anywhere_but_the_most_important_information(self, gen) -> None:
        text = GUIDE.replace("Do not drink alcohol.", "Swallow the capsules whole.")
        assert gen.medication_guide(guide_label(text)) == (None, "dosing")

    def test_though_the_most_important_information_may_say_to_take_it_as_prescribed(
        self, gen
    ) -> None:
        text = GUIDE.replace(
            "Call your healthcare provider.",
            "Take sertraline exactly as your healthcare provider tells you to.",
        )
        assert gen.medication_guide(guide_label(text))[1] == "carried"

    def test_an_amount_to_take_leaves_it_out_even_there(self, gen) -> None:
        text = GUIDE.replace("Call your healthcare provider.", "Take 2 tablets at bedtime.")
        assert gen.medication_guide(guide_label(text)) == (None, "dosing")

    def test_a_guide_laid_out_otherwise_is_left_out(self, gen) -> None:
        # Without the heading 21 CFR 208.20 puts first, there is no telling
        # which part is which.
        text = "MEDICATION GUIDE Methadone tablets are: a strong medicine. Take it daily."
        assert gen.medication_guide(guide_label(text)) == (None, "unrecognised")

    def test_a_label_without_one_has_none(self, gen) -> None:
        assert gen.medication_guide(raw_label()) == (None, "none")

    def test_it_travels_with_its_drug_and_is_counted(self, gen) -> None:
        entries, _, _ = bundle_of(gen, THREE_DRUGS)
        key = "tranexamic-acid.oral.rx"
        guide = [["What is the most important information?", "Blood clots."]]
        rebuilt = gen.build_bundle(
            {"export_date": "2026-10-02", "jurisdiction": "US"},
            entries,
            sections_of(gen, entries),
            {key: guide},
        )
        parsed, lines = unpacked(gen, *rebuilt)
        records = {
            json.loads(lines[row["chunk"]][row["line"]])["key"]: json.loads(
                lines[row["chunk"]][row["line"]]
            )
            for row in parsed["entries"]
        }
        assert records[key]["guide"] == guide
        assert "guide" not in records["ibuprofen.oral.otc"]
        assert parsed["guides"] == 1

    def test_the_generated_dart_says_how_many_drugs_have_one(self, gen) -> None:
        index = index_for()
        index["guides"] = 2
        assert "const int medicinesGuideCount = 2;" in gen.render(index, DIGEST)


def sections_of(gen, entries: list[dict]) -> dict[str, list[list[str]]]:
    """THREE_DRUGS' sections, by the keys `select` gave them."""
    by_set = {label["set_id"]: text for label, text in THREE_DRUGS}
    return {entry["key"]: by_set[entry["label"]["set_id"]] for entry in entries}


class TestTheCommittedBundle:
    @pytest.fixture(scope="class")
    def files(self, gen) -> list[Path]:
        files = gen.bundle_files(BUNDLE)
        if not files:
            pytest.skip("no bundle has been built yet")
        return files

    def test_agrees_with_the_selection(self, gen, files: list[Path]) -> None:
        selection = json.loads(SELECTION.read_text(encoding="utf-8"))
        assert gen.bundle_problems(files, selection) == []

    def test_is_what_the_generated_dart_describes(self, gen, files: list[Path]) -> None:
        expected = gen.render(gen.read_index(files[0]), gen.bundle_digest(files))
        assert GENERATED.read_text(encoding="utf-8") == expected

    def test_carries_safety_sections_and_nothing_else(self, gen, files: list[Path]) -> None:
        # No dosing reaches the phone: not shipped and hidden, not shipped at all.
        allowed = set(gen.RX_SECTIONS) | set(gen.OTC_SECTIONS)
        for path in files[1:]:
            for line in gen.zlib.decompress(path.read_bytes()).decode().split("\n"):
                names = {name for name, _ in json.loads(line)["sections"]}
                assert names <= allowed, names - allowed

    def test_carries_no_dosing_in_any_medication_guide(self, gen, files: list[Path]) -> None:
        # Every guide in the bundle, held again to the rules that admitted it:
        # a refresh with a loosened rule, or a guide edited by hand, fails here.
        guides = 0
        for path in files[1:]:
            for line in gen.zlib.decompress(path.read_bytes()).decode().split("\n"):
                record = json.loads(line)
                for heading, text in record.get("guide", []):
                    name = gen.guide_section(heading)
                    assert name is not None, (record["key"], heading)
                    assert gen.guide_dosing(name, text) is None, (record["key"], heading)
                    assert not gen.GUIDE_DOSING.search(heading), (record["key"], heading)
                guides += "guide" in record
        assert guides == gen.read_index(files[0])["guides"]
        assert guides > 0

    def test_well_known_guides_are_carried(self, gen, files: list[Path]) -> None:
        index = gen.read_index(files[0])
        lines = [gen.zlib.decompress(path.read_bytes()).decode().split("\n") for path in files[1:]]
        with_guide = {
            row["key"]
            for row in index["entries"]
            if "guide" in json.loads(lines[row["chunk"]][row["line"]])
        }
        # An antidepressant, an NSAID and a sleep medicine, each of which has
        # one by regulation.
        assert any(key.startswith("sertraline") for key in with_guide)
        assert any(key.startswith(("naproxen", "ibuprofen", "meloxicam")) for key in with_guide)
        assert any(key.startswith("zolpidem") for key in with_guide)
