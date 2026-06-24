# Silex Native UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a compact native macOS UI faithful to the approved prototype, repair every visible control path, fix cross-metric chart lines, and produce verified replacement PKG and DMG artifacts.

**Architecture:** Put deterministic chart, navigation, rule-validation, and notification policy in `SilexCore` so the existing harness can test behavior without launching AppKit. Keep SwiftUI views focused on presentation, drive all user-visible dialogs through explicit `AppModel` presentation state, and use one shared metric presentation definition for chart membership, color, and units.

**Tech Stack:** Swift 6.2 package, SwiftUI, Swift Charts, AppKit, UserNotifications, ServiceManagement, SQLite, shell-based macOS app/PKG/DMG packaging.

---

## File Structure

Create these focused files:

- `Sources/SilexCore/ChartPresentation.swift`: trend groups, metric membership, point preparation, deduplication, and axis domains.
- `Sources/SilexCore/PageNavigation.swift`: bounded navigation and one-action-per-gesture decisions.
- `Sources/SilexCore/RuleDraft.swift`: editable rule copies and validation.
- `Sources/SilexCore/NotificationPolicy.swift`: enabled/disabled notifier behavior and notification failure descriptions.
- `Sources/SilexApp/Presentation.swift`: application alerts, rule-test results, and localized presentation helpers.
- `Sources/SilexApp/Views/WindowInputAdapter.swift`: window-scoped scroll and keyboard input forwarding without Accessibility permission.
- `Sources/SilexApp/Views/OverviewMetricCard.swift`: compact overview tiles.
- `Sources/SilexApp/Views/SettingsCard.swift`: reusable native settings card.

Modify these existing files:

- `Tests/SilexTestRunner/main.swift`: behavioral and source-contract regression tests.
- `Sources/SilexCore/CollectionCoordinator.swift`: evaluate matches independently from optional notification delivery.
- `Sources/SilexApp/AppModel.swift`: explicit presentation state, functional control outcomes, notification policy, rule drafts, and next-collection date.
- `Sources/SilexApp/main.swift`: immediate locale propagation and minimum window size.
- `Sources/SilexApp/Localization.swift`: localized formatting helpers.
- `Sources/SilexApp/Resources/en.lproj/Localizable.strings`: complete English strings.
- `Sources/SilexApp/Resources/zh-Hans.lproj/Localizable.strings`: matching Chinese strings.
- `Sources/SilexApp/Views/MainWindowView.swift`: compact shell, navigation, alerts, and no arrow buttons.
- `Sources/SilexApp/Views/OverviewView.swift`: fixed status header and ten-tile grid.
- `Sources/SilexApp/Views/MetricCard.swift`: compact selectable metric cards.
- `Sources/SilexApp/Views/TrendPageView.swift`: explicit chart series, approved colors, layout, focus, and ranges.
- `Sources/SilexApp/Views/SettingsView.swift`: two-column settings and destructive confirmation.
- `Sources/SilexApp/Views/RuleOverlay.swift`: draft editing, validation, confirmations, and visible test result.
- `Sources/SilexApp/Views/MenuBarView.swift`: localized live state and consistent feedback.

## Task 1: Add deterministic chart presentation

**Files:**
- Create: `Sources/SilexCore/ChartPresentation.swift`
- Modify: `Tests/SilexTestRunner/main.swift`

- [ ] **Step 1: Write failing chart-series regression tests**

Add tests that construct two samples at `100` and `200` seconds, pass metrics
`[.dataRead, .dataWritten]`, and assert two separate series whose timestamp
arrays are `[100, 200]`. Add the same assertion for
`[.availableSpare, .percentageUsed, .availableSpareThreshold]`.

```swift
let series = ChartSeriesBuilder().build(
    metrics: [.dataRead, .dataWritten],
    samples: [second, first],
    range: .all,
    now: second.collectedAt,
    scale: { metric, value in
        metric == .dataRead || metric == .dataWritten ? value / 1_000 : value
    }
)
try requireEqual(series.map(\.metric), [.dataRead, .dataWritten], "series identity")
try requireEqual(series[0].points.map(\.date), [first.collectedAt, second.collectedAt], "read order")
try requireEqual(series[1].points.map(\.date), [first.collectedAt, second.collectedAt], "write order")
```

