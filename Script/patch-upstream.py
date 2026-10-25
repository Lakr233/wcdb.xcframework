#!/usr/bin/env python3
"""Make a disposable WCDB checkout buildable for visionOS.

WCDB's Xcode project does not list visionOS in SUPPORTED_PLATFORMS, and
xcodebuild resolves a destination before command-line build settings apply, so
passing SUPPORTED_PLATFORMS to xcodebuild cannot unlock visionOS. Patch the
clone instead of forking upstream.

The changes are limited to project configuration:

1. add xros/xrsimulator to every SUPPORTED_PLATFORMS assignment in the WCDB,
   sqlcipher and zstd projects, plus their xcconfig files;
2. pin XROS_DEPLOYMENT_TARGET in the shared xcconfig;
3. link UIKit for visionOS. Upstream's UIKit file reference points at
   System/iOSSupport/System/Library/Frameworks, which does not exist in the
   XROS SDK, so the framework is silently dropped even though
   WCTOperationQueue.mm takes the TARGET_OS_IPHONE branch on visionOS. Adding
   it to OTHER_LDFLAGS[sdk=xros*] is what actually links it.

No source file is modified. The script is idempotent and fails loudly when the
upstream layout changes, so a silent partial patch cannot ship.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

PLATFORM_SUFFIX = " xros xrsimulator"
ASSIGNMENT = re.compile(r'^\s*SUPPORTED_PLATFORMS = "?([^";\n]*)', re.MULTILINE)

VISIONOS_LDFLAGS = """OTHER_LDFLAGS[sdk=xros*] = $(inherited) -framework zstd -framework UIKit
OTHER_LDFLAGS[sdk=xrsimulator*] = $(inherited) -framework zstd -framework UIKit"""


def patch_quoted_platforms(path: Path) -> int:
    pattern = re.compile(r'^(\s*SUPPORTED_PLATFORMS = ")([^"]*)(";)', re.MULTILINE)
    text = path.read_text()
    count = 0

    def replace(match):
        nonlocal count
        count += 1
        value = match.group(2)
        if "xros" not in value.split():
            value += PLATFORM_SUFFIX
        return match.group(1) + value + match.group(3)

    path.write_text(pattern.sub(replace, text))
    return count


def patch_unquoted_platforms(path: Path) -> int:
    pattern = re.compile(r"^(\s*SUPPORTED_PLATFORMS = )([^\n\"]+)$", re.MULTILINE)
    text = path.read_text()
    count = 0

    def replace(match):
        nonlocal count
        count += 1
        value = match.group(2).rstrip()
        if "xros" not in value.split():
            value += PLATFORM_SUFFIX
        return match.group(1) + value

    path.write_text(pattern.sub(replace, text))
    return count


def unpatched_assignments(path: Path) -> tuple[int, int]:
    """Return (assignments, assignments without xros) in any spelling."""
    values = ASSIGNMENT.findall(path.read_text())
    return len(values), len([value for value in values if "xros" not in value.split()])


def ensure_xros_deployment_target(path: Path) -> None:
    text = path.read_text()
    if "XROS_DEPLOYMENT_TARGET" not in text:
        text = text.rstrip("\n") + "\nXROS_DEPLOYMENT_TARGET = 1.0\n"
        path.write_text(text)


def patch_visionos_linker(path: Path) -> None:
    text = path.read_text()
    if "OTHER_LDFLAGS[sdk=xros*]" in text:
        return

    anchor = "OTHER_LDFLAGS = $(inherited) -framework zstd"
    if anchor not in text:
        raise SystemExit(f"[!] {path}: linker anchor not found")

    text = text.replace(anchor, anchor + "\n" + VISIONOS_LDFLAGS, 1)
    path.write_text(text)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument(
        "--skip-destination-check",
        action="store_true",
        help="Do not run xcodebuild -showdestinations after patching",
    )
    args = parser.parse_args()

    source_dir = args.source_dir
    project = source_dir / "src/WCDB.xcodeproj/project.pbxproj"
    sqlcipher_project = (
        source_dir / "sqlcipher/sqlcipher.preprocessed.xcodeproj/project.pbxproj"
    )
    zstd_project = source_dir / "src/zstd.xcodeproj/project.pbxproj"
    projects = [project, sqlcipher_project, zstd_project]
    xcconfigs = [
        source_dir / "src/support/Base.xcconfig",
        source_dir / "src/support/ZstdBase.xcconfig",
        source_dir / "sqlcipher/macosx/Base.xcconfig",
    ]
    linker_config = source_dir / "src/support/WCDB.xcconfig"

    if not project.is_file():
        print(f"[!] Not a WCDB checkout: {project}", file=sys.stderr)
        return 1

    for path in projects:
        if not path.is_file():
            print(f"[!] Missing project: {path}", file=sys.stderr)
            return 1
        patch_quoted_platforms(path)

    for path in xcconfigs:
        if not path.is_file():
            print(f"[!] Missing xcconfig: {path}", file=sys.stderr)
            return 1
        patch_unquoted_platforms(path)

    # Re-read every assignment, whatever its spelling. One the patterns above
    # did not match would leave that target without visionOS, and the archive
    # would drop it silently, so stop instead of publishing a partial set.
    for path in projects + xcconfigs:
        total, missing = unpatched_assignments(path)
        if total == 0 or missing:
            print(
                f"[!] {path}: {missing} of {total} "
                "SUPPORTED_PLATFORMS assignments lack xros",
                file=sys.stderr,
            )
            return 1

    if not linker_config.is_file():
        print(f"[!] Missing linker config: {linker_config}", file=sys.stderr)
        return 1
    ensure_xros_deployment_target(source_dir / "src/support/Base.xcconfig")
    patch_visionos_linker(linker_config)

    if not args.skip_destination_check:
        result = subprocess.run(
            [
                "xcodebuild",
                "-project",
                str(source_dir / "src/WCDB.xcodeproj"),
                "-scheme",
                "WCDBSwift",
                "-showdestinations",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0 or "platform:visionOS" not in result.stdout:
            print(
                "[!] visionOS destination still unavailable after patching",
                file=sys.stderr,
            )
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            return 1

    print(
        f"[*] Patched WCDB for visionOS: {len(projects)} projects, "
        f"UIKit linked via {linker_config.name}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
