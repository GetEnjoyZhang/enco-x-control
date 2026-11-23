#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TEAM_ID:-}" ]]; then
  echo "用法: TEAM_ID=你的AppleTeamID ./build.sh"
  echo "例如: TEAM_ID=ABCDE12345 ./build.sh"
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 xcodegen，请先执行: brew install xcodegen"
  exit 1
fi

xcodegen generate
mkdir -p build
sed "s/TEAMID/${TEAM_ID}/g" ExportOptions.plist > build/ExportOptions.plist

xcodebuild -project EncoXControl.xcodeproj \
  -scheme EncoXControl \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  archive -archivePath build/EncoXControl.xcarchive

xcodebuild -exportArchive \
  -archivePath build/EncoXControl.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/ipa

echo "完成！IPA 位于: build/ipa/EncoXControl.ipa"
