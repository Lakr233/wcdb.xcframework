#!/bin/bash

# Usage: ./build-platform.sh <wcdb_source_dir> <scheme> <platform> <output_dir>
# Platforms: ios, ios-simulator, macos, macos-catalyst, tvos, tvos-simulator, watchos, watchos-simulator

set -euo pipefail

cd "$(dirname "$0")/.."

WCDB_SOURCE_DIR="${1-}"
SCHEME="${2-}"
PLATFORM="${3-}"
OUTPUT_DIR="${4-}"

if [ -z "$WCDB_SOURCE_DIR" ] || [ -z "$SCHEME" ] || [ -z "$PLATFORM" ] || [ -z "$OUTPUT_DIR" ]; then
	echo "Usage: $0 <wcdb_source_dir> <scheme> <platform> <output_dir>"
	echo "Platforms: ios, ios-simulator, macos, macos-catalyst, tvos, tvos-simulator, watchos, watchos-simulator"
	exit 1
fi

PROJECT_FILE="$WCDB_SOURCE_DIR/src/WCDB.xcodeproj"
if [ ! -d "$PROJECT_FILE" ]; then
	echo "[!] Project not found: $PROJECT_FILE"
	exit 1
fi

echo "[*] Building $SCHEME for $PLATFORM"
echo "[*] Project: $PROJECT_FILE"
echo "[*] Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

case "$PLATFORM" in
ios)
	DESTINATION="generic/platform=iOS,name=Any iOS Device"
	;;
ios-simulator)
	DESTINATION="generic/platform=iOS Simulator"
	;;
macos)
	DESTINATION="generic/platform=macOS,name=Any Mac"
	;;
macos-catalyst)
	DESTINATION="generic/platform=macOS,variant=Mac Catalyst,name=Any Mac"
	;;
tvos)
	DESTINATION="generic/platform=tvOS,name=Any tvOS Device"
	;;
tvos-simulator)
	DESTINATION="generic/platform=tvOS Simulator"
	;;
watchos)
	DESTINATION="generic/platform=watchOS,name=Any watchOS Device"
	;;
watchos-simulator)
	DESTINATION="generic/platform=watchOS Simulator"
	;;
*)
	echo "[!] Unknown platform: $PLATFORM"
	echo "Valid platforms: ios, ios-simulator, macos, macos-catalyst, tvos, tvos-simulator, watchos, watchos-simulator"
	exit 1
	;;
esac

ARCHIVE_PATH="$OUTPUT_DIR/$SCHEME-$PLATFORM"

echo "[*] Destination: $DESTINATION"
echo "[*] Archive path: $ARCHIVE_PATH"

run_archive() {
	local extra_args=()
	if [ "$SCHEME" = "WCDBSwift" ]; then
		extra_args=(BUILD_LIBRARY_FOR_DISTRIBUTION=YES)
	fi
	xcodebuild archive \
		-project "$PROJECT_FILE" \
		-scheme "$SCHEME" \
		-configuration Release \
		-destination "$DESTINATION" \
		-archivePath "$ARCHIVE_PATH" \
		SKIP_INSTALL=NO \
		"${extra_args[@]}"
}

if command -v xcbeautify &>/dev/null; then
	run_archive 2>&1 | xcbeautify
else
	run_archive
fi

if [ ! -d "$ARCHIVE_PATH.xcarchive" ]; then
	echo "[!] Archive not created: $ARCHIVE_PATH.xcarchive"
	exit 1
fi

echo "[*] Build complete: $ARCHIVE_PATH.xcarchive"
