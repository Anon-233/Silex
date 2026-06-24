#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
mkdir -p "$DIST"
WORK="$(mktemp -d "$DIST/installer-work.XXXXXX")"
PAYLOAD_ROOT="$WORK/root"
PACKAGE_SCRIPTS="$WORK/scripts"
COMPONENT_PACKAGE="$WORK/Silex-component.pkg"
COMPONENT_PLIST="$WORK/components.plist"
PRODUCT_PACKAGE=""
DISK_IMAGE=""
DMG_ROOT="$WORK/dmg-root"
HELPER_BUNDLE="$PAYLOAD_ROOT/Library/PrivilegedHelperTools/SilexSMARTService.app"
HELPER_CONTENTS="$PAYLOAD_ROOT/Library/PrivilegedHelperTools/SilexSMARTService.app/Contents"
HELPER_EXECUTABLE="$PAYLOAD_ROOT/Library/PrivilegedHelperTools/SilexSMARTService.app/Contents/MacOS/SilexSMARTService"
ALLOW_DOWNGRADE=0
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:--}"
INSTALLER_SIGN_IDENTITY="${INSTALLER_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SMARTCTL_SOURCE="${SMARTCTL_PATH:-$(command -v smartctl || true)}"

cleanup_work() {
  /bin/rm -rf "$WORK"
}
trap cleanup_work EXIT

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

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ "$APP_SIGN_IDENTITY" == "-" || -z "$INSTALLER_SIGN_IDENTITY" ]]; then
    echo "NOTARY_PROFILE requires both signing identities" >&2
    exit 64
  fi
fi

SMARTCTL_SOURCE="$(realpath "$SMARTCTL_SOURCE")"
PACKAGE_VERSION="$VERSION.$BUILD"
PRODUCT_PACKAGE="$DIST/Silex-$VERSION.pkg"
DISK_IMAGE="$DIST/Silex-$VERSION.dmg"

rm -f "$PRODUCT_PACKAGE" "$DISK_IMAGE"
mkdir -p \
  "$PAYLOAD_ROOT/Applications" \
  "$PAYLOAD_ROOT/Library/LaunchDaemons" \
  "$PAYLOAD_ROOT/Library/PrivilegedHelperTools" \
  "$HELPER_CONTENTS/MacOS" \
  "$HELPER_CONTENTS/Resources/en.lproj" \
  "$HELPER_CONTENTS/Resources/zh-Hans.lproj" \
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
/usr/bin/install -m 644 \
  "$ROOT/Resources/PrivilegedHelper/Info.plist" \
  "$HELPER_CONTENTS/Info.plist"
/usr/bin/install -m 644 \
  "$ROOT/Resources/PrivilegedHelper/en.lproj/InfoPlist.strings" \
  "$HELPER_CONTENTS/Resources/en.lproj/InfoPlist.strings"
/usr/bin/install -m 644 \
  "$ROOT/Resources/PrivilegedHelper/zh-Hans.lproj/InfoPlist.strings" \
  "$HELPER_CONTENTS/Resources/zh-Hans.lproj/InfoPlist.strings"
/usr/bin/install -m 755 \
  "$BIN_PATH/SilexSMARTService" \
  "$HELPER_EXECUTABLE"
/usr/bin/install -m 755 \
  "$SMARTCTL_SOURCE" \
  "$PAYLOAD_ROOT/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl"

/usr/bin/plutil -replace CFBundleShortVersionString \
  -string "$VERSION" "$HELPER_CONTENTS/Info.plist"
/usr/bin/plutil -replace CFBundleVersion \
  -string "$BUILD" "$HELPER_CONTENTS/Info.plist"

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
    "$HELPER_BUNDLE"
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
    "$HELPER_BUNDLE"
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
  --analyze \
  --root "$PAYLOAD_ROOT" \
  "$COMPONENT_PLIST"
COMPONENT_INDEX=0
while /usr/libexec/PlistBuddy \
  -c "Print :$COMPONENT_INDEX:RootRelativeBundlePath" \
  "$COMPONENT_PLIST" >/dev/null 2>&1
do
  /usr/bin/plutil \
    -replace "$COMPONENT_INDEX.BundleIsRelocatable" \
    -bool false \
    "$COMPONENT_PLIST"
  /usr/bin/plutil \
    -replace "$COMPONENT_INDEX.BundleIsVersionChecked" \
    -bool true \
    "$COMPONENT_PLIST"
  /usr/bin/plutil \
    -replace "$COMPONENT_INDEX.BundleHasStrictIdentifier" \
    -bool true \
    "$COMPONENT_PLIST"
  /usr/bin/plutil \
    -replace "$COMPONENT_INDEX.BundleOverwriteAction" \
    -string upgrade \
    "$COMPONENT_PLIST"
  COMPONENT_INDEX=$((COMPONENT_INDEX + 1))
done

/usr/bin/pkgbuild \
  --root "$PAYLOAD_ROOT" \
  --scripts "$PACKAGE_SCRIPTS" \
  --component-plist "$COMPONENT_PLIST" \
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

if [[ -n "$NOTARY_PROFILE" ]]; then
  /usr/bin/xcrun notarytool submit "$PRODUCT_PACKAGE" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  /usr/bin/xcrun stapler staple "$PRODUCT_PACKAGE"
  /usr/bin/xcrun stapler validate "$PRODUCT_PACKAGE"
fi

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

if [[ -n "$NOTARY_PROFILE" ]]; then
  /usr/bin/xcrun notarytool submit "$DISK_IMAGE" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  /usr/bin/xcrun stapler staple "$DISK_IMAGE"
  /usr/bin/xcrun stapler validate "$DISK_IMAGE"
fi

"$ROOT/Scripts/verify-installer.sh" "$VERSION"

echo "$PRODUCT_PACKAGE"
echo "$DISK_IMAGE"
