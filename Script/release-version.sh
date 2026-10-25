#!/bin/bash

# Usage: ./release-version.sh <wcdb_version> [remote]
#
# Print the tags for a new release as KEY=VALUE lines for $GITHUB_OUTPUT:
#
#   package_version      <WCDB major>.<WCDB minor>.<yymmdd><NN>, e.g. 2.1.26102501
#   storage_release_tag  storage.<WCDB version>.<UTC timestamp>
#
# Every release gets tags that have never existed, so publishing never deletes
# or moves a tag that consumers may have resolved. NN counts releases on the
# same UTC day, starting at 01. A new WCDB major or minor version starts a new
# series; the WCDB patch version only appears in the storage tag and the notes.
#
# RELEASE_NOW (UTC, YYYYmmddHHMMSS) overrides the clock for testing.

set -euo pipefail

WCDB_VERSION="${1-}"
REMOTE="${2-origin}"

if ! [[ "$WCDB_VERSION" =~ ^([0-9]+)\.([0-9]+)\.[0-9]+$ ]]; then
	echo "[!] Expected a WCDB version like 2.1.16, got: '$WCDB_VERSION'" >&2
	exit 1
fi
SERIES="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"

NOW="${RELEASE_NOW:-$(date -u +%Y%m%d%H%M%S)}"
if ! [[ "$NOW" =~ ^[0-9]{14}$ ]]; then
	echo "[!] RELEASE_NOW must be YYYYmmddHHMMSS, got: '$NOW'" >&2
	exit 1
fi
DAY="${NOW:2:6}"

TAGS=$(git ls-remote --tags --refs "$REMOTE" | sed 's|.*refs/tags/||')

LAST_INDEX=0
while IFS= read -r tag; do
	if [[ "$tag" =~ ^${SERIES//./\\.}\.${DAY}([0-9]{2})$ ]]; then
		index=$((10#${BASH_REMATCH[1]}))
		if [ "$index" -gt "$LAST_INDEX" ]; then
			LAST_INDEX=$index
		fi
	fi
done <<<"$TAGS"

INDEX=$((LAST_INDEX + 1))
if [ "$INDEX" -gt 99 ]; then
	echo "[!] $SERIES.$DAY already has 99 releases" >&2
	exit 1
fi

PACKAGE_VERSION=$(printf '%s.%s%02d' "$SERIES" "$DAY" "$INDEX")
STORAGE_RELEASE_TAG="storage.$WCDB_VERSION.$NOW"

for tag in "$PACKAGE_VERSION" "$STORAGE_RELEASE_TAG"; do
	if grep -Fxq "$tag" <<<"$TAGS"; then
		echo "[!] Tag already exists: $tag" >&2
		exit 1
	fi
done

echo "package_version=$PACKAGE_VERSION"
echo "storage_release_tag=$STORAGE_RELEASE_TAG"
