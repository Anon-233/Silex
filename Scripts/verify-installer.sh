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
PLIST="$PAYLOAD/Library/LaunchDaemons/com.anon233.Silex.Daemon.plist"
HELPER_BUNDLE="$PAYLOAD/Library/PrivilegedHelperTools/SilexDaemon.app"
HELPER="$HELPER_BUNDLE/Contents/MacOS/SilexDaemon"
HELPER_INFO="$HELPER_BUNDLE/Contents/Info.plist"
SMARTCTL="$PAYLOAD/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl"

for payload_path in \
  "$PAYLOAD_APP" \
  "$PLIST" \
  "$HELPER_BUNDLE" \
  "$HELPER" \
  "$HELPER_INFO" \
  "$SMARTCTL"
do
  if [[ ! -e "$payload_path" ]]; then
    echo "missing package payload: $payload_path" >&2
    exit 65
  fi
done

PAYLOAD_APP_COUNT=$(
  /usr/bin/find "$PAYLOAD/Applications" \
    -mindepth 1 -maxdepth 1 -type d -name 'Silex.app' -print |
    /usr/bin/wc -l |
    /usr/bin/tr -d ' '
)
PAYLOAD_HELPER_COUNT=$(
  /usr/bin/find "$PAYLOAD/Library/PrivilegedHelperTools" \
    -mindepth 1 -maxdepth 1 -type d -name 'SilexDaemon.app' -print |
    /usr/bin/wc -l |
    /usr/bin/tr -d ' '
)
if [[ "$PAYLOAD_APP_COUNT" != "1" || "$PAYLOAD_HELPER_COUNT" != "1" ]]; then
  echo "package must contain exactly one app and one helper bundle" >&2
  exit 65
fi
if [[ -e \
  "$PAYLOAD/Library/PrivilegedHelperTools/com.anon233.Silex.Daemon" \
]]; then
  echo "package contains obsolete bare helper" >&2
  exit 65
fi

if ! /usr/bin/grep -q 'identifier="com.anon233.Silex.pkg"' \
  "$COMPONENT/PackageInfo"
then
  echo "package receipt identifier is incorrect" >&2
  exit 65
fi

RELOCATABLE_BUNDLES=$(
  /usr/bin/xmllint --xpath \
    'count(/pkg-info/relocate/bundle)' \
    "$COMPONENT/PackageInfo"
)
if [[ "$RELOCATABLE_BUNDLES" != "0" ]]; then
  echo "application bundle must not be relocatable" >&2
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

/usr/bin/plutil -lint \
  "$PAYLOAD_APP/Contents/Info.plist" \
  "$HELPER_INFO" \
  "$PLIST"
if [[ "$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$HELPER_INFO"
)" != "com.anon233.Silex.Daemon" ]]; then
  echo "helper bundle identifier is incorrect" >&2
  exit 65
fi
if [[ "$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$HELPER_INFO"
)" != "Silex SMART Service" ]]; then
  echo "helper CFBundleDisplayName is incorrect" >&2
  exit 65
fi
for localized_info in \
  "$HELPER_BUNDLE/Contents/Resources/en.lproj/InfoPlist.strings" \
  "$HELPER_BUNDLE/Contents/Resources/zh-Hans.lproj/InfoPlist.strings"
do
  if [[ ! -f "$localized_info" ]]; then
    echo "missing helper localization: $localized_info" >&2
    exit 65
  fi
done
/usr/bin/codesign --verify --deep --strict "$PAYLOAD_APP"
/usr/bin/codesign --verify --deep --strict "$HELPER_BUNDLE"
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