Add duplicate-timestamp coverage where the later repository element wins, and
axis-domain coverage for normal, equal, zero, 100-percent, and empty inputs.

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift run SilexTestRunner
```

Expected: compilation fails because `ChartSeriesBuilder`,
`ChartMetricSeries`, and `ChartAxisDomainBuilder` do not exist.

- [ ] **Step 3: Implement chart presentation types**

Create public sendable value types:

```swift
public struct ChartPoint: Equatable, Identifiable, Sendable {
    public let metric: Metric
    public let date: Date
    public let value: Double
    public var id: String { "\(metric.rawValue)-\(date.timeIntervalSince1970)" }
}

public struct ChartMetricSeries: Equatable, Identifiable, Sendable {
    public let metric: Metric
    public let points: [ChartPoint]
    public var id: Metric { metric }
}

public enum ChartValueKind: Sendable {
    case percentage
    case nonnegative
    case unconstrained
}

public struct ChartAxisDomain: Equatable, Sendable {
    public let lower: Double
    public let upper: Double
}
```

Implement `ChartSeriesBuilder.build` by enumerating repository order,
filtering with `HistoryAnalyzer`, assigning the last value for each
metric/timestamp key, and sorting each returned series by date.

Implement `ChartAxisDomainBuilder.domain(values:kind:)` with the exact
ten-percent and equal-value rules in the design. Return `nil` for no finite
values.

- [ ] **Step 4: Run tests and verify pass**

Run:

```bash
swift run SilexTestRunner
```

Expected: all chart-series and axis-domain tests pass, with no cross-metric
flattening.

- [ ] **Step 5: Commit**

```bash
git add Sources/SilexCore/ChartPresentation.swift Tests/SilexTestRunner/main.swift
git -c user.name="Anon-233" -c user.email="105512649+Anon-233@users.noreply.github.com" \
  commit -m "fix: isolate chart metric series" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

## Task 2: Make notification behavior obey settings

**Files:**
- Create: `Sources/SilexCore/NotificationPolicy.swift`
- Modify: `Sources/SilexCore/CollectionCoordinator.swift`
- Modify: `Tests/SilexTestRunner/main.swift`

- [ ] **Step 1: Write failing notification-policy tests**

Add a notifier with a call counter and tests proving:

- disabled delivery does not invoke the wrapped notifier;
- enabled delivery invokes it once;
- a real rule match is persisted with `lastTriggeredAt` even when notification
  delivery throws;
- the collection outcome still contains the match and one notification
  failure.

```swift
let notifier = RecordingNotifier()
let disabled = ConditionalAlertNotifier(isEnabled: false, notifier: notifier)
try await disabled.post(match)
try requireEqual(notifier.matches.count, 0, "disabled notification calls")
```

- [ ] **Step 2: Run tests and verify failure**

Run `swift run SilexTestRunner`.

Expected: compilation fails because `ConditionalAlertNotifier` and collection
notification failures do not exist.

- [ ] **Step 3: Implement policy and non-fatal delivery failures**

Create:

```swift
public struct ConditionalAlertNotifier: AlertNotifying {
    public let isEnabled: Bool
    public let notifier: any AlertNotifying

    public func post(_ match: AlertMatch) async throws {
        guard isEnabled else { return }
        try await notifier.post(match)
    }
}

public struct AlertDeliveryFailure: Equatable, Sendable {
    public let ruleID: UUID
    public let message: String
}
```

Extend `CollectionOutcome` with `notificationFailures`. In `collect`, evaluate
the match, update and save `lastTriggeredAt`, append the match, then attempt
notification in `do/catch` and append a failure instead of aborting the
collection. Keep parser, collector, database, and rule-save errors fatal.

- [ ] **Step 4: Run tests and verify pass**

Run `swift run SilexTestRunner`.

Expected: notification policy tests pass and existing coordinator tests remain
green.

- [ ] **Step 5: Commit**

