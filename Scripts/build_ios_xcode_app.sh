#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
IOS_APP_NAME="${IOS_APP_NAME:-Xvideo}"
IOS_PROJECT_NAME="${IOS_PROJECT_NAME:-XvideoiOS}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.seeker.xvideo}"
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-17.0}"
IOS_DEVELOPMENT_TEAM="${IOS_DEVELOPMENT_TEAM:-}"
IOS_DESTINATION="${IOS_DESTINATION:-}"
IOS_DERIVED_DATA="${IOS_DERIVED_DATA:-$ROOT_DIR/.build/ios-derived}"
WORK_DIR="$ROOT_DIR/.build/ios-xcode"
PROJECT_DIR="$WORK_DIR/$IOS_PROJECT_NAME.xcodeproj"
APP_DIR="${IOS_APP_DIR:-$ROOT_DIR/.build/ios-device/$IOS_APP_NAME.app}"

infer_development_team() {
    local cert_file
    cert_file="$(mktemp)"
    security find-certificate -a -p -c "Apple Development" 2>/dev/null \
        | awk '/-----BEGIN CERTIFICATE-----/ { capture = 1 } capture { print } /-----END CERTIFICATE-----/ { exit }' \
        > "$cert_file"

    if [ -s "$cert_file" ]; then
        openssl x509 -noout -subject -in "$cert_file" 2>/dev/null \
            | sed -n 's/.*\/OU=\([A-Z0-9]*\).*/\1/p'
    fi

    rm -f "$cert_file"
}

if [ -z "$IOS_DEVELOPMENT_TEAM" ]; then
    IOS_DEVELOPMENT_TEAM="$(infer_development_team || true)"
fi

if [ -z "$IOS_DEVELOPMENT_TEAM" ]; then
    echo "Unable to infer IOS_DEVELOPMENT_TEAM from an Apple Development certificate." >&2
    echo "Set IOS_DEVELOPMENT_TEAM to your Apple team id and rerun this script." >&2
    exit 2
fi

if [ -z "$IOS_DESTINATION" ]; then
    if [ -n "${IOS_DEVICE_UDID:-}" ]; then
        IOS_DESTINATION="id=$IOS_DEVICE_UDID"
    elif [ -n "${IOS_DEVICE_ID:-}" ]; then
        IOS_DESTINATION="id=$IOS_DEVICE_ID"
    else
        IOS_DESTINATION="generic/platform=iOS"
    fi
fi

rm -rf "$WORK_DIR"
mkdir -p "$PROJECT_DIR"

export ROOT_DIR
export WORK_DIR
export PROJECT_DIR
export IOS_APP_NAME
export IOS_PROJECT_NAME
export IOS_BUNDLE_ID
export IOS_DEPLOYMENT_TARGET
export IOS_DEVELOPMENT_TEAM

ruby <<'RUBY'
require "digest"
require "fileutils"

root_dir = ENV.fetch("ROOT_DIR")
work_dir = ENV.fetch("WORK_DIR")
project_dir = ENV.fetch("PROJECT_DIR")
app_name = ENV.fetch("IOS_APP_NAME")
project_name = ENV.fetch("IOS_PROJECT_NAME")
bundle_id = ENV.fetch("IOS_BUNDLE_ID")
deployment_target = ENV.fetch("IOS_DEPLOYMENT_TARGET")
development_team = ENV.fetch("IOS_DEVELOPMENT_TEAM")

def pbx_id(seed)
  Digest::SHA1.hexdigest(seed).upcase[0, 24]
end

def q(value)
  %("#{value.to_s.gsub("\\", "\\\\\\").gsub('"', '\\"')}")
end

source_paths = Dir.glob(File.join(root_dir, "Sources/Xvideo/**/*.swift")).sort
raise "No Swift source files found under Sources/Xvideo" if source_paths.empty?

framework_names = ["AVKit.framework", "WebKit.framework", "UIKit.framework"]

source_refs = source_paths.map do |path|
  {
    path: path,
    name: File.basename(path),
    file_ref: pbx_id("file:#{path}"),
    build_file: pbx_id("build-file:#{path}")
  }
end

framework_refs = framework_names.map do |name|
  {
    name: name,
    file_ref: pbx_id("framework:#{name}"),
    build_file: pbx_id("framework-build-file:#{name}")
  }
end

ids = {
  main_group: pbx_id("group:main"),
  sources_group: pbx_id("group:sources"),
  frameworks_group: pbx_id("group:frameworks"),
  products_group: pbx_id("group:products"),
  product_ref: pbx_id("product:#{app_name}.app"),
  target: pbx_id("target:#{app_name}"),
  project: pbx_id("project:#{project_name}"),
  sources_phase: pbx_id("phase:sources"),
  frameworks_phase: pbx_id("phase:frameworks"),
  resources_phase: pbx_id("phase:resources"),
  project_configs: pbx_id("configs:project"),
  target_configs: pbx_id("configs:target"),
  project_debug: pbx_id("config:project:debug"),
  project_release: pbx_id("config:project:release"),
  target_debug: pbx_id("config:target:debug"),
  target_release: pbx_id("config:target:release")
}

