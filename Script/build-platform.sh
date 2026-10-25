#!/bin/bash

# Usage: ./build-platform.sh <wcdb_source_dir> <scheme> <platform> <output_dir>
# Platforms: see ./platforms.sh (ios, ios-simulator, macos, macos-catalyst,
#            tvos, tvos-simulator, watchos, watchos-simulator, visionos,
#            visionos-simulator)
#
# Set DERIVED_DATA_PATH to keep build products out of the default Xcode
# DerivedData directory (CI leaves it unset).

set -euo pipefail

cd "$(dirname "$0")/.."

source Script/platforms.sh

WCDB_SOURCE_DIR="${1-}"
SCHEME="${2-}"
PLATFORM="${3-}"
OUTPUT_DIR="${4-}"

if [ -z "$WCDB_SOURCE_DIR" ] || [ -z "$SCHEME" ] || [ -z "$PLATFORM" ] || [ -z "$OUTPUT_DIR" ]; then
	echo "Usage: $0 <wcdb_source_dir> <scheme> <platform> <output_dir>"
	echo "Platforms: $(platforms_list)"
	exit 1
fi

if ! platforms_list | tr ' ' '\n' | grep -Fxq "$PLATFORM"; then
	echo "[!] Unknown platform: $PLATFORM"
	echo "Valid platforms: $(platforms_list)"
	exit 1
fi

PROJECT_FILE="$WCDB_SOURCE_DIR/src/WCDB.xcodeproj"
if [ ! -d "$PROJECT_FILE" ]; then
	echo "[!] Project not found: $PROJECT_FILE"
	exit 1
fi

DESTINATION=$(platform_destination "$PLATFORM")

PLATFORM_SETTINGS=()
while IFS= read -r setting; do
	if [ -n "$setting" ]; then
		PLATFORM_SETTINGS+=("$setting")
	fi
done < <(platform_build_settings "$PLATFORM")

EXTRA_ARGS=()
if [ ${#PLATFORM_SETTINGS[@]} -gt 0 ]; then
	EXTRA_ARGS=("${PLATFORM_SETTINGS[@]}")
fi
if [ -n "${DERIVED_DATA_PATH:-}" ]; then
	EXTRA_ARGS+=("-derivedDataPath" "$DERIVED_DATA_PATH")
fi

echo "[*] Building $SCHEME for $PLATFORM"
echo "[*] Project: $PROJECT_FILE"
echo "[*] Destination: $DESTINATION"
echo "[*] Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

ARCHIVE_PATH="$OUTPUT_DIR/$SCHEME-$PLATFORM"

echo "[*] Archive path: $ARCHIVE_PATH"

# Never let a failed rebuild leave the previous archive in place for the merge
# step to pick up.
rm -rf "$ARCHIVE_PATH.xcarchive"

run_archive() {
	local build_settings=()
	if [ ${#EXTRA_ARGS[@]} -gt 0 ]; then
		build_settings=("${EXTRA_ARGS[@]}")
	fi
	if [ "$SCHEME" = "WCDBSwift" ]; then
		build_settings+=(BUILD_LIBRARY_FOR_DISTRIBUTION=YES)
	fi
	# Bitcode is gone from current toolchains, but upstream still sets it for
	# tvOS. Frameworks are not signed, so skip signing to keep runner
	# identities out of the archive.
	build_settings+=(ENABLE_BITCODE=NO CODE_SIGNING_ALLOWED=NO)
	xcodebuild archive \
		-project "$PROJECT_FILE" \
		-scheme "$SCHEME" \
		-configuration Release \
		-destination "$DESTINATION" \
		-archivePath "$ARCHIVE_PATH" \
		SKIP_INSTALL=NO \
		"${build_settings[@]+"${build_settings[@]}"}"
}

if command -v xcbeautify &>/dev/null; then
	run_archive 2>&1 | xcbeautify
else
	run_archive
fi

FRAMEWORK_PATH="$ARCHIVE_PATH.xcarchive/Products/Library/Frameworks/$SCHEME.framework"
if [ ! -d "$FRAMEWORK_PATH" ]; then
	echo "[!] Archive completed without $SCHEME.framework: $FRAMEWORK_PATH"
	exit 1
fi

echo "[*] Build complete: $ARCHIVE_PATH.xcarchive"
