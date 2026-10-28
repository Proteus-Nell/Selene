#!/usr/bin/env python3
"""Check, or set, the version a release is built with.

  usage: tools/scripts/release_version.py check [<tag>]
         tools/scripts/release_version.py set <major.minor.patch>

Android installs an APK over the copy already on a phone only when two things
hold: it is signed with the same key, and its version code is higher. The key
is the keystore's job (docs/RELEASE.md). The version code is this script's.

The code is derived from the version name, as major * 10000 + minor * 100 +
patch, so a later version always has a higher code and there is no second
number to forget to bump. Every APK in a release carries that same code, built
with `-Pforce-version-code-ignoring-abi=true`, so a newer release installs over
an older one whichever architecture either was built for.

`check` confirms that `app/pubspec.yaml` follows that rule. Given a tag, it also
confirms the tag names the same version, and that the version is newer than
every release tagged before it. On success it prints `name=` and `code=` lines,
which the release workflow appends to `$GITHUB_OUTPUT`.

`set` writes a version into `pubspec.yaml` and into the constant exports are
stamped with, which a test holds to the pubspec.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PUBSPEC = REPO_ROOT / "app" / "pubspec.yaml"
EXPORT_STAMP = REPO_ROOT / "app" / "lib" / "data" / "transfer" / "export_v1.dart"

NAME = re.compile(r"(\d+)\.(\d+)\.(\d+)")
TAG = re.compile(r"v(\d+\.\d+\.\d+)")
PUBSPEC_VERSION = re.compile(r"^version:[ \t]*(\S+)[ \t]*$", re.MULTILINE)
STAMP = re.compile(r"^const String appVersion = '([^']*)';$", re.MULTILINE)

# Android's ceiling on versionCode.
MAX_VERSION_CODE = 2_100_000_000


def parse_name(name: str) -> tuple[int, int, int]:
    """Split a version name into its three parts.

    Raises:
        ValueError: When the name is not `major.minor.patch`, or a part is too
            large for the code to stay in order.
    """
    match = NAME.fullmatch(name)
    if match is None:
        raise ValueError(f"'{name}' is not a version of the form major.minor.patch")
    major, minor, patch = (int(part) for part in match.groups())
    if minor > 99 or patch > 99:
        raise ValueError(
            f"'{name}': minor and patch must each be below 100, or a later version "
            "could get a lower version code"
        )
    return major, minor, patch


def version_code(name: str) -> int:
    """Return the version code a version name is released with."""
    major, minor, patch = parse_name(name)
    code = major * 10_000 + minor * 100 + patch
    if not 0 < code <= MAX_VERSION_CODE:
        raise ValueError(f"'{name}' gives version code {code}, outside 1..{MAX_VERSION_CODE}")
    return code


def read_version(pubspec_text: str) -> tuple[str, int]:
    """Return the version name and build number a pubspec declares.

    Raises:
        ValueError: When there is no `version: name+number` line.
    """
    match = PUBSPEC_VERSION.search(pubspec_text)
    if match is None:
        raise ValueError("pubspec.yaml has no version line")
    name, sep, number = match.group(1).partition("+")
    if not sep or not number.isdigit():
        raise ValueError(f"pubspec.yaml version '{match.group(1)}' has no +build number")
    return name, int(number)


def check(pubspec_text: str, tag: str | None = None, tags: list[str] | None = None) -> list[str]:
    """Return every reason the version is not releasable. Empty means it is.

    Args:
        pubspec_text: The contents of `app/pubspec.yaml`.
        tag: The tag being released, if any.
        tags: Every tag in the repository, for the newer-than check.
    """
    try:
        name, number = read_version(pubspec_text)
        expected = version_code(name)
    except ValueError as error:
        return [str(error)]
    problems = []
    if number != expected:
        problems.append(
            f"pubspec.yaml has build number {number} for version {name}; it must be "
            f"{expected}. Run: tools/scripts/release_version.py set {name}"
        )
    if tag is not None:
        if tag != f"v{name}":
            problems.append(f"tag '{tag}' does not match pubspec.yaml version {name}")
        for other in tags or []:
            match = TAG.fullmatch(other)
            if match is None or other == tag:
                continue
            try:
                earlier = version_code(match.group(1))
            except ValueError:
                continue
            if earlier >= expected:
                problems.append(
                    f"{other} is already tagged, and {tag} is not newer than it: a phone "
                    "with that release would refuse this one as a downgrade"
                )
    return problems


def set_version(name: str, pubspec_text: str, stamp_text: str) -> tuple[str, str]:
    """Return the pubspec and the export stamp source with `name` written into both."""
    full = f"{name}+{version_code(name)}"
    if PUBSPEC_VERSION.search(pubspec_text) is None:
        raise ValueError("pubspec.yaml has no version line")
    if STAMP.search(stamp_text) is None:
        raise ValueError("export_v1.dart has no appVersion constant")
    pubspec = PUBSPEC_VERSION.sub(f"version: {full}", pubspec_text, count=1)
    stamp = STAMP.sub(f"const String appVersion = '{full}';", stamp_text, count=1)
    return pubspec, stamp


def _repository_tags() -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "tag", "--list", "v*"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.split()


def main(argv: list[str]) -> int:
    """Run `check` or `set` and return the exit code: 0 done, 1 refused, 2 usage."""
    if len(argv) >= 1 and argv[0] == "check" and len(argv) <= 2:
        tag = argv[1] if len(argv) == 2 else None
        pubspec_text = PUBSPEC.read_text(encoding="utf-8")
        problems = check(pubspec_text, tag, _repository_tags() if tag else None)
        if problems:
            for problem in problems:
                print(f"ERROR: {problem}", file=sys.stderr)
            return 1
        name, number = read_version(pubspec_text)
        print(f"name={name}")
        print(f"code={number}")
        return 0
    if len(argv) == 2 and argv[0] == "set":
        try:
            pubspec, stamp = set_version(
                argv[1],
                PUBSPEC.read_text(encoding="utf-8"),
                EXPORT_STAMP.read_text(encoding="utf-8"),
            )
        except ValueError as error:
            print(f"ERROR: {error}", file=sys.stderr)
            return 1
        PUBSPEC.write_text(pubspec, encoding="utf-8")
        EXPORT_STAMP.write_text(stamp, encoding="utf-8")
        full = f"{argv[1]}+{version_code(argv[1])}"
        print(f"version {full} written to pubspec.yaml and the export stamp")
        return 0
    print(__doc__.split("\n\n", 2)[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
