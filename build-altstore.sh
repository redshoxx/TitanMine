#!/bin/bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen fehlt. Installiere es mit: brew install xcodegen"
  exit 1
fi

rm -rf build Payload TitanMine-AltStore.ipa TitanMine.xcodeproj
xcodegen generate

xcodebuild \
  -project TitanMine.xcodeproj \
  -scheme TitanMine \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  build

mkdir -p Payload
cp -R build/Build/Products/Release-iphoneos/TitanMine.app Payload/TitanMine.app
/usr/bin/zip -qry TitanMine-AltStore.ipa Payload

echo "Fertig: TitanMine-AltStore.ipa"