```bash
git add Sources/SilexCore/NotificationPolicy.swift Sources/SilexCore/CollectionCoordinator.swift Tests/SilexTestRunner/main.swift
git -c user.name="Anon-233" -c user.email="105512649+Anon-233@users.noreply.github.com" \
  commit -m "fix: honor notification settings" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

## Task 3: Add navigation and rule-draft domain models

**Files:**
- Create: `Sources/SilexCore/PageNavigation.swift`
- Create: `Sources/SilexCore/RuleDraft.swift`
- Modify: `Tests/SilexTestRunner/main.swift`

- [ ] **Step 1: Write failing navigation and draft tests**

Test page clamping, predominantly horizontal thresholding, and the
one-action-per-gesture latch:

```swift
var navigation = PageNavigationState(page: 1, pageCount: 6)
try requireEqual(navigation.finishDrag(width: -80, height: 5, isBlocked: false), 2, "advance")
try requireEqual(navigation.finishDrag(width: -80, height: 5, isBlocked: true), 2, "blocked")
navigation.go(to: 99)
try requireEqual(navigation.page, 5, "upper clamp")
```

Test `RuleDraft.validate()` rejects an empty name, disallowed aggregation,
non-finite threshold, negative window, and negative cooldown, and accepts a
valid rule. Test `makeRule()` preserves ID and `lastTriggeredAt`.

- [ ] **Step 2: Run tests and verify failure**

Run `swift run SilexTestRunner`.

Expected: compilation fails because the new types do not exist.

- [ ] **Step 3: Implement pure models**

Implement:

```swift
public enum PageDirection: Sendable { case previous, next }

public struct PageNavigationState: Equatable, Sendable {
    public private(set) var page: Int
    public let pageCount: Int

    public mutating func go(to target: Int) {
        page = min(max(target, 0), pageCount - 1)
    }

    public mutating func move(_ direction: PageDirection, isBlocked: Bool) {
        guard !isBlocked else { return }
        go(to: page + (direction == .next ? 1 : -1))
    }

    @discardableResult
    public mutating func finishDrag(
        width: Double,
        height: Double,
        isBlocked: Bool
    ) -> Int {
        guard !isBlocked, abs(width) >= 60, abs(width) > abs(height) * 1.25 else {
            return page
        }
        move(width < 0 ? .next : .previous, isBlocked: false)
        return page
    }
}
```

Implement `RuleDraft`, `RuleDraftValidationError`, `isDirty(comparedTo:)`,
`validate()`, and `makeRule()` as a pure conversion layer.

- [ ] **Step 4: Run tests and verify pass**

Run `swift run SilexTestRunner`.

Expected: navigation and rule validation tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SilexCore/PageNavigation.swift Sources/SilexCore/RuleDraft.swift Tests/SilexTestRunner/main.swift
git -c user.name="Anon-233" -c user.email="105512649+Anon-233@users.noreply.github.com" \
  commit -m "feat: add UI interaction domain models" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

## Task 4: Repair AppModel control outcomes and localization

**Files:**
- Create: `Sources/SilexApp/Presentation.swift`
- Modify: `Sources/SilexApp/AppModel.swift`
- Modify: `Sources/SilexApp/Localization.swift`
- Modify: `Sources/SilexApp/main.swift`
- Modify: `Sources/SilexApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/SilexApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Tests/SilexTestRunner/main.swift`

- [ ] **Step 1: Write failing source-contract and localization tests**

Add harness checks that:

- English and Chinese key sets include aggregation, comparison, dialog,
  success, failure, overview, and rule-test keys;
- `CollectionCoordinator` is constructed with
  `ConditionalAlertNotifier(isEnabled: settings.notificationsEnabled, ...)`;
- no user-facing aggregation label is hard-coded as `"Current"` or
  `"Rate/h"` in Swift sources;
- `AppModel` exposes application alert and rule-test result state;
- `main.swift` keys the localized content by selected language.

- [ ] **Step 2: Run tests and verify failure**

Run `swift run SilexTestRunner`.

Expected: new localization and source-contract assertions fail.

- [ ] **Step 3: Add explicit presentation state**

Create:

```swift
struct AppAlert: Identifiable, Equatable {
    enum Kind: Equatable { case error, success, serviceUnavailable }
    let id = UUID()
    let kind: Kind
    let titleKey: String
    let message: String
}

