"""The release version rule (tools/scripts/release_version.py, docs/RELEASE.md).

Android installs an APK over the copy on a phone only if its version code is
higher. The code is derived from the version name so that a later release
always outranks an earlier one, and these tests pin that, along with the checks
the release workflow relies on to refuse a tag before anything is built.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "tools" / "scripts" / "release_version.py"

PUBSPEC = """name: period_tracker
# The version line, as Flutter writes it.
version: {version}

environment:
  sdk: ^3.13.0
"""

STAMP = """/// The app version stamped into exports.
const String appVersion = '{version}';

String get appVersionName => appVersion.split('+').first;
"""


def load_script():
    """Import the script as a module, since it is a script, not a package."""
    spec = importlib.util.spec_from_file_location("release_version", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def rv():
    return load_script()


class TestVersionCode:
    def test_is_derived_from_the_name(self, rv) -> None:
        assert rv.version_code("1.0.0") == 10_000
        assert rv.version_code("1.2.3") == 10_203
        assert rv.version_code("0.0.1") == 1

    def test_a_later_version_always_has_a_higher_code(self, rv) -> None:
        # In version order, across every place a part can roll over.
        ordered = ["0.9.99", "1.0.0", "1.0.1", "1.0.99", "1.1.0", "1.99.99", "2.0.0", "10.0.0"]
        codes = [rv.version_code(name) for name in ordered]
        assert codes == sorted(codes)
        assert len(set(codes)) == len(codes)

    @pytest.mark.parametrize("name", ["1.100.0", "1.0.100"])
    def test_refuses_a_part_that_would_break_the_order(self, rv, name: str) -> None:
        # 1.100.0 would get the same code as 2.0.0.
        with pytest.raises(ValueError, match="below 100"):
            rv.version_code(name)

    @pytest.mark.parametrize("name", ["1.0", "v1.0.0", "1.0.0-rc.1", "1.0.0+5", "", "0.0.0"])
    def test_refuses_anything_but_major_minor_patch(self, rv, name: str) -> None:
        with pytest.raises(ValueError):
            rv.version_code(name)


class TestCheck:
    def test_passes_a_pubspec_that_follows_the_rule(self, rv) -> None:
        assert rv.check(PUBSPEC.format(version="1.1.0+10100")) == []

    def test_says_what_to_run_when_the_build_number_is_wrong(self, rv) -> None:
        [problem] = rv.check(PUBSPEC.format(version="1.1.0+2"))
        assert "10100" in problem
        assert "release_version.py set 1.1.0" in problem

    def test_refuses_a_pubspec_with_no_build_number(self, rv) -> None:
        [problem] = rv.check(PUBSPEC.format(version="1.1.0"))
        assert "build number" in problem

    def test_passes_a_matching_tag_newer_than_every_other(self, rv) -> None:
        tags = ["v1.0.0", "v1.0.1", "v1.1.0", "not-a-release"]
        assert rv.check(PUBSPEC.format(version="1.1.0+10100"), "v1.1.0", tags) == []

    def test_refuses_a_tag_that_names_another_version(self, rv) -> None:
        problems = rv.check(PUBSPEC.format(version="1.1.0+10100"), "v1.2.0", [])
        assert any("does not match" in problem for problem in problems)

    def test_refuses_a_version_no_newer_than_one_already_tagged(self, rv) -> None:
        # A phone with 1.2.0 would refuse 1.1.0 as a downgrade.
        problems = rv.check(PUBSPEC.format(version="1.1.0+10100"), "v1.1.0", ["v1.2.0", "v1.1.0"])
        assert any("v1.2.0" in problem and "downgrade" in problem for problem in problems)


class TestSetVersion:
    def test_writes_the_name_and_its_code_into_both_files(self, rv) -> None:
        pubspec, stamp = rv.set_version(
            "1.1.0",
            PUBSPEC.format(version="1.0.0+10000"),
            STAMP.format(version="1.0.0+10000"),
        )
        assert pubspec == PUBSPEC.format(version="1.1.0+10100")
        assert stamp == STAMP.format(version="1.1.0+10100")

    def test_keeps_the_lines_around_the_version(self, rv) -> None:
        # A pattern that matched the newline after the version once removed the
        # blank line below it.
        pubspec, _ = rv.set_version(
            "2.0.0",
            PUBSPEC.format(version="1.0.0+10000"),
            STAMP.format(version="1.0.0+10000"),
        )
        assert pubspec.splitlines()[3] == ""

    def test_refuses_a_version_that_breaks_the_rule(self, rv) -> None:
        with pytest.raises(ValueError):
            rv.set_version("1.0.100", PUBSPEC.format(version="1.0.0+10000"), STAMP)


class TestTheRepository:
    def test_pubspec_follows_the_rule(self, rv) -> None:
        # So that the next tag fails only on purpose.
        text = (REPO_ROOT / "app" / "pubspec.yaml").read_text(encoding="utf-8")
        assert rv.check(text) == []

    def test_export_stamp_is_the_pubspec_version(self, rv) -> None:
        name, number = rv.read_version(
            (REPO_ROOT / "app" / "pubspec.yaml").read_text(encoding="utf-8")
        )
        stamp = (REPO_ROOT / "app" / "lib" / "data" / "transfer" / "export_v1.dart").read_text(
            encoding="utf-8"
        )
        assert f"const String appVersion = '{name}+{number}';" in stamp