pbx = []
pbx << ('// !$*UTF8*$!')
pbx << "{"
pbx << "\tarchiveVersion = 1;"
pbx << "\tclasses = {};"
pbx << "\tobjectVersion = 56;"
pbx << "\tobjects = {"
pbx << ""

pbx << "/* Begin PBXBuildFile section */"
source_refs.each do |source|
  pbx << "\t\t#{source[:build_file]} /* #{source[:name]} in Sources */ = {isa = PBXBuildFile; fileRef = #{source[:file_ref]}; };"
end
framework_refs.each do |framework|
  pbx << "\t\t#{framework[:build_file]} /* #{framework[:name]} in Frameworks */ = {isa = PBXBuildFile; fileRef = #{framework[:file_ref]}; };"
end
pbx << "/* End PBXBuildFile section */"
pbx << ""

pbx << "/* Begin PBXFileReference section */"
source_refs.each do |source|
  pbx << "\t\t#{source[:file_ref]} /* #{source[:name]} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{q(source[:path])}; sourceTree = \"<absolute>\"; };"
end
framework_refs.each do |framework|
  pbx << "\t\t#{framework[:file_ref]} /* #{framework[:name]} */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = #{framework[:name]}; path = System/Library/Frameworks/#{framework[:name]}; sourceTree = SDKROOT; };"
end
pbx << "\t\t#{ids[:product_ref]} /* #{app_name}.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = #{app_name}.app; sourceTree = BUILT_PRODUCTS_DIR; };"
pbx << "/* End PBXFileReference section */"
pbx << ""

pbx << "/* Begin PBXFrameworksBuildPhase section */"
pbx << "\t\t#{ids[:frameworks_phase]} /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (#{framework_refs.map { |framework| framework[:build_file] }.join(", ")}); runOnlyForDeploymentPostprocessing = 0; };"
pbx << "/* End PBXFrameworksBuildPhase section */"
pbx << ""

pbx << "/* Begin PBXGroup section */"
pbx << "\t\t#{ids[:main_group]} = {isa = PBXGroup; children = (#{ids[:sources_group]}, #{ids[:frameworks_group]}, #{ids[:products_group]}); sourceTree = \"<group>\"; };"
pbx << "\t\t#{ids[:sources_group]} /* Sources */ = {isa = PBXGroup; children = (#{source_refs.map { |source| source[:file_ref] }.join(", ")}); name = Sources; sourceTree = \"<group>\"; };"
pbx << "\t\t#{ids[:frameworks_group]} /* Frameworks */ = {isa = PBXGroup; children = (#{framework_refs.map { |framework| framework[:file_ref] }.join(", ")}); name = Frameworks; sourceTree = \"<group>\"; };"
pbx << "\t\t#{ids[:products_group]} /* Products */ = {isa = PBXGroup; children = (#{ids[:product_ref]}); name = Products; sourceTree = \"<group>\"; };"
pbx << "/* End PBXGroup section */"
pbx << ""

pbx << "/* Begin PBXNativeTarget section */"
pbx << "\t\t#{ids[:target]} /* #{app_name} */ = {isa = PBXNativeTarget; buildConfigurationList = #{ids[:target_configs]}; buildPhases = (#{ids[:sources_phase]}, #{ids[:frameworks_phase]}, #{ids[:resources_phase]}); buildRules = (); dependencies = (); name = #{app_name}; productName = #{app_name}; productReference = #{ids[:product_ref]}; productType = \"com.apple.product-type.application\"; };"
pbx << "/* End PBXNativeTarget section */"
pbx << ""

pbx << "/* Begin PBXProject section */"
pbx << "\t\t#{ids[:project]} /* Project object */ = {isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 2650; LastUpgradeCheck = 2650; TargetAttributes = {#{ids[:target]} = {CreatedOnToolsVersion = 26.5; ProvisioningStyle = Automatic;};};}; buildConfigurationList = #{ids[:project_configs]}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = #{ids[:main_group]}; productRefGroup = #{ids[:products_group]}; projectDirPath = \"\"; projectRoot = \"\"; targets = (#{ids[:target]}); };"
pbx << "/* End PBXProject section */"
pbx << ""

pbx << "/* Begin PBXResourcesBuildPhase section */"
pbx << "\t\t#{ids[:resources_phase]} /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };"
pbx << "/* End PBXResourcesBuildPhase section */"
pbx << ""

pbx << "/* Begin PBXSourcesBuildPhase section */"
pbx << "\t\t#{ids[:sources_phase]} /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (#{source_refs.map { |source| source[:build_file] }.join(", ")}); runOnlyForDeploymentPostprocessing = 0; };"
pbx << "/* End PBXSourcesBuildPhase section */"
pbx << ""

