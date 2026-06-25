#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Silex.app"
CONTENTS="$APP/Contents"
SILEX_VERSION="${SILEX_VERSION:-1.0.1}"
SILEX_BUILD="${SILEX_BUILD:-3}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:--}"

if [[ "${1:-}" == "--adhoc" ]]; then
  APP_SIGN_IDENTITY="-"
elif [[ $# -gt 0 ]]; then
  echo "usage: Scripts/build-app.sh [--adhoc]" >&2
  exit 64
fi

if [[ ! "$SILEX_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  echo "SILEX_VERSION must use numeric X.Y.Z form" >&2
  exit 64
fi

if [[ ! "$SILEX_BUILD" =~ '^[1-9][0-9]*$' ]]; then
  echo "SILEX_BUILD must be a positive integer" >&2
  exit 64
fi

swift build \
  --package-path "$ROOT" \
  --configuration release \
  --disable-sandbox

BIN_PATH="$(swift build \
  --package-path "$ROOT" \
  --configuration release \
  --disable-sandbox \
  --show-bin-path)"

rm -rf "$APP"
mkdir -p \
  "$CONTENTS/MacOS" \
  "$CONTENTS/Resources/en.lproj" \
  "$CONTENTS/Resources/zh-Hans.lproj"

install -m 755 "$BIN_PATH/Silex" "$CONTENTS/MacOS/Silex"
install -m 644 "$ROOT/Resources/App/Info.plist" "$CONTENTS/Info.plist"
install -m 644 \
  "$ROOT/Sources/SilexApp/Resources/en.lproj/Localizable.strings" \
  "$CONTENTS/Resources/en.lproj/Localizable.strings"
install -m 644 \
  "$ROOT/Sources/SilexApp/Resources/zh-Hans.lproj/Localizable.strings" \
  "$CONTENTS/Resources/zh-Hans.lproj/Localizable.strings"

/usr/bin/plutil -replace CFBundleShortVersionString \
  -string "$SILEX_VERSION" "$CONTENTS/Info.plist"
/usr/bin/plutil -replace CFBundleVersion \
  -string "$SILEX_BUILD" "$CONTENTS/Info.plist"
/usr/bin/plutil -replace SilexBuildDate \
  -string "$(date '+%Y-%m-%d %H:%M %Z')" "$CONTENTS/Info.plist"


ICONSET="$DIST/AppIcon.iconset"
rm -rf "$ICONSET"
/usr/bin/swift "$ROOT/Scripts/generate-icon.swift" "$ICONSET"
/usr/bin/iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$ICONSET"

/usr/bin/plutil -lint "$CONTENTS/Info.plist"

if [[ "$APP_SIGN_IDENTITY" == "-" ]]; then
  /usr/bin/codesign \
    --force \
    --sign - \
    --entitlements "$ROOT/Resources/App/Silex.entitlements" \
    "$APP"
else
  /usr/bin/codesign \
    --force \
    --sign "$APP_SIGN_IDENTITY" \
    --options runtime \
    --timestamp \
    --entitlements "$ROOT/Resources/App/Silex.entitlements" \
    "$APP"
fi

/usr/bin/codesign --verify --deep --strict "$APP"

echo "$APP"
