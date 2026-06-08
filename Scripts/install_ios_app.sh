#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_ID="${IOS_DEVICE_ID:-${1:-}}"
APP_DIR="${2:-$ROOT_DIR/.build/ios-device/Xvideo.app}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.seeker.xvideo}"

if [ -z "$DEVICE_ID" ]; then
    echo "Set IOS_DEVICE_ID or pass a device identifier. Available devices:" >&2
    xcrun devicectl list devices >&2
    exit 2
fi

if [ ! -d "$APP_DIR" ]; then
    echo "App bundle not found: $APP_DIR" >&2
    echo "Run Scripts/build_ios_app.sh first." >&2
    exit 2
fi

if [ ! -f "$APP_DIR/embedded.mobileprovision" ]; then
    echo "Missing embedded.mobileprovision in $APP_DIR." >&2
    echo "Set IOS_PROVISIONING_PROFILE when running Scripts/build_ios_app.sh." >&2
    exit 2
fi

if ! codesign --verify --strict "$APP_DIR" >/dev/null 2>&1; then
    echo "App bundle is not signed with a valid local identity." >&2
    echo "Set IOS_SIGNING_IDENTITY when running Scripts/build_ios_app.sh." >&2
    exit 2
fi

xcrun devicectl device install app --device "$DEVICE_ID" "$APP_DIR"
xcrun devicectl device process launch --device "$DEVICE_ID" "$IOS_BUNDLE_ID"
