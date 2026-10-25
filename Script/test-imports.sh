#!/bin/bash

# Usage: ./test-imports.sh <xcframeworks_dir>
#
# Compile a one-line consumer against every slice. This catches a slice that
# merged successfully but cannot be imported: a stale swiftinterface, a wrong
# deployment target, or a framework that lost its module map.

set -euo pipefail

cd "$(dirname "$0")/.."

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

# shard:SDK:clang target:Swift target slice directory
# The Swift target for a shard is the same as the clang target.
CHECKS="
ios|iphoneos|arm64-apple-ios12.0|ios-arm64
ios-simulator|iphonesimulator|arm64-apple-ios12.0-simulator|ios-arm64_x86_64-simulator
macos|macosx|arm64-apple-macos10.13|macos-arm64_x86_64
macos-catalyst|macosx|arm64-apple-ios13.1-macabi|ios-arm64_x86_64-maccatalyst
tvos|appletvos|arm64-apple-tvos12.4|tvos-arm64
tvos-simulator|appletvsimulator|arm64-apple-tvos12.4-simulator|tvos-arm64_x86_64-simulator
watchos|watchos|arm64_32-apple-watchos6.0|watchos-arm64_arm64_32_armv7k
watchos-simulator|watchsimulator|arm64-apple-watchos6.0-simulator|watchos-arm64_x86_64-simulator
visionos|xros|arm64-apple-xros1.0|xros-arm64
visionos-simulator|xrsimulator|arm64-apple-xros1.0-simulator|xros-arm64-simulator
"

FAILED=0

while IFS='|' read -r shard sdk target slice; do
	[ -z "$shard" ] && continue

	swift_slice="$XCFRAMEWORKS_DIR/WCDBSwift.xcframework/$slice"
	objc_slice="$XCFRAMEWORKS_DIR/WCDBObjc.xcframework/$slice"

	if [ ! -d "$swift_slice" ] || [ ! -d "$objc_slice" ]; then
		echo "[!] $shard: missing slice ($swift_slice or $objc_slice)"
		FAILED=1
		continue
	fi

	if ! xcrun --sdk "$sdk" swiftc -typecheck -target "$target" \
		-F "$swift_slice" "$SWIFT_SOURCE"; then
		echo "[!] $shard: cannot import WCDBSwift"
		FAILED=1
	fi

	if ! xcrun --sdk "$sdk" clang -fsyntax-only -fmodules \
		-target "$target" -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
		-F "$objc_slice" "$OBJC_SOURCE"; then
		echo "[!] $shard: cannot import WCDBObjc"
		FAILED=1
	fi

	echo "[*] $shard: imports WCDBSwift and WCDBObjc"
done <<<"$CHECKS"

if [ "$FAILED" -ne 0 ]; then
	echo "[!] consumer import check failed"
	exit 1
fi

echo "[*] all platform slices import successfully"
