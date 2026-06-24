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
- A signed and notarized app in `/Applications` for real
  `SMAppService` LaunchDaemon registration.

The target Mac requires privileged access for its built-in SSD. An unprivileged
probe returns smartctl exit status 2 with
`IOCreatePlugInInterfaceForService failed`.

For privilege safety, the root helper never executes the user-owned Homebrew
path. `Scripts/build-app.sh` copies the selected `smartctl` binary into the
signed app bundle, and the helper executes only that fixed sibling executable.
Set `SMARTCTL_PATH=/path/to/smartctl` while building to choose a source path.

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

Create and ad-hoc sign `dist/Silex.app` without installing it:

```bash
Scripts/build-app.sh --adhoc
```

Generated build output and app bundles are excluded by `.gitignore`.

Ad-hoc signing verifies package structure only. Registering the privileged
LaunchDaemon requires a Developer ID signed and notarized build. Silex never
registers or installs the service during tests.

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
- `Sources/SilexSMARTService`: restricted privileged Mach service.
- `Resources`: app metadata and LaunchDaemon plist.
- `Scripts`: deterministic icon and `.app` assembly.
- `Tests/SilexTestRunner`: executable regression suite.
- `docs/superpowers`: approved specification and implementation plan.
