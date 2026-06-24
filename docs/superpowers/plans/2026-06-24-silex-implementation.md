# Silex Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and test the first complete macOS 26 Silex menu-bar application, restricted SMART service, persistence layer, alerts, native charts, localization, and app-bundle packaging.

**Architecture:** A Swift package contains a testable `SilexCore` library, a SwiftUI menu-bar executable, and a restricted privileged service executable. SQLite persists samples and rules. The app registers the service through ServiceManagement, performs scheduling and notifications, and renders history through Swift Charts.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit, Charts, ServiceManagement, UserNotifications, Foundation XPC, SQLite3, XCTest.

---

### Task 1: Package skeleton and SMART domain model

**Files:**
- Create: `Package.swift`
- Create: `Sources/CSQLite/module.modulemap`
- Create: `Sources/SilexCore/Models.swift`
- Create: `Sources/SilexCore/SmartctlParser.swift`
- Create: `Tests/SilexCoreTests/Fixtures/apple-nvme.json`
- Create: `Tests/SilexCoreTests/SmartctlParserTests.swift`

- [ ] **Step 1: Write the failing parser tests**

Test decoding of model, health, temperature, percentages, byte counters, event
counters, raw JSON, and exit status. Add a second case proving valid SMART data
is accepted when the exit status is nonzero.

- [ ] **Step 2: Verify the parser tests fail**

Run:

```bash
swift test --filter SmartctlParserTests
```

Expected: compilation fails because `SmartctlParser` and `DriveSample` do not
exist.

- [ ] **Step 3: Implement the minimal model and parser**

Use explicit `CodingKeys` matching smartctl JSON. Convert NVMe data units using
the JSON byte value when present and otherwise use `raw * 512_000`.

- [ ] **Step 4: Verify parser tests pass**

Run:

```bash
swift test --filter SmartctlParserTests
```

Expected: all parser tests pass.

### Task 2: SQLite sample and rule persistence

**Files:**
- Create: `Sources/SilexCore/Database.swift`
- Create: `Sources/SilexCore/SampleRepository.swift`
- Create: `Sources/SilexCore/RuleRepository.swift`
- Create: `Tests/SilexCoreTests/DatabaseTests.swift`

- [ ] **Step 1: Write failing database tests**

Cover schema creation, sample round trip, date-ordered queries, rule CRUD,
settings round trip, export reads, and deletion.

- [ ] **Step 2: Verify the database tests fail**

Run:

```bash
swift test --filter DatabaseTests
```

Expected: compilation fails because the database types do not exist.

- [ ] **Step 3: Implement the SQLite wrapper and repositories**

Use prepared statements, bound parameters, transactions, WAL mode, foreign
keys, and a migration table. Store the complete raw JSON in the samples table.

- [ ] **Step 4: Verify database tests pass**

Run:

```bash
swift test --filter DatabaseTests
```

Expected: all database tests pass.

### Task 3: History calculations and alert engine

**Files:**
- Create: `Sources/SilexCore/Metrics.swift`
- Create: `Sources/SilexCore/HistoryAnalyzer.swift`
- Create: `Sources/SilexCore/AlertEngine.swift`
- Create: `Tests/SilexCoreTests/HistoryAnalyzerTests.swift`
- Create: `Tests/SilexCoreTests/AlertEngineTests.swift`

- [ ] **Step 1: Write failing time-window and rate tests**

Use irregular sample times to prove `24h` and `30d` filter by timestamp, one
sample remains visible, and rates use the real elapsed hours.

- [ ] **Step 2: Run the analyzer tests and confirm RED**

Run:

```bash
swift test --filter HistoryAnalyzerTests
```

Expected: compilation fails because `HistoryAnalyzer` does not exist.

- [ ] **Step 3: Implement the minimal analyzer**

Return filtered samples, latest values, historical min/max/average, sample
deltas, and per-hour rates without assuming a fixed collection interval.

- [ ] **Step 4: Write and run failing alert tests**

Cover every aggregation, comparison, cooldown suppression, disabled rules, and
simulated trigger output.

- [ ] **Step 5: Implement the alert engine and verify GREEN**

Run:

```bash
swift test --filter HistoryAnalyzerTests
swift test --filter AlertEngineTests
```

Expected: both suites pass.

### Task 4: smartctl execution and restricted service contract

**Files:**
- Create: `Sources/SilexCore/SmartctlLocator.swift`
- Create: `Sources/SilexCore/SmartctlRunner.swift`
- Create: `Sources/SilexCore/SMARTServiceProtocol.swift`
- Create: `Sources/SilexCore/SMARTServiceClient.swift`
- Create: `Tests/SilexCoreTests/SmartctlRunnerTests.swift`
- Create: `Tests/SilexCoreTests/SMARTServiceContractTests.swift`

- [ ] **Step 1: Write failing locator, runner, and validation tests**

Use temporary executable fixtures. Prove the runner always uses
`-j -x /dev/disk0`, captures stdout/stderr/status, and rejects a non-allowlisted
device or executable request.

- [ ] **Step 2: Confirm RED**

Run:

```bash
swift test --filter SmartctlRunnerTests
swift test --filter SMARTServiceContractTests
```

Expected: compilation fails because the runner and service contract do not
exist.

- [ ] **Step 3: Implement process execution and XPC-compatible result types**

The privileged interface accepts only `collectBuiltInDrive(reply:)`. It does
not accept shell text, arbitrary arguments, or output paths.

- [ ] **Step 4: Verify GREEN**

Run the same two filtered suites and expect all tests to pass.

### Task 5: Privileged daemon and ServiceManagement control