struct RuleTestPresentation: Identifiable, Equatable {
    let id = UUID()
    let ruleName: String
    let metric: Metric
    let observedValue: Double
    let comparison: RuleComparison
    let threshold: Double
    let notificationMessage: String?
}
```

In `AppModel`:

- add `@Published var presentedAlert: AppAlert?`;
- add `@Published var ruleTestPresentation: RuleTestPresentation?`;
- add `@Published private(set) var nextCollectionAt: Date?`;
- set `nextCollectionAt` whenever scheduling changes;
- construct conditional notifiers using `settings.notificationsEnabled`;
- make `testRule` always calculate and publish the simulated result, then
  optionally attempt notification and record its error in that result;
- turn file export cancellation into no alert, successful write into a
  success alert, and write failure into an error alert;
- expose confirmed delete methods separately from confirmation presentation;
- replace raw `lastError` presentation with explicit alerts while retaining
  logging.

- [ ] **Step 4: Make locale replacement deterministic**

Create an observed language host:

```swift
struct LocalizedAppContent<Content: View>: View {
    @ObservedObject var model: AppModel
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.locale, model.locale)
            .id(model.settings.language)
    }
}
```

Use it for both `WindowGroup` and `MenuBarExtra`. Localize every aggregation,
comparison, result, confirmation, service, and export string in both `.strings`
files.

- [ ] **Step 5: Run tests and build**

Run:

```bash
swift run SilexTestRunner
swift build
```

Expected: all harness tests pass and the app compiles.

- [ ] **Step 6: Commit**

```bash
git add Sources/SilexApp/Presentation.swift Sources/SilexApp/AppModel.swift Sources/SilexApp/Localization.swift Sources/SilexApp/main.swift Sources/SilexApp/Resources Tests/SilexTestRunner/main.swift
git -c user.name="Anon-233" -c user.email="105512649+Anon-233@users.noreply.github.com" \
  commit -m "fix: connect app controls and localization" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

## Task 5: Rebuild the window shell and navigation

**Files:**
- Create: `Sources/SilexApp/Views/WindowInputAdapter.swift`
- Modify: `Sources/SilexApp/Views/MainWindowView.swift`
- Modify: `Sources/SilexApp/Views/WindowConfigurator.swift`
- Modify: `Sources/SilexApp/main.swift`
- Modify: `Tests/SilexTestRunner/main.swift`

- [ ] **Step 1: Write failing shell contract tests**

Add source assertions that `MainWindowView.swift` contains no
`chevron.left`, `chevron.right`, `action.previous`, or `action.next`; contains
clickable page indicators; and uses `WindowInputAdapter`.

Assert `main.swift` or `WindowConfigurator.swift` sets a 760 by 570 minimum
content size and the default remains 900 by 675.

- [ ] **Step 2: Run tests and verify failure**

Run `swift run SilexTestRunner`.

Expected: shell contract fails because arrow buttons remain.

- [ ] **Step 3: Implement window-scoped input**

`WindowInputAdapter` installs an `NSEvent.addLocalMonitorForEvents` token while
its representable view belongs to a window, filters all events by that exact
window, and removes the token on dismantle. It handles:

- `.scrollWheel`: accumulate horizontal deltas until 60 points, require
  horizontal dominance, fire once until momentum/phase ends;
- `.keyDown`: Left/Right only when the first responder is not an editable text
  control and the rule overlay is closed;
- no mouse or keyboard events from another window.

The SwiftUI content keeps `DragGesture` for conventional click-and-drag and
uses `PageNavigationState.finishDrag`.

- [ ] **Step 4: Rebuild shared shell**

Use 10-point vertical spacing and 14-point outer padding. Build the compact
header with 30-point mark, application name/device, Rules, and Collect Now.
Render one rounded content container and only the clickable capsule indicator
row. Present `AppAlert` through native `.alert`.

- [ ] **Step 5: Run tests and build**

Run:

```bash
swift run SilexTestRunner
swift build
```

Expected: shell contract passes and app compiles.

- [ ] **Step 6: Commit**

