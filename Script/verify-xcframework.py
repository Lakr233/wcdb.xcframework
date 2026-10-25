#!/usr/bin/env python3
"""Validate an XCFramework produced by merge-xcframework.sh.

Checks that every platform shard landed in the archive, that each slice's
binary is present and reports the architectures Xcode recorded, and that every
slice declares a minimum OS version. A missing visionOS or watchOS slice used
to be invisible until an app failed to link, so this runs in CI before upload.
"""

import argparse
import plistlib
import subprocess
import sys
from pathlib import Path

# shard -> (SupportedPlatform, SupportedPlatformVariant or None)
#
# Mac Catalyst is an iOS-family binary: its slice is recorded as platform "ios"
# with variant "maccatalyst", not as a platform of its own. visionOS uses the
# "xros" name here; the framework's own CFBundleSupportedPlatforms uses the
# "XROS"/"XRSimulator" spelling.
SHARDS = {
    "ios": ("ios", None),
    "ios-simulator": ("ios", "simulator"),
    "macos": ("macos", None),
    "macos-catalyst": ("ios", "maccatalyst"),
    "tvos": ("tvos", None),
    "tvos-simulator": ("tvos", "simulator"),
    "watchos": ("watchos", None),
    "watchos-simulator": ("watchos", "simulator"),
    "visionos": ("xros", None),
    "visionos-simulator": ("xros", "simulator"),
}

# Minimum OS each shard must declare: the deployment targets in platforms.sh.
# Package.swift must not advertise a lower floor than these, or consumers can
# target OS versions the binary was not built for. Mac Catalyst records the
# macOS version: 10.15 is Catalyst 13.1, the first release, so the package's
# 13.0 is equivalent.
EXPECTED_MIN_OS = {
    "ios": "12.0",
    "ios-simulator": "12.0",
    "macos": "10.13",
    "macos-catalyst": "10.15",
    "tvos": "12.4",
    "tvos-simulator": "12.4",
    "watchos": "6.0",
    "watchos-simulator": "6.0",
    "visionos": "1.0",
    "visionos-simulator": "1.0",
}


def fail(message):
    print(f"[!] {message}", file=sys.stderr)
    return 1


def architectures(path):
    result = subprocess.run(
        ["lipo", "-archs", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    return sorted(result.stdout.split())


def version_tuple(value):
    parts = value.split(".")
    return tuple(int(part) for part in parts[:2])


def shard_for_slice(platform, variant):
    for shard, identity in SHARDS.items():
        if identity == (platform, variant):
            return shard
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("xcframework", type=Path)
    parser.add_argument("--shards", nargs="+", required=True, choices=sorted(SHARDS))
    args = parser.parse_args()

    info_path = args.xcframework / "Info.plist"
    if not info_path.is_file():
        return fail(f"missing Info.plist: {info_path}")

    with info_path.open("rb") as handle:
        info = plistlib.load(handle)

    libraries = info.get("AvailableLibraries", [])
    if not libraries:
        return fail(f"no AvailableLibraries in {info_path}")

    expected = {SHARDS[shard] for shard in args.shards}
    actual = {
        (library.get("SupportedPlatform"), library.get("SupportedPlatformVariant"))
        for library in libraries
    }

    def labels(identities):
        return sorted(f"{platform}/{variant or 'device'}" for platform, variant in identities)

    missing = expected - actual
    unexpected = actual - expected
    if missing:
        return fail(f"missing slices: {labels(missing)}")
    if unexpected:
        return fail(f"unexpected slices: {labels(unexpected)}")

    for library in libraries:
        platform = library.get("SupportedPlatform")
        variant = library.get("SupportedPlatformVariant")
        label = f"{platform}/{variant or 'device'}"
        library_path = (
            args.xcframework
            / library["LibraryIdentifier"]
            / library["LibraryPath"]
        )
        binary_path = (
            args.xcframework
            / library["LibraryIdentifier"]
            / library["BinaryPath"]
        )
        if not library_path.is_dir():
            return fail(f"{label}: LibraryPath does not exist: {library_path}")
        if not binary_path.is_file():
            return fail(f"{label}: missing binary: {binary_path}")

        recorded = sorted(library.get("SupportedArchitectures", []))
        found = architectures(binary_path)
        if not found:
            return fail(f"{label}: lipo cannot read {binary_path}")
        if found != recorded:
            return fail(
                f"{label}: binary has {found}, Info.plist records {recorded}"
            )

        # macOS frameworks use the versioned deep layout; everything else is
        # flat. The descriptor's BinaryPath already points into Versions/A.
        slice_info_path = library_path / "Info.plist"
        if not slice_info_path.is_file():
            slice_info_path = library_path / "Versions/A/Resources/Info.plist"
        if not slice_info_path.is_file():
            return fail(f"{label}: missing framework Info.plist")
        with slice_info_path.open("rb") as handle:
            slice_info = plistlib.load(handle)
        minimum = slice_info.get("MinimumOSVersion") or slice_info.get(
            "LSMinimumSystemVersion"
        )
        if not minimum:
            return fail(f"{label}: no MinimumOSVersion in {slice_info_path}")

        shard = shard_for_slice(platform, variant)
        expected_minimum = EXPECTED_MIN_OS[shard]
        if version_tuple(minimum) != version_tuple(expected_minimum):
            return fail(
                f"{label}: minimum {minimum}, expected {expected_minimum} "
                "(check the deployment target passed to build-platform.sh)"
            )

        print(f"[*] {label}: {found}, minimum {minimum}")

    print(f"[*] verified {len(libraries)} slices in {args.xcframework.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
