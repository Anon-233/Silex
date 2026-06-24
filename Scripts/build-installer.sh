#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
WORK="$DIST/installer-work"
PAYLOAD_ROOT="$WORK/root"
PACKAGE_SCRIPTS="$WORK/scripts"
COMPONENT_PACKAGE="$WORK/Silex-component.pkg"
PRODUCT_PACKAGE=""
DISK_IMAGE=""
DMG_ROOT="$WORK/dmg-root"
ALLOW_DOWNGRADE=0
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:--}"
INSTALLER_SIGN_IDENTITY="${INSTALLER_SIGN_IDENTITY:-}"
SMARTCTL_SOURCE="${SMARTCTL_PATH:-$(command -v smartctl || true)}"

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: Scripts/build-installer.sh VERSION BUILD [--allow-downgrade]" >&2
  exit 64
fi

VERSION="$1"
BUILD="$2"
if [[ $# -eq 3 ]]; then
  if [[ "$3" != "--allow-downgrade" ]]; then
    echo "unknown option: $3" >&2
    exit 64
  fi
  ALLOW_DOWNGRADE=1
fi

if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  echo "VERSION must use numeric X.Y.Z form" >&2
  exit 64
fi

if [[ ! "$BUILD" =~ '^[1-9][0-9]*$' ]]; then
  echo "BUILD must be a positive integer" >&2
  exit 64
fi

if [[ -z "$SMARTCTL_SOURCE" || ! -x "$SMARTCTL_SOURCE" ]]; then
  echo "smartctl was not found; set SMARTCTL_PATH to an executable" >&2
  exit 69
fi

SMARTCTL_SOURCE="$(realpath "$SMARTCTL_SOURCE")"
PACKAGE_VERSION="$VERSION.$BUILD"
PRODUCT_PACKAGE="$DIST/Silex-$VERSION.pkg"
DISK_IMAGE="$DIST/Silex-$VERSION.dmg"

rm -rf "$WORK"
rm -f "$PRODUCT_PACKAGE" "$DISK_IMAGE"
mkdir -p \
  "$PAYLOAD_ROOT/Applications" \
  "$PAYLOAD_ROOT/Library/LaunchDaemons" \
  "$PAYLOAD_ROOT/Library/PrivilegedHelperTools" \
  "$PACKAGE_SCRIPTS"

if [[ "$APP_SIGN_IDENTITY" == "-" ]]; then
  env \
    SILEX_VERSION="$VERSION" \
    SILEX_BUILD="$BUILD" \
    APP_SIGN_IDENTITY="-" \
    "$ROOT/Scripts/build-app.sh" --adhoc
else
  env \
    SILEX_VERSION="$VERSION" \
    SILEX_BUILD="$BUILD" \
    APP_SIGN_IDENTITY="$APP_SIGN_IDENTITY" \
    "$ROOT/Scripts/build-app.sh"
fi

BIN_PATH="$(swift build \
  --package-path "$ROOT" \
  --configuration release \
  --disable-sandbox \
  --show-bin-path)"

/usr/bin/ditto \
  "$DIST/Silex.app" \
  "$PAYLOAD_ROOT/Applications/Silex.app"
/usr/bin/install -m 644 \
  "$ROOT/Resources/LaunchDaemons/com.anon233.Silex.SMARTService.plist" \
  "$PAYLOAD_ROOT/Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist"
/usr/bin/install -m 755 \
  "$BIN_PATH/SilexSMARTService" \
  "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/com.anon233.Silex.SMARTService"
/usr/bin/install -m 755 \
  "$SMARTCTL_SOURCE" \
  "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl"

if [[ "$APP_SIGN_IDENTITY" == "-" ]]; then
  /usr/bin/codesign \
    --force \
    --sign - \
    --identifier com.anon233.Silex.smartctl \
    "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl"
  /usr/bin/codesign \
    --force \
    --sign - \
    --identifier com.anon233.Silex.SMARTService \
    "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/com.anon233.Silex.SMARTService"
else
  /usr/bin/codesign \
    --force \
    --sign "$APP_SIGN_IDENTITY" \
    --options runtime \
    --timestamp \
    "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl"
  /usr/bin/codesign \
    --force \
    --sign "$APP_SIGN_IDENTITY" \
    --options runtime \
    --timestamp \
    "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/com.anon233.Silex.SMARTService"
fi

/usr/bin/sed \
  -e "s/@SILEX_VERSION@/$VERSION/g" \
  -e "s/@SILEX_BUILD@/$BUILD/g" \
  -e "s/@ALLOW_DOWNGRADE@/$ALLOW_DOWNGRADE/g" \
  "$ROOT/Packaging/Scripts/preinstall.in" \
  > "$PACKAGE_SCRIPTS/preinstall"
/bin/cp \
  "$ROOT/Packaging/Scripts/version-compare.sh" \
  "$PACKAGE_SCRIPTS/version-compare.sh"
/bin/cp \
  "$ROOT/Packaging/Scripts/postinstall" \
  "$PACKAGE_SCRIPTS/postinstall"
/bin/chmod 755 \
  "$PACKAGE_SCRIPTS/preinstall" \
  "$PACKAGE_SCRIPTS/version-compare.sh" \
  "$PACKAGE_SCRIPTS/postinstall"

/usr/bin/sed \
  -e "s/@PACKAGE_VERSION@/$PACKAGE_VERSION/g" \
  "$ROOT/Packaging/Distribution.xml.in" \
  > "$WORK/Distribution.xml"

/usr/bin/pkgbuild \
  --root "$PAYLOAD_ROOT" \
  --scripts "$PACKAGE_SCRIPTS" \
  --identifier com.anon233.Silex.pkg \
  --version "$PACKAGE_VERSION" \
  --ownership recommended \
  "$COMPONENT_PACKAGE"

PRODUCT_ARGUMENTS=(
  --distribution "$WORK/Distribution.xml"
  --package-path "$WORK"
)
if [[ -n "$INSTALLER_SIGN_IDENTITY" ]]; then
  PRODUCT_ARGUMENTS+=(--sign "$INSTALLER_SIGN_IDENTITY")
fi

/usr/bin/productbuild \
  "${PRODUCT_ARGUMENTS[@]}" \
  "$PRODUCT_PACKAGE"

mkdir -p "$DMG_ROOT"
/bin/cp "$PRODUCT_PACKAGE" "$DMG_ROOT/Install Silex.pkg"
/bin/cp "$ROOT/Packaging/README.txt" "$DMG_ROOT/README.txt"
/usr/bin/osacompile \
  -o "$DMG_ROOT/Uninstall Silex.app" \
  "$ROOT/Packaging/Uninstall Silex.applescript"

if [[ "$APP_SIGN_IDENTITY" == "-" ]]; then
  /usr/bin/codesign \
    --force \
    --sign - \
    "$DMG_ROOT/Uninstall Silex.app"
else
  /usr/bin/codesign \
    --force \
    --sign "$APP_SIGN_IDENTITY" \
    --options runtime \
    --timestamp \
    "$DMG_ROOT/Uninstall Silex.app"
fi

/usr/bin/hdiutil create \
  -ov \
  -format UDZO \
  -volname "Silex $VERSION" \
  -srcfolder "$DMG_ROOT" \
  "$DISK_IMAGE"

echo "$PRODUCT_PACKAGE"
echo "$DISK_IMAGE"