```bash
git add Sources/SilexApp/Views/WindowInputAdapter.swift Sources/SilexApp/Views/MainWindowView.swift Sources/SilexApp/Views/WindowConfigurator.swift Sources/SilexApp/main.swift Tests/SilexTestRunner/main.swift
git -c user.name="Anon-233" -c user.email="105512649+Anon-233@users.noreply.github.com" \
  commit -m "feat: add native page navigation" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

## Task 6: Rebuild overview and history pages

**Files:**
- Create: `Sources/SilexApp/Views/OverviewMetricCard.swift`
- Modify: `Sources/SilexApp/Views/OverviewView.swift`
- Modify: `Sources/SilexApp/Views/MetricCard.swift`
- Modify: `Sources/SilexApp/Views/TrendPageView.swift`
- Modify: `Sources/SilexApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/SilexApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Tests/SilexTestRunner/main.swift`

- [ ] **Step 1: Write failing view contract tests**

Assert:

- overview source defines ten approved keys and no four-column SF Symbol grid;
- Events metrics are exactly power cycles, unsafe shutdowns, and media errors;
- approved metric color mapping is centralized;
- `LineMark` contains `series: .value`;
- `TrendPageView` consumes `ChartSeriesBuilder` rather than nesting raw metric
  and sample loops.

- [ ] **Step 2: Run tests and verify failure**

Run `swift run SilexTestRunner`.

Expected: view source contract fails on old grid, event membership, colors,
and missing series.

- [ ] **Step 3: Implement shared metric presentation**

Define one app-side mapping:

```swift
extension Metric {
    var chartColor: Color {
        switch self {
        case .dataRead, .powerCycles: .blue
        case .dataWritten: .cyan
        case .temperature, .availableSpare: .green
        case .percentageUsed: .purple
        case .availableSpareThreshold, .unsafeShutdowns: .orange
        case .mediaErrors: .red
        default: .secondary
        }
    }
}
```

Use that mapping in cards, lines, and points.

- [ ] **Step 4: Rebuild overview**

Create a compact status row with health state, localized capsule, firmware,
and next collection. Build a five-column/two-row grid with temperature, spare,
used, read, written, power cycles, unsafe shutdowns, media errors, latest
collection alert count, and `/dev/disk0`. Preserve the same structure with em
dashes when no sample exists.

- [ ] **Step 5: Rebuild history pages and fix charts**

Use the approved card strip and chart panel. Build prepared series once per
render, then render:

```swift
ForEach(series) { metricSeries in
    ForEach(metricSeries.points) { point in
        LineMark(
            x: .value("Time", point.date),
            y: .value("Value", point.value),
            series: .value("Metric", metricSeries.metric.rawValue)
        )
        .foregroundStyle(metricSeries.metric.chartColor)
    }
}
```

Apply the computed domain, point visibility rules, card focus, chart click
focus, and range controls. Keep Events to three metrics.

- [ ] **Step 6: Run tests and build**

Run:

```bash
swift run SilexTestRunner
swift build
```

Expected: chart regression and view contract tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/SilexApp/Views/OverviewMetricCard.swift Sources/SilexApp/Views/OverviewView.swift Sources/SilexApp/Views/MetricCard.swift Sources/SilexApp/Views/TrendPageView.swift Sources/SilexApp/Resources Tests/SilexTestRunner/main.swift
git -c user.name="Anon-233" -c user.email="105512649+Anon-233@users.noreply.github.com" \
  commit -m "feat: rebuild health and history pages" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

## Task 7: Rebuild settings and rule editing

**Files:**
- Create: `Sources/SilexApp/Views/SettingsCard.swift`
- Modify: `Sources/SilexApp/Views/SettingsView.swift`
- Modify: `Sources/SilexApp/Views/RuleOverlay.swift`
- Modify: `Sources/SilexApp/AppModel.swift`
- Modify: `Sources/SilexApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/SilexApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Tests/SilexTestRunner/main.swift`

- [ ] **Step 1: Write failing functional source tests**

Assert:

- Delete History uses a confirmation presentation before `deleteHistory`;
- RuleOverlay edits `RuleDraft`, not direct `$model.rules` bindings;
- Test Rule binds to `ruleTestPresentation`;
- save/discard/cancel and delete confirmation states exist;
- every visible settings action references its expected model method;
- no raw `lastError` text is embedded in settings.

- [ ] **Step 2: Run tests and verify failure**

Run `swift run SilexTestRunner`.

Expected: functional source tests fail on direct bindings and missing
confirmations.

- [ ] **Step 3: Rebuild settings**

Use a two-column lazy grid of native `SettingsCard` sections. Commit interval
changes on submit/focus loss, display normalized minimum help, and keep
language, notification, login, daemon, and storage controls observable.
Present JSON/CSV actions and destructive Delete History in a compact footer.
Use `.confirmationDialog` before deletion.

- [ ] **Step 4: Rebuild rule editor with drafts**

When opening, map rules to `RuleDraft`. Add creates an unsaved draft. Save
validates and writes one rule; Delete confirms; Close/backdrop compares drafts
to persisted rules and presents Save All, Discard, or Cancel. Test always
publishes `RuleTestPresentation`; present it with a native sheet or alert,
including notification-disabled or denied details.

- [ ] **Step 5: Run tests and build**

Run:

```bash
swift run SilexTestRunner
swift build
```

Expected: settings/rule functional contracts pass and app compiles.

- [ ] **Step 6: Commit**

```bash
git add Sources/SilexApp/Views/SettingsCard.swift Sources/SilexApp/Views/SettingsView.swift Sources/SilexApp/Views/RuleOverlay.swift Sources/SilexApp/AppModel.swift Sources/SilexApp/Resources Tests/SilexTestRunner/main.swift
git -c user.name="Anon-233" -c user.email="105512649+Anon-233@users.noreply.github.com" \
  commit -m "feat: restore settings and rule workflows" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

