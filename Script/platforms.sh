#!/bin/bash

# Single source of truth for the platform shards. build-platform.sh,
# merge-xcframework.sh and the release workflow read this list, so adding a
# slice cannot leave another step behind. Script/test-imports.sh carries the
# matching consumer targets; update it when a shard is added.
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

# Extra KEY=VALUE build settings, one per line.
#
# XROS_DEPLOYMENT_TARGET must be pinned: without it Xcode uses the SDK version
# as the minimum and the slice claims it needs the newest visionOS. The
# upstream project has no xros deployment setting.
#
# visionOS has no Intel simulator, but a generic simulator destination still
# resolves ARCHS to "arm64 x86_64"; pin it so we do not publish a slice that can
# never run.
platform_build_settings() {
	case "$1" in
	visionos)
		echo "XROS_DEPLOYMENT_TARGET=1.0"
		# Current SDKs refuse the old tvOS floor declared by the zstd and
		# sqlcipher subprojects. The setting only satisfies that validation;
		# this archive contains no tvOS code.
		echo "TVOS_DEPLOYMENT_TARGET=15.0"
		;;
	visionos-simulator)
		echo "XROS_DEPLOYMENT_TARGET=1.0"
		echo "TVOS_DEPLOYMENT_TARGET=15.0"
		echo "ARCHS=arm64"
		;;
	esac
}
