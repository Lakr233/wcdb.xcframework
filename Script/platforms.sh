#!/bin/bash

# Single source of truth for the platform shards. build-platform.sh,
# merge-xcframework.sh and the release workflow read this list, so adding a
# slice cannot leave another step behind. Script/test-imports.sh carries the
# matching consumer targets and fails when a shard here has none.
#
# Shard names are also the archive suffix: <scheme>-<shard>.xcarchive.
# They stay stable so existing release tooling keeps working.

platforms_list() {
	echo "ios ios-simulator macos macos-catalyst tvos tvos-simulator watchos watchos-simulator visionos visionos-simulator"
}

# The xcodebuild destination for one shard.
platform_destination() {
	case "$1" in
	ios) echo "generic/platform=iOS,name=Any iOS Device" ;;
	ios-simulator) echo "generic/platform=iOS Simulator" ;;
	macos) echo "generic/platform=macOS,name=Any Mac" ;;
	macos-catalyst) echo "generic/platform=macOS,variant=Mac Catalyst,name=Any Mac" ;;
	tvos) echo "generic/platform=tvOS,name=Any tvOS Device" ;;
	tvos-simulator) echo "generic/platform=tvOS Simulator" ;;
	watchos) echo "generic/platform=watchOS,name=Any watchOS Device" ;;
	watchos-simulator) echo "generic/platform=watchOS Simulator" ;;
	visionos) echo "generic/platform=visionOS" ;;
	visionos-simulator) echo "generic/platform=visionOS Simulator" ;;
	*)
		echo "[!] Unknown platform shard: $1" >&2
		return 1
		;;
	esac
}

# Deployment targets for every shard. Passing them on the command line makes
# them reach the zstd and sqlcipher subprojects too, whose own floors (iOS 8,
# tvOS 9, watchOS 2) are older than current SDKs support.
#
# They are WCDB's floors except where the SDK no longer goes that low: WCDB
# declares iOS 11.0, and Xcode 26 supports iOS 12.0 and later. Upstream has no
# visionOS floor, and without one Xcode uses the SDK version.
#
# Script/verify-xcframework.py, Script/test-imports.sh, Package.swift.template
# and README.md carry the same numbers. When a newer default Xcode drops one
# of these, the build or the verify step fails; raise it in all five places.
deployment_targets() {
	echo "IPHONEOS_DEPLOYMENT_TARGET=12.0"
	echo "MACOSX_DEPLOYMENT_TARGET=10.13"
	echo "TVOS_DEPLOYMENT_TARGET=12.4"
	echo "WATCHOS_DEPLOYMENT_TARGET=6.0"
	echo "XROS_DEPLOYMENT_TARGET=1.0"
}

# Extra KEY=VALUE build settings, one per line.
#
# visionOS has no Intel simulator, but a generic simulator destination still
# resolves ARCHS to "arm64 x86_64"; pin it so we do not publish a slice that can
# never run.
platform_build_settings() {
	deployment_targets
	case "$1" in
	visionos-simulator)
		echo "ARCHS=arm64"
		;;
	esac
}
