#!/bin/bash

# Usage: ./test-imports.sh <xcframeworks_dir>
#
# Compile a one-line consumer against every slice. This catches a slice that
# merged successfully but cannot be imported: a stale swiftinterface, a wrong
# deployment target, or a framework that lost its module map.

set -euo pipefail

cd "$(dirname "$0")/.."

source Script/platforms.sh

XCFRAMEWORKS_DIR="${1-}"
if [ -z "$XCFRAMEWORKS_DIR" ] || [ ! -d "$XCFRAMEWORKS_DIR" ]; then
	echo "Usage: $0 <xcframeworks_dir>"
	exit 1
fi

SWIFT_SOURCE=$(mktemp /tmp/wcdb-import-swift.XXXXXX.swift)
OBJC_SOURCE=$(mktemp /tmp/wcdb-import-objc.XXXXXX.m)
trap 'rm -f "$SWIFT_SOURCE" "$OBJC_SOURCE"' EXIT

echo "import WCDBSwift" >"$SWIFT_SOURCE"
echo "@import WCDBObjc;" >"$OBJC_SOURCE"

# shard|SDK|target triple|SupportedPlatform|SupportedPlatformVariant
# swiftc and clang share the target triple, which uses the deployment targets
# from platforms.sh. The slice directory is looked up in the XCFramework, so
# an architecture change in a new Xcode does not need an edit here.
CHECKS="
ios|iphoneos|arm64-apple-ios12.0|ios|
ios-simulator|iphonesimulator|arm64-apple-ios12.0-simulator|ios|simulator
macos|macosx|arm64-apple-macos10.13|macos|
macos-catalyst|macosx|arm64-apple-ios13.1-macabi|ios|maccatalyst
tvos|appletvos|arm64-apple-tvos12.4|tvos|
tvos-simulator|appletvsimulator|arm64-apple-tvos12.4-simulator|tvos|simulator
watchos|watchos|arm64_32-apple-watchos6.0|watchos|
watchos-simulator|watchsimulator|arm64-apple-watchos6.0-simulator|watchos|simulator
visionos|xros|arm64-apple-xros1.0|xros|
visionos-simulator|xrsimulator|arm64-apple-xros1.0-simulator|xros|simulator
"

# A shard added to platforms.sh without a check here would ship untested.
for shard in $(platforms_list); do
	if ! grep -q "^$shard|" <<<"$CHECKS"; then
		echo "[!] $shard: no consumer import check in $0"
		exit 1
	fi
done

# Print the slice directory an XCFramework uses for a platform and variant.
slice_directory() {
	python3 -c '
import plistlib, sys
path, platform, variant = sys.argv[1], sys.argv[2], sys.argv[3] or None
with open(path + "/Info.plist", "rb") as handle:
    libraries = plistlib.load(handle)["AvailableLibraries"]
for library in libraries:
    identity = (library["SupportedPlatform"], library.get("SupportedPlatformVariant"))
    if identity == (platform, variant):
        print(library["LibraryIdentifier"])
' "$1" "$2" "$3"
}

FAILED=0

while IFS='|' read -r shard sdk target platform variant; do
	[ -z "$shard" ] && continue

	swift_xcframework="$XCFRAMEWORKS_DIR/WCDBSwift.xcframework"
	objc_xcframework="$XCFRAMEWORKS_DIR/WCDBObjc.xcframework"
	swift_slice="$swift_xcframework/$(slice_directory "$swift_xcframework" "$platform" "$variant")"
	objc_slice="$objc_xcframework/$(slice_directory "$objc_xcframework" "$platform" "$variant")"

	if [ ! -d "$swift_slice/WCDBSwift.framework" ] || [ ! -d "$objc_slice/WCDBObjc.framework" ]; then
		echo "[!] $shard: missing $platform/${variant:-device} slice"
		FAILED=1
		continue
	fi

	shard_failed=0

	if ! xcrun --sdk "$sdk" swiftc -typecheck -target "$target" \
		-F "$swift_slice" "$SWIFT_SOURCE"; then
		echo "[!] $shard: cannot import WCDBSwift"
		shard_failed=1
	fi

	if ! xcrun --sdk "$sdk" clang -fsyntax-only -fmodules \
		-target "$target" -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
		-F "$objc_slice" "$OBJC_SOURCE"; then
		echo "[!] $shard: cannot import WCDBObjc"
		shard_failed=1
	fi

	if [ "$shard_failed" -ne 0 ]; then
		FAILED=1
	else
		echo "[*] $shard: imports WCDBSwift and WCDBObjc"
	fi
done <<<"$CHECKS"

if [ "$FAILED" -ne 0 ]; then
	echo "[!] consumer import check failed"
	exit 1
fi

echo "[*] all platform slices import successfully"
