#!/bin/bash

# Usage: ./merge-xcframework.sh <archives_dir> <output_dir>

set -euo pipefail

cd "$(dirname "$0")/.."

ARCHIVES_DIR="${1-}"
OUTPUT_DIR="${2-}"

if [ -z "$ARCHIVES_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
	echo "Usage: $0 <archives_dir> <output_dir>"
	exit 1
fi

echo "[*] Merging xcframeworks from: $ARCHIVES_DIR"
echo "[*] Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

SCHEMES="WCDBSwift WCDBObjc"
PLATFORMS="ios ios-simulator macos macos-catalyst tvos tvos-simulator watchos watchos-simulator"

for SCHEME in $SCHEMES; do
	echo "[*] Creating $SCHEME.xcframework..."

	XCFRAMEWORK_CMD=("xcodebuild" "-create-xcframework")

	for PLATFORM in $PLATFORMS; do
		ARCHIVE_PATH="$ARCHIVES_DIR/$SCHEME-$PLATFORM.xcarchive"
		if [ ! -d "$ARCHIVE_PATH" ]; then
			echo "[!] Missing archive: $ARCHIVE_PATH"
			exit 1
		fi
		XCFRAMEWORK_CMD+=("-archive" "$ARCHIVE_PATH" "-framework" "$SCHEME.framework")
	done

	XCFRAMEWORK_PATH="$OUTPUT_DIR/$SCHEME.xcframework"
	rm -rf "$XCFRAMEWORK_PATH"
	XCFRAMEWORK_CMD+=("-output" "$XCFRAMEWORK_PATH")

	echo "[*] Running: ${XCFRAMEWORK_CMD[*]}"
	"${XCFRAMEWORK_CMD[@]}"

	echo "[*] Created: $XCFRAMEWORK_PATH"
done

echo "[*] All xcframeworks created successfully"
