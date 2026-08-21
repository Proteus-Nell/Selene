"""The medicines generator (task AND-31).

The generator is the only thing in this project that touches the network, and
it does so on a developer machine or in CI — never on the phone. What is tested
here is everything except the fetch: the artifact's shape, the determinism the
`--check` gate depends on, and the rendering of a populated snapshot.

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

    def test_a_fetched_snapshot_covers_the_whole_allowlist(
        self, gen, artifact: dict
    ) -> None:
        # Half a snapshot is worse than none: the app would show four medicines
        # with no indication that nine others were meant to be there.
        if artifact["snapshot_status"] != "fetched":
            pytest.skip("artifact has not been fetched yet")
        keys = {entry["key"] for entry in artifact["entries"]}
        assert keys == {key for key, _ in gen.ALLOWLIST}


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
                for key, generic in gen.ALLOWLIST
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


class TestTheAllowlist:
    def test_is_what_the_task_specified(self, gen) -> None:
        # An allowlist rather than a search: the point is a small reviewable set
        # of things that come up around menstrual cycles, not "whatever openFDA
        # has". Pinned so that widening it is a deliberate edit here.
        assert {key for key, _ in gen.ALLOWLIST} == {
            "ibuprofen",
            "naproxen",
            "mefenamic_acid",
            "paracetamol",
            "tranexamic_acid",
            "combined_oral_contraceptive",
            "progestogen_only_pill",
            "levonorgestrel_emergency",
            "ferrous_sulfate",
            "ferrous_fumarate",
            "ferrous_gluconate",
            "magnesium",
            "zinc",
        }

    def test_has_no_duplicate_keys(self, gen) -> None:
        keys = [key for key, _ in gen.ALLOWLIST]
        assert len(keys) == len(set(keys))

    def test_carries_no_dosing_section(self, gen) -> None:
        # Deliberate. A dose read off a US label and applied to a box bought
        # elsewhere is the specific harm this feature has to avoid rather than
        # cause, so dosing is not fetched at all — not fetched and hidden,
        # which would leave it one edit away from being shown.
        fields = {field for _, field in gen.SECTIONS}
        assert "dosage_and_administration" not in fields
        assert not any("dosage" in field for field in fields)
