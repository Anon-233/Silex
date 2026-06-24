# Silex Design Specification

## Product goal

Silex is a macOS 26+ menu-bar utility for the built-in Apple SSD. It turns
`smartctl` output into persistent history, native trend charts, configurable
alerts, and safe simulated alert tests. It does not modify SSD state.

## Confirmed scope

- Native SwiftUI/AppKit application; no WebView.
- Built-in SSD only, default device `/dev/disk0`.
- No Dock icon. A menu-bar item is the normal entry point.
- Starts at login when enabled.
- Manual collection and configurable periodic collection, default 8 hours.
- Chinese and English localization. Default follows the system; settings can
  override the language.
- Store all parsed samples and the complete original `smartctl -j -x` JSON.
- Keep history indefinitely until the user exports or deletes it.
- Plot time-proportional charts for `24h`, `30d`, and `All`.
- `24h` and `30d` show sample points. `All` omits points to avoid clutter.
- A range containing one sample displays one point and no line.
- Clicking a metric card or a line isolates that series. Clicking it again or
  clicking chart whitespace restores all series.
- Rules are addable, removable, enableable, and testable with simulated values.
- Data and logs use standard macOS locations and are easy to remove.
- The repository excludes generated applications, build output, logs, and user
  Xcode state.

## Window and navigation

The main window defaults to 900 by 675 points and maintains a 4:3 aspect ratio
while resizing. It has a minimum size of 720 by 540 points.

The content is a horizontal card carousel:

1. Settings
2. Health overview
3. Read/write data
4. Temperature
5. Wear and spare capacity
6. Events and operating time

The content area supports trackpad horizontal swipe, arrow buttons, and a
bottom page indicator. The current page is a green elongated dot.

The accepted placeholder logo is a rounded square outline containing a smaller
filled rounded square. It is rendered as a native SwiftUI shape so it remains
sharp at every scale.

## Data presentation

### Overview

Shows SMART overall status, model, last collection time, temperature, available
spare, percentage used, total data read/written, power-on hours, and error
counts. `PASSED` and the localized status label share one baseline.

### Read/write

Two full-width cards show total data read and written. Secondary statistics are
recent per-hour change and full-history average per-hour change. The chart title
contains the unit, for example `Read and write data (TB)`.

### Temperature

One full-width card shows the latest value in `°C`, historical maximum, and
historical average.

### Wear and spare

Cards show:

- Available spare: latest, historical minimum, and distance to threshold.
- Percentage used: latest, historical maximum, and latest sample change.
- Spare threshold: latest threshold and its alert role.

### Events and operating time

Count-based chart series include power cycles, unsafe shutdowns, media/data
integrity errors, and error log entries. Power-on hours is displayed as a
separate summary statistic.

## Collection and privilege design

The installed Homebrew `smartctl` is discovered in this order:

1. A user-configured executable path.
2. `/opt/homebrew/bin/smartctl`
3. `/opt/homebrew/sbin/smartctl`
4. `/usr/local/bin/smartctl`
5. `/usr/local/sbin/smartctl`
6. `which smartctl`

The collection command is fixed:

```text
smartctl -j -x /dev/disk0
```

The build copies the selected Homebrew binary into
`Contents/Library/PrivilegedHelperTools/smartctl`. No arbitrary executable,
argument list, or output path is accepted by the privileged service. The root
daemon executes only this signed bundle sibling, never a user-owned Homebrew
path.

An unprivileged probe on the target machine returned exit status 2 with
`IOCreatePlugInInterfaceForService failed`, so Silex packages a restricted
LaunchDaemon. The app registers it with
`SMAppService.daemon(plistName:)`. Registration requires a code-signed,
notarized app and administrator approval in System Settings. The daemon exposes
one privileged XPC operation that returns the raw JSON and process exit status.
The user app parses and stores data.

The app itself is an `LSUIElement` menu-bar application and can register as a
login item with `SMAppService.mainApp`. While running in the menu bar it owns
the periodic timer and user notifications. Quitting Silex stops periodic
collection until the next login or manual launch.

## smartctl handling

Silex parses JSON even when `smartctl` returns a nonzero status because the
status is a bit mask and may describe drive health or partial command failures.
A collection is rejected only when the output cannot be decoded into the
required SMART structure.

The parser records:

- model, serial number, firmware, NVMe version;
- overall passed status and critical warning;
- temperature;
- available spare and spare threshold;
- percentage used;
- data units read and written, normalized to bytes;
- host read/write commands;
- controller busy time;
- power cycles, power-on hours, unsafe shutdowns;
- media/data integrity errors and error log entries;
- raw JSON, collection source, timestamp, and smartctl exit status.

## Persistence

All persistent data lives under:

```text
~/Library/Application Support/Silex/
```

The SQLite database is:

```text
~/Library/Application Support/Silex/silex.sqlite3
```

SQLite stores samples, raw JSON, and rules transactionally. Settings that must
be read by both the app and helper are stored in the same database. System
diagnostics use unified logging with subsystem `com.anon233.Silex`.

The settings page provides `Show in Finder`, JSON/CSV export, and history
deletion. Silex does not allow moving the storage directory.

## Rules

A rule contains:

- metric;
- aggregation (`current`, `increase`, `rate per hour`, `average`, `minimum`,
  or `maximum`);
- time window in hours;
- comparison (`>`, `>=`, `<`, or `<=`);
- numeric threshold;
- cooldown in hours;
- enabled state;
- last-triggered timestamp.

Units and valid aggregations are derived from the selected metric. Users enter
numbers only. Rules are evaluated after every successful sample. Cooldown
prevents duplicate notifications.

The rule editor is a custom overlay rather than a separate window. Clicking
outside the editor closes it; interacting with the editor does not.

`Test` evaluates a simulated value and posts the same local notification path
as a real rule without running `smartctl`, writing a fake sample, or changing
SSD state.

## Notifications and errors

Silex requests notification permission when the user first enables alerts or
tests a rule. Notifications include the rule name, observed value, threshold,
and window.

Errors are shown in the menu and main window with an actionable category:

- `smartctl` missing;
- privileged service not registered;
- service awaiting System Settings approval;
- device access failure;
- malformed JSON;
- database failure;
- notification permission denied.

The settings page has a smartctl installation sheet. It displays
`brew install smartmontools`, streams stdout/stderr into a terminal-style view,
and requires an explicit Run action. The app never installs on launch.

## Testing

Automated tests cover:

- representative Apple NVMe JSON parsing;
- nonzero smartctl exit status with valid JSON;
- SQLite migrations and round trips;
- time-range filtering including zero and one sample;
- real-time delta/rate calculations with irregular manual samples;
- all rule aggregation/comparison/cooldown paths;
- launchd plist and app bundle packaging;
- restricted service request validation;
- localization key parity.

The current machine has Swift 6.3.2 and the macOS 26 SDK through Command Line
Tools but no full Xcode. The bundled Swift Testing runner does not register
macro tests, so `SilexTestRunner` provides deterministic executable regression
tests. The test runner, `swift build`, package assembly, plist validation, and
ad-hoc signing can be verified. App notarization, System
Settings approval, privileged daemon registration, and GUI interaction require
full Xcode/signing credentials and are intentionally not performed during this
development run.
