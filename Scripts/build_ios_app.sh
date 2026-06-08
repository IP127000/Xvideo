#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-debug}"
IOS_TRIPLE="${IOS_TRIPLE:-arm64-apple-ios}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.seeker.xvideo}"
IOS_SIGNING_IDENTITY="${IOS_SIGNING_IDENTITY:-}"
IOS_PROVISIONING_PROFILE="${IOS_PROVISIONING_PROFILE:-}"
IOS_ENTITLEMENTS="${IOS_ENTITLEMENTS:-}"

SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
BUILD_DIR="$ROOT_DIR/.build/$IOS_TRIPLE/$CONFIGURATION"
APP_DIR="$ROOT_DIR/.build/ios-device/Xvideo.app"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" --triple "$IOS_TRIPLE" --sdk "$SDK_PATH"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp "$BUILD_DIR/Xvideo" "$APP_DIR/Xvideo"

if [ -d "$BUILD_DIR/Xvideo_Xvideo.bundle" ]; then
    ditto "$BUILD_DIR/Xvideo_Xvideo.bundle" "$APP_DIR/Xvideo_Xvideo.bundle"
fi

if [ -d "$ROOT_DIR/Sources/Xvideo/Resources" ]; then
    ditto "$ROOT_DIR/Sources/Xvideo/Resources" "$APP_DIR/Resources"
fi

cat > "$APP_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Xvideo</string>
    <key>CFBundleIdentifier</key>
    <string>$IOS_BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>Xvideo</string>
    <key>CFBundleDisplayName</key>
    <string>Xvideo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>MinimumOSVersion</key>
    <string>17.0</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
    </array>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

if [ -n "$IOS_PROVISIONING_PROFILE" ]; then
    cp "$IOS_PROVISIONING_PROFILE" "$APP_DIR/embedded.mobileprovision"
fi

if [ -n "$IOS_SIGNING_IDENTITY" ]; then
    SIGN_ARGS=(--force --sign "$IOS_SIGNING_IDENTITY" --timestamp=none --generate-entitlement-der)
    if [ -n "$IOS_ENTITLEMENTS" ]; then
        SIGN_ARGS+=(--entitlements "$IOS_ENTITLEMENTS")
    fi
    codesign "${SIGN_ARGS[@]}" --deep "$APP_DIR"
else
    echo "Built unsigned iOS app. Set IOS_SIGNING_IDENTITY and IOS_PROVISIONING_PROFILE to prepare for device install." >&2
fi

echo "$APP_DIR"
