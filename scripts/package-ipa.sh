#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP_PATH=build/DerivedData/Build/Products/Release-iphoneos/Teleprompter.app
if [[ ! -d "$APP_PATH" ]]; then
  echo "No iPhone app bundle was built. Inspect build/build.log."
  exit 1
fi
PLATFORM=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$APP_PATH/Info.plist")
[[ "$PLATFORM" == "iPhoneOS" ]] || { echo "Refusing to package a simulator app."; exit 1; }
EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist")
lipo "$APP_PATH/$EXECUTABLE" -verify_arch arm64
mkdir -p dist
rm -rf dist/Payload
rm -f dist/Teleprompter.ipa
mkdir -p dist/Payload
ditto "$APP_PATH" dist/Payload/Teleprompter.app
(
  cd dist
  zip -qry Teleprompter.ipa Payload
)
python3 scripts/verify_ipa.py dist/Teleprompter.ipa
