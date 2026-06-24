#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Silex.app"
CONTENTS="$APP/Contents"
ADHOC=false
SMARTCTL_SOURCE="${SMARTCTL_PATH:-$(command -v smartctl || true)}"

if [[ "${1:-}" == "--adhoc" ]]; then
  ADHOC=true
elif [[ $# -gt 0 ]]; then
  echo "usage: Scripts/build-app.sh [--adhoc]" >&2
  exit 64
fi

if [[ -z "$SMARTCTL_SOURCE" || ! -x "$SMARTCTL_SOURCE" ]]; then
  echo "smartctl was not found. Install it with: brew install smartmontools" >&2
  exit 69
fi
SMARTCTL_SOURCE="$(realpath "$SMARTCTL_SOURCE")"

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
  "$CONTENTS/Resources/zh-Hans.lproj" \
  "$CONTENTS/Library/LaunchDaemons" \
  "$CONTENTS/Library/PrivilegedHelperTools"

install -m 755 "$BIN_PATH/Silex" "$CONTENTS/MacOS/Silex"
install -m 755 \
  "$BIN_PATH/SilexSMARTService" \
  "$CONTENTS/Library/PrivilegedHelperTools/SilexSMARTService"
install -m 755 \
  "$SMARTCTL_SOURCE" \
  "$CONTENTS/Library/PrivilegedHelperTools/smartctl"
install -m 644 "$ROOT/Resources/App/Info.plist" "$CONTENTS/Info.plist"
install -m 644 \
  "$ROOT/Resources/LaunchDaemons/com.anon233.Silex.SMARTService.plist" \
  "$CONTENTS/Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist"
install -m 644 \
  "$ROOT/Sources/SilexApp/Resources/en.lproj/Localizable.strings" \
  "$CONTENTS/Resources/en.lproj/Localizable.strings"
install -m 644 \
  "$ROOT/Sources/SilexApp/Resources/zh-Hans.lproj/Localizable.strings" \
  "$CONTENTS/Resources/zh-Hans.lproj/Localizable.strings"

ICONSET="$DIST/AppIcon.iconset"
rm -rf "$ICONSET"
/usr/bin/swift "$ROOT/Scripts/generate-icon.swift" "$ICONSET"
/usr/bin/iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$ICONSET"

/usr/bin/plutil -lint "$CONTENTS/Info.plist"
/usr/bin/plutil -lint \
  "$CONTENTS/Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist"

if [[ "$ADHOC" == true ]]; then
  /usr/bin/codesign \
    --force \
    --sign - \
    --identifier com.anon233.Silex.smartctl \
    "$CONTENTS/Library/PrivilegedHelperTools/smartctl"
  /usr/bin/codesign \
    --force \
    --sign - \
    --identifier com.anon233.Silex.SMARTService \
    "$CONTENTS/Library/PrivilegedHelperTools/SilexSMARTService"
  /usr/bin/codesign \
    --force \
    --sign - \
    --entitlements "$ROOT/Resources/App/Silex.entitlements" \
    "$APP"
  /usr/bin/codesign --verify --deep --strict "$APP"
fi

echo "$APP"
