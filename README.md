# Silex

Silex is a native macOS 26+ menu-bar utility for recording and visualizing the
SMART history of the built-in Apple SSD.

## Features

- Native SwiftUI/AppKit interface with no Dock icon.
- Menu-bar status and a resizable 4:3 history window.
- Manual and periodic collection through `smartctl -j -x /dev/disk0`.
- SQLite history containing parsed metrics and complete raw JSON.
- `24h`, `30d`, and `All` time ranges with single-point support.
- Metric-card and direct-chart series isolation.
- Configurable alert rules with safe simulated notification tests.
- English and Simplified Chinese UI.
- JSON/CSV export and standard Application Support storage.
- Restricted privileged daemon: callers cannot supply commands, arguments,
  devices, or output paths.

## Requirements

- macOS 26 or later.
- Apple Swift 6.3 toolchain.
- `smartmontools` installed through Homebrew when building the app bundle.

The target Mac does not need Homebrew or a separately installed `smartctl`.
The verified installer contains its own root-owned copy.

The target Mac requires privileged access for its built-in SSD. An unprivileged
probe returns smartctl exit status 2 with
`IOCreatePlugInInterfaceForService failed`.

For privilege safety, the root helper never executes the user-owned Homebrew
path. `Scripts/build-installer.sh` copies the selected `smartctl` binary into
the fixed package payload path
`/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl`. The helper executes
only that fixed packaged executable. Set `SMARTCTL_PATH=/path/to/smartctl` while
building to choose a source path.

## Tests

The installed Command Line Tools build does not register Swift Testing macros
with its bundled runner, so this repository uses a deterministic executable
test harness:

```bash
swift run --disable-sandbox SilexTestRunner
```

It prints every PASS/FAIL result and exits nonzero on failure.

Compile all targets:

```bash
swift build --disable-sandbox
```

## Build a local app bundle

Create and ad-hoc sign a local `Silex.app` for testing (placed in `dist/`):

```bash
SILEX_VERSION=1.0.1 SILEX_BUILD=3 zsh Scripts/build-app.sh --adhoc
```

## Build the personal installer

Build version `1.0.1`, build number `3`:

```bash
Scripts/build-installer.sh 1.0.1 3
```

The command generates and verifies:

```text
dist/Silex-1.0.1.dmg
```

Building does not install the package, request administrator privileges, or
load the daemon. Open the DMG and double-click `Install Silex.pkg` to install.
macOS Installer controls authentication. It may offer Touch ID when available,
but macOS can require the administrator password.

The package always uses:

```text
/Applications/Silex.app
com.anon233.Silex.pkg
```

Installing a package with a newer version updates the existing application and
daemon in place. It does not create another copy. The default package
rejects accidental downgrades. Uninstalling removes all data.

Generated build output, applications, packages, and disk images are excluded
by `.gitignore`.

## Daemon visibility and control

The package installs the on-demand daemon
`com.anon233.Silex.Daemon`. It exits after 30 idle seconds and is not an
always-running process. Its privileged helper is packaged with the localized
display name `Silex Daemon` (`Silex 后台服务` in Simplified
Chinese), while the internal launchd and Mach service identifier remains
stable for in-place updates.

View or disable it in:

```text
System Settings > General > Login Items & Extensions > Background Items
```

Inspect its launchd state:

```bash
launchctl print system/com.anon233.Silex.Daemon
```

Use Console.app and filter for subsystem `com.anon233.Silex` to inspect logs.
Disabling the daemon stops new collection; the app can still display existing
history. Package updates do not call `launchctl enable`, so they do not
deliberately override a disabled background-item preference.

The DMG includes `Uninstall Silex.app`. It removes the app, package receipt,
daemon, helper, packaged smartctl, and all user data after administrator
authorization.

## Offline and permissions

Silex is offline at runtime. It has no update check, download, telemetry,
analytics upload, crash upload, GitHub API, WebView, or other network feature.
The build verifies that application binaries do not link Network.framework,
CFNetwork.framework, or WebKit.framework and that no network entitlement is
present.

Silex does not request Full Disk Access, Accessibility, Location, Camera,
Microphone, Contacts, Calendar, Bluetooth, or Screen Recording. Its expected
approvals are limited to:

- administrator authorization while installing, updating, or uninstalling;
- notification authorization when an alert needs to notify the user;
- optional launch-at-login registration controlled in settings;
- root access by the fixed SMART daemon to read `/dev/disk0`.

## Optional Developer ID distribution

The default personal build uses ad-hoc application signatures and an unsigned
PKG. Gatekeeper may require explicit approval. With Apple Developer
certificates, use Developer ID signing:

```bash
APP_SIGN_IDENTITY="Developer ID Application: Example" \
INSTALLER_SIGN_IDENTITY="Developer ID Installer: Example" \
Scripts/build-installer.sh 1.0.1 3
```

To notarize, first store credentials in a Keychain profile, then add:

```bash
NOTARY_PROFILE="silex-notary"
```

When `NOTARY_PROFILE` is set, both signing identities are required. The build
uses only the profile name and does not accept plaintext Apple credentials.

## Data locations

Persistent data:

```text
~/Library/Application Support/Silex/silex.sqlite3
```

System diagnostics use unified logging with subsystem:

```text
com.anon233.Silex
```

The settings page can reveal the storage directory, export history, or delete
history. Silex does not move data to arbitrary folders.

## Repository structure

- `Sources/SilexCore`: parser, SQLite, analytics, alerts, scheduling, XPC client.
- `Sources/SilexApp`: menu-bar app, Swift Charts UI, localization.
- `Sources/SilexDaemon`: restricted privileged Mach service.
- `Resources`: app metadata and LaunchDaemon plist.
- `Scripts`: deterministic icon and `.app` assembly.
- `Tests/SilexTestRunner`: executable regression suite.
- `docs/superpowers`: approved specification and implementation plan.
