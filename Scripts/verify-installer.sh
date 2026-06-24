#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"

if [[ $# -ne 1 ]]; then
  echo "usage: Scripts/verify-installer.sh VERSION" >&2
  exit 64
fi

VERSION="$1"
if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  echo "VERSION must use numeric X.Y.Z form" >&2
  exit 64
fi

APP="$DIST/Silex.app"
PKG="$DIST/Silex-$VERSION.pkg"
DMG="$DIST/Silex-$VERSION.dmg"
TEMP_ROOT="$(mktemp -d /tmp/silex-verify.XXXXXX)"
EXPANDED="$TEMP_ROOT/expanded"
MOUNT_POINT="$TEMP_ROOT/mount"
ATTACHED=0

cleanup() {
  if [[ "$ATTACHED" -eq 1 ]]; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
  fi
  /bin/rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

for artifact in "$APP" "$PKG" "$DMG"; do
  if [[ ! -e "$artifact" ]]; then
    echo "missing artifact: $artifact" >&2
    exit 66
  fi
done

/usr/bin/codesign --verify --deep --strict "$APP"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"

/usr/sbin/pkgutil --expand-full "$PKG" "$EXPANDED"
COMPONENT="$EXPANDED/Silex-component.pkg"
PAYLOAD="$COMPONENT/Payload"
PAYLOAD_APP="$PAYLOAD/Applications/Silex.app"
PLIST="$PAYLOAD/Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist"
HELPER="$PAYLOAD/Library/PrivilegedHelperTools/com.anon233.Silex.SMARTService"
SMARTCTL="$PAYLOAD/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl"

for payload_path in "$PAYLOAD_APP" "$PLIST" "$HELPER" "$SMARTCTL"; do
  if [[ ! -e "$payload_path" ]]; then
    echo "missing package payload: $payload_path" >&2
    exit 65
  fi
done

if ! /usr/bin/grep -q 'identifier="com.anon233.Silex.pkg"' \
  "$COMPONENT/PackageInfo"
then
  echo "package receipt identifier is incorrect" >&2
  exit 65
fi

if /usr/bin/find "$PAYLOAD" -path '*Application Support*' -print -quit |
  /usr/bin/grep -q .
then
  echo "package must not contain user application data" >&2
  exit 65
fi

if [[ "$(/usr/bin/stat -f '%Lp' "$PLIST")" != "644" ]]; then
  echo "LaunchDaemon plist mode is not 644" >&2
  exit 65
fi
for executable in "$HELPER" "$SMARTCTL"; do
  if [[ "$(/usr/bin/stat -f '%Lp' "$executable")" != "755" ]]; then
    echo "privileged executable mode is not 755: $executable" >&2
    exit 65
  fi
done

/usr/bin/plutil -lint "$PAYLOAD_APP/Contents/Info.plist" "$PLIST"
/usr/bin/codesign --verify --deep --strict "$PAYLOAD_APP"
/usr/bin/codesign --verify --strict "$HELPER"
/usr/bin/codesign --verify --strict "$SMARTCTL"

for binary in \
  "$PAYLOAD_APP/Contents/MacOS/Silex" \
  "$HELPER" \
  "$SMARTCTL"
do
  DEPENDENCIES="$(/usr/bin/otool -L "$binary")"
  for forbidden_framework in \
    "Network.framework" \
    "CFNetwork.framework" \
    "WebKit.framework"
  do
    if echo "$DEPENDENCIES" |
      /usr/bin/grep -F "$forbidden_framework"
    then
      echo "network framework dependency found in $binary" >&2
      exit 65
    fi
  done
done

ENTITLEMENTS="$TEMP_ROOT/entitlements.plist"
/usr/bin/codesign -d --entitlements :- "$PAYLOAD_APP" \
  > "$ENTITLEMENTS" 2>/dev/null
if /usr/bin/grep -Eiq \
  'com\.apple\.security\.network|network\.client|network\.server' \
  "$ENTITLEMENTS"
then
  echo "network entitlement found" >&2
  exit 65
fi

/usr/bin/hdiutil verify "$DMG"
/bin/mkdir "$MOUNT_POINT"
/usr/bin/hdiutil attach \
  -readonly \
  -nobrowse \
  -mountpoint "$MOUNT_POINT" \
  "$DMG" >/dev/null
ATTACHED=1

EXPECTED_CONTENTS=$'Install Silex.pkg\nREADME.txt\nUninstall Silex.app'
ACTUAL_CONTENTS=$(
  /usr/bin/find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 -print |
    /usr/bin/sed 's#^.*/##' |
    /usr/bin/sort
)
if [[ "$ACTUAL_CONTENTS" != "$EXPECTED_CONTENTS" ]]; then
  echo "unexpected DMG contents:" >&2
  echo "$ACTUAL_CONTENTS" >&2
  exit 65
fi

/usr/bin/codesign --verify --deep --strict \
  "$MOUNT_POINT/Uninstall Silex.app"

echo "Verified $PKG"
echo "Verified $DMG"