**Files:**
- Create: `Sources/SilexSMARTService/main.swift`
- Create: `Sources/SilexSMARTService/SMARTService.swift`
- Create: `Sources/SilexCore/ServiceController.swift`
- Create: `Resources/LaunchDaemons/com.anon233.Silex.SMARTService.plist`
- Create: `Tests/SilexCoreTests/ServiceControllerTests.swift`
- Create: `Tests/SilexCoreTests/PlistTests.swift`

- [ ] **Step 1: Write failing service status and plist tests**

Verify status mapping for not registered, enabled, requires approval, and not
found. Validate plist label, Mach service, root user, `BundleProgram`, and
on-demand behavior.

- [ ] **Step 2: Confirm RED**

Run:

```bash
swift test --filter ServiceControllerTests
swift test --filter PlistTests
```

- [ ] **Step 3: Implement the daemon listener and controller**

The listener checks the connection effective UID, exports the fixed protocol,
runs smartctl, and replies with JSON/status. The app controller wraps
`SMAppService.daemon(plistName:)` and never registers during tests.

- [ ] **Step 4: Verify GREEN**

Run the same filtered suites and expect all tests to pass.

### Task 6: Application model, scheduler, notifications, import/export

**Files:**
- Create: `Sources/SilexCore/CollectionCoordinator.swift`
- Create: `Sources/SilexCore/CollectionScheduler.swift`
- Create: `Sources/SilexCore/NotificationClient.swift`
- Create: `Sources/SilexCore/Exporter.swift`
- Create: `Tests/SilexCoreTests/CollectionCoordinatorTests.swift`
- Create: `Tests/SilexCoreTests/SchedulerTests.swift`
- Create: `Tests/SilexCoreTests/ExporterTests.swift`

- [ ] **Step 1: Write failing coordinator and scheduler tests**

Prove manual/scheduled sources share one pipeline, collection persists before
rule evaluation, due-date calculation uses the configured interval, and no
second timer fires after cancellation.

- [ ] **Step 2: Confirm RED**

Run:

```bash
swift test --filter CollectionCoordinatorTests
swift test --filter SchedulerTests
```

- [ ] **Step 3: Implement coordinator, scheduler, notification abstraction**

Keep system APIs behind protocols so tests use deterministic fakes. Simulated
alerts call the notification path without inserting samples.

- [ ] **Step 4: Add failing export tests and implementation**

Export complete JSON and a stable CSV column set. Verify with:

```bash
swift test --filter ExporterTests
```

### Task 7: Native menu-bar UI and localization

**Files:**
- Create: `Sources/SilexApp/SilexApp.swift`
- Create: `Sources/SilexApp/AppDelegate.swift`
- Create: `Sources/SilexApp/AppModel.swift`
- Create: `Sources/SilexApp/Views/AppMark.swift`
- Create: `Sources/SilexApp/Views/MainWindowView.swift`
- Create: `Sources/SilexApp/Views/OverviewView.swift`
- Create: `Sources/SilexApp/Views/TrendPageView.swift`
- Create: `Sources/SilexApp/Views/MetricCard.swift`
- Create: `Sources/SilexApp/Views/RuleOverlay.swift`
- Create: `Sources/SilexApp/Views/SettingsView.swift`
- Create: `Sources/SilexApp/Views/InstallSheet.swift`
- Create: `Sources/SilexApp/Resources/en.lproj/Localizable.strings`
- Create: `Sources/SilexApp/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `Tests/SilexCoreTests/LocalizationTests.swift`

- [ ] **Step 1: Write failing localization parity tests**

Parse both strings files and assert identical keys, including menu actions,
pages, errors, rule labels, units, and installation output labels.

- [ ] **Step 2: Confirm RED**

Run:

```bash
swift test --filter LocalizationTests
```

- [ ] **Step 3: Implement the SwiftUI views**

Use `MenuBarExtra`, `WindowGroup`, Swift Charts, a 4:3 AppKit window aspect
ratio, card/line focus, timestamp ranges, one-point rendering, swipe navigation,
custom outside-click rule overlay, terminal-style installation sheet, and
system/open-in-Finder actions.

- [ ] **Step 4: Verify localization and compile**

Run:

```bash
swift test --filter LocalizationTests
swift build
```

Expected: localization tests pass and both executables compile.

### Task 8: App assembly, documentation, and full verification

**Files:**
- Create: `Resources/App/Info.plist`
- Create: `Resources/App/Silex.entitlements`
- Create: `Scripts/build-app.sh`
- Create: `README.md`
- Create: `Tests/SilexCoreTests/PackagingTests.swift`

- [ ] **Step 1: Write failing packaging tests**

Verify `LSUIElement`, bundle identifier, minimum system version, service plist
placement, executable placement, and absence of generated output from git.

- [ ] **Step 2: Confirm RED and implement app assembly**

The script builds release executables, creates:

```text
Silex.app/
  Contents/MacOS/Silex
  Contents/Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist
  Contents/Library/PrivilegedHelperTools/SilexSMARTService
  Contents/Resources/en.lproj/Localizable.strings
  Contents/Resources/zh-Hans.lproj/Localizable.strings
```

It validates plists and supports ad-hoc signing for local build verification.

- [ ] **Step 3: Run complete verification**

Run:

```bash
swift test
swift build -c release
bash Scripts/build-app.sh --adhoc
plutil -lint dist/Silex.app/Contents/Info.plist
plutil -lint dist/Silex.app/Contents/Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist
codesign --verify --deep --strict dist/Silex.app
git status --short
```

Expected: all tests pass; release build, app assembly, plist validation, and
ad-hoc signature verification succeed; generated output remains ignored.