## Task 8: Verify appearance, interaction, and failures

**Files:**
- Modify: `Sources/SilexApp/Views/MainWindowView.swift`
- Modify: `Sources/SilexApp/Views/OverviewView.swift`
- Modify: `Sources/SilexApp/Views/TrendPageView.swift`
- Modify: `Sources/SilexApp/Views/SettingsView.swift`
- Modify: `Sources/SilexApp/Views/RuleOverlay.swift`
- Modify: `Sources/SilexApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/SilexApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Tests/SilexTestRunner/main.swift`

- [ ] **Step 1: Run full automated verification**

Run:

```bash
swift run SilexTestRunner
swift build
swift build -c release
```

Expected: every command exits zero and the harness reports all tests passed.

- [ ] **Step 2: Build the ad-hoc application bundle**

Run:

```bash
SILEX_VERSION=0.1.0 SILEX_BUILD=2 Scripts/build-app.sh --adhoc
```

Expected: `dist/Silex.app` is produced and strict code-sign verification
passes.

- [ ] **Step 3: Launch and inspect the native app**

Run:

```bash
open dist/Silex.app
```

Use Computer Use to verify:

- the 900 by 675 normal window and 760 by 570 minimum layout;
- all six pages, clickable indicators, Left/Right keys, mouse drag, and
  trackpad/Magic Mouse swipe where available;
- English and Chinese switch immediately;
- populated/empty presentation, Rules workflow, Test result, notification
  disabled behavior, destructive confirmations, daemon unavailable action;
- light and dark appearances;
- no bottom arrow buttons;
- no chart cross-series lines.

For a data, control-path, localization, or source-contract defect, add a
failing harness assertion before repairing it. For a spacing, clipping, or
color defect that cannot be represented by the harness, capture the observed
window state, make the smallest view-only correction, and repeat Steps 1–3.

- [ ] **Step 4: Commit verified UI corrections**

If visual verification required source changes:

```bash
git add Sources Tests
git -c user.name="Anon-233" -c user.email="105512649+Anon-233@users.noreply.github.com" \
  commit -m "fix: refine native UI behavior" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

If no source changes were required, do not create an empty commit.

## Task 9: Build and verify replacement installers

**Files:**
- Modify only if verification exposes a packaging regression:
  `Scripts/build-app.sh`, `Scripts/build-installer.sh`,
  `Scripts/verify-installer.sh`, or `Packaging/*`

- [ ] **Step 1: Locate packaged smartctl**

Run:

```bash
command -v smartctl
```

Expected: an executable path. If not found, use the already-installed
`/opt/homebrew/bin/smartctl`; if that path is also absent, stop the packaging
step and report the missing local prerequisite without downloading anything.

- [ ] **Step 2: Build the replacement package and disk image**

Run:

```bash
SMARTCTL_PATH="$(command -v smartctl)" Scripts/build-installer.sh 0.1.0 2
```

Expected:

- `dist/Silex-0.1.0.pkg`
- `dist/Silex-0.1.0.dmg`
- no installation, daemon loading, or network access.

- [ ] **Step 3: Verify artifacts**

Run:

```bash
Scripts/verify-installer.sh 0.1.0
```

Expected: application signing, package payload, non-relocatable bundle,
offline framework checks, and DMG verification all pass.

- [ ] **Step 4: Run final repository checks**

Run:

```bash
git diff --check
git status --short --branch
git log -8 --format='%h %an <%ae>%n%B'
```

Expected: no uncommitted source changes; every new commit is authored by
`Anon-233 <105512649+Anon-233@users.noreply.github.com>` and contains
`Co-authored-by: Codex <codex@openai.com>`.

- [ ] **Step 5: Commit packaging fixes if needed**

If and only if packaging files changed:

```bash
git add Scripts Packaging
git -c user.name="Anon-233" -c user.email="105512649+Anon-233@users.noreply.github.com" \
  commit -m "fix: package redesigned Silex app" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

Then rerun Steps 2–4.