project_common = "ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ANALYZER_NONNULL = YES; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; CLANG_WARN_DOCUMENTATION_COMMENTS = YES; CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES; ENABLE_STRICT_OBJC_MSGSEND = YES; GCC_C_LANGUAGE_STANDARD = gnu17; GCC_NO_COMMON_BLOCKS = YES; IPHONEOS_DEPLOYMENT_TARGET = #{deployment_target}; SDKROOT = iphoneos; SWIFT_VERSION = 6.0;"
target_common = "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; DEVELOPMENT_TEAM = #{development_team}; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Info.plist; MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = #{bundle_id}; PRODUCT_NAME = #{app_name}; SUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\"; SUPPORTS_MACCATALYST = NO; SWIFT_VERSION = 6.0; TARGETED_DEVICE_FAMILY = 1;"

pbx << "/* Begin XCBuildConfiguration section */"
pbx << "\t\t#{ids[:project_debug]} /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {#{project_common} COPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = dwarf;}; name = Debug; };"
pbx << "\t\t#{ids[:project_release]} /* Release */ = {isa = XCBuildConfiguration; buildSettings = {#{project_common} COPY_PHASE_STRIP = YES; DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";}; name = Release; };"
pbx << "\t\t#{ids[:target_debug]} /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {#{target_common}}; name = Debug; };"
pbx << "\t\t#{ids[:target_release]} /* Release */ = {isa = XCBuildConfiguration; buildSettings = {#{target_common} SWIFT_COMPILATION_MODE = wholemodule;}; name = Release; };"
pbx << "/* End XCBuildConfiguration section */"
pbx << ""

pbx << "/* Begin XCConfigurationList section */"
pbx << "\t\t#{ids[:project_configs]} /* Build configuration list for PBXProject */ = {isa = XCConfigurationList; buildConfigurations = (#{ids[:project_debug]}, #{ids[:project_release]}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };"
pbx << "\t\t#{ids[:target_configs]} /* Build configuration list for PBXNativeTarget */ = {isa = XCConfigurationList; buildConfigurations = (#{ids[:target_debug]}, #{ids[:target_release]}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };"
pbx << "/* End XCConfigurationList section */"
pbx << ""
pbx << "\t};"
pbx << "\trootObject = #{ids[:project]} /* Project object */;"
pbx << "}"

File.write(File.join(project_dir, "project.pbxproj"), pbx.join("\n") + "\n")

FileUtils.mkdir_p(File.join(project_dir, "project.xcworkspace"))
File.write(
  File.join(project_dir, "project.xcworkspace", "contents.xcworkspacedata"),
  <<~XML
  <?xml version="1.0" encoding="UTF-8"?>
  <Workspace
     version = "1.0">
     <FileRef
        location = "self:">
     </FileRef>
  </Workspace>
  XML
)

File.write(
  File.join(work_dir, "Info.plist"),
  <<~PLIST
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>CFBundleDevelopmentRegion</key>
      <string>$(DEVELOPMENT_LANGUAGE)</string>
      <key>CFBundleDisplayName</key>
      <string>#{app_name}</string>
      <key>CFBundleExecutable</key>
      <string>$(EXECUTABLE_NAME)</string>
      <key>CFBundleIdentifier</key>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
      <key>CFBundleInfoDictionaryVersion</key>
      <string>6.0</string>
      <key>CFBundleName</key>
      <string>$(PRODUCT_NAME)</string>
      <key>CFBundlePackageType</key>
      <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
      <key>CFBundleShortVersionString</key>
      <string>$(MARKETING_VERSION)</string>
      <key>CFBundleVersion</key>
      <string>$(CURRENT_PROJECT_VERSION)</string>
      <key>LSRequiresIPhoneOS</key>
      <true/>
      <key>MinimumOSVersion</key>
      <string>#{deployment_target}</string>
      <key>NSAppTransportSecurity</key>
      <dict>
          <key>NSAllowsArbitraryLoads</key>
          <true/>
      </dict>
      <key>UIApplicationSceneManifest</key>
      <dict>
          <key>UIApplicationSupportsMultipleScenes</key>
          <false/>
      </dict>
      <key>UILaunchScreen</key>
      <dict/>
      <key>UISupportedInterfaceOrientations</key>
      <array>
          <string>UIInterfaceOrientationPortrait</string>
          <string>UIInterfaceOrientationLandscapeLeft</string>
          <string>UIInterfaceOrientationLandscapeRight</string>
      </array>
  </dict>
  </plist>
  PLIST
)
RUBY

xcrun xcodebuild \
    -project "$PROJECT_DIR" \
    -scheme "$IOS_APP_NAME" \
    -configuration "$CONFIGURATION" \
    -destination "$IOS_DESTINATION" \
    -derivedDataPath "$IOS_DERIVED_DATA" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    build

BUILT_APP="$IOS_DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos/$IOS_APP_NAME.app"
if [ ! -d "$BUILT_APP" ]; then
    echo "Signed iOS app was not found at expected path: $BUILT_APP" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$(dirname "$APP_DIR")"
ditto "$BUILT_APP" "$APP_DIR"

echo "$APP_DIR"
