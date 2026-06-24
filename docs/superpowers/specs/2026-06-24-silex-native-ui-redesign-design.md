# Silex Native UI Redesign and Chart Correctness Design

## Purpose

Rebuild the Silex window as a compact native macOS interface that faithfully
translates the approved HTML prototype into SwiftUI. The HTML prototype is a
visual reference only: window chrome, controls, typography, focus behavior,
accessibility, dark mode, and system dialogs must use native macOS behavior.

This work also fixes the trend-chart defect that currently joins points from
different metrics into one line.

## Scope

The redesign covers the six existing pages:

1. Settings
2. Health overview
3. Read and write history
4. Temperature history
5. Life and spare-space history
6. Event history

It also covers page navigation, the rule editor, loading and error states,
chart data preparation, functional repair of existing controls, localization,
dark mode, accessibility, tests, and a new personal installer build after
verification.

The work does not change the collector protocol, database schema, offline
policy, package identifiers, daemon ownership, or installation permissions.

## Design Principles

- Prefer native SwiftUI and AppKit behavior over imitating browser controls.
- Preserve the approved density, hierarchy, spacing, card layout, and color
  semantics of the final HTML prototype.
- Keep information visible without large empty regions.
- Separate view layout, navigation input, chart-series preparation, and
  persistence so each can be tested independently.
- Require no network access, Accessibility permission, or other new
  permissions.

## Window and Shared Layout

The application keeps the native macOS title bar and traffic-light controls.
It must not draw a simulated title bar.

Inside the window:

- Use a compact toolbar row.
- Show the Silex mark, application name, and detected drive model on the left.
- Show the Rules button on history pages and Collect Now on the right.
- Put the current page inside one rounded main content container.
- Use adaptive system backgrounds and separators rather than fixed white
  surfaces.
- Keep the existing 900 by 675 point default window size, support a minimum
  content size of 760 by 570 points, and expand the grid and chart fluidly
  above the default size.

The Collect Now button shows a native progress indicator while collection is
running, disables duplicate requests, and returns to its normal label when the
operation finishes.

## Page Navigation

The page order remains Settings, Overview, Read/Write, Temperature, Life, and
Events. Bottom navigation contains only six clickable capsule indicators. The
left and right arrow buttons are removed.

Users can change one page at a time with:

- a horizontal trackpad or Magic Mouse swipe;
- horizontal dragging with a conventional mouse;
- the keyboard Left Arrow and Right Arrow keys;
- a click on a page indicator.

Navigation input is handled by a small window-local adapter rather than a
global event monitor. Horizontal scroll events, drag gestures, and move
commands normalize to the same bounded `previous` or `next` action. A gesture
must cross a direction and distance threshold, be predominantly horizontal,
and trigger at most one page change until that gesture ends. Swiping or
dragging left advances; swiping or dragging right goes back.

Arrow-key navigation is disabled while a text field, picker, or other editable
control has focus and while the rule editor is open. Page indices are always
clamped to valid bounds.

Chart clicks and page gestures must coexist:

- a short click near a plotted point selects that metric;
- clicking chart background clears the selection;
- a dominant horizontal drag changes page and does not select a point;
- a vertical or short ambiguous movement does neither.

## Health Overview

The overview uses the compact two-row structure from the HTML prototype.

The upper status row shows:

- `PASSED` or `FAILED`;
- a localized normal or failed status capsule;
- firmware revision;
- the relative time until the next scheduled collection.

The main area is a five-column by two-row metric grid:

1. Temperature
2. Available spare
3. Percentage used
4. Data read
5. Data written
6. Power cycles
7. Unsafe shutdowns
8. Media errors
9. Alerts
10. Device identifier

Alert count means the number of enabled rules whose `lastTriggeredAt` is
within one second of the latest sample's `collectedAt`. This represents alerts
triggered by the latest completed collection and is derived from existing
persisted rule state. It is not the total number of configured rules.

The current large page title, oversized whitespace, and decorative SF Symbol
grid are removed. Labels remain secondary. Every numeric value uses
monospaced digits; model names and the device identifier use normal system
text.

When no sample exists, the same status and grid geometry remains visible.
Unavailable values use an em dash and a concise no-data explanation so the
layout does not jump after the first collection.

## History Page Layout

All four history pages share one structure:

- compact page heading;
- fixed-height metric-card strip;
- chart panel filling the remaining space;
- chart title at upper left;
- native capsule-style `24h`, `30d`, and `All` range controls at upper right.

Metric cards show the latest value and two contextual statistics. Cards are
laid out as one, two, or three equal columns according to the metric count.
Clicking a card focuses its metric; clicking it again clears the focus.

The pages and colors are:

- Read/Write: read blue, written cyan.
- Temperature: temperature green.
- Life: available spare green, percentage used purple, threshold amber.
- Events: power cycles blue, unsafe shutdowns amber, media errors red.

The Events chart contains those three series only. Power-on hours remains
contextual device information rather than a fourth event series.

## Chart Data and Rendering

### Root Cause

The current chart creates `LineMark` values with only time and numeric value.
Swift Charts therefore treats points from different metrics as one series and
connects them in declaration order. This produces horizontal lines, diagonals,
and X-shaped crossings between unrelated metrics.

### Series Preparation

A dedicated, UI-independent series builder prepares chart input. For every
visible metric it:

1. filters samples to the selected time range;
2. extracts only values valid for that metric;
3. converts units where required;
4. sorts points by collection timestamp;
5. deduplicates points sharing a metric and timestamp, keeping the last sample
   in stable repository order;
6. returns a separately identified series.

Filtering or focusing a metric changes which prepared series are supplied to
the chart. It never flattens metrics back into one point collection.

### Swift Charts Contract

Every `LineMark` includes an explicit metric series value in addition to its
time and numeric value. Marks from different metrics must never be joined.
Point marks use the same metric identity and color.

Point marks are visible for 24-hour and 30-day ranges. In the All range they
are hidden to avoid dense plots, except when a series contains only one point.

### Axes

The horizontal axis is derived from visible timestamps and requests five
readable labels from Swift Charts.

The vertical domain is derived from all currently visible series. For a
non-zero range, padding is ten percent of that range on both sides. For an
equal-valued series, padding is the greater of five percent of the absolute
value or one unit. Count and cumulative-data metrics clamp the lower domain to
zero. Percentage metrics clamp the domain to `0...100`; an equal value at zero
uses `0...1`, and an equal value at 100 uses `99...100`. Empty data does not
construct a numeric domain and instead uses the placeholder state.

Selecting a metric recalculates the domain from that metric only.

### Empty Charts

When a range contains no points, the metric cards remain visible and the chart
panel shows a concise native no-data state. Switching to another range must
not alter page geometry.

## Settings

The settings page uses compact native cards arranged in two columns, based on
the HTML prototype. It retains:

- language;
- collection interval;
- notifications;
- launch at login;
- daemon status;
- storage location.

The collection interval is normalized to the supported minimum and saved when
editing commits. The scheduler then recalculates from:

`last collection time + new normalized interval`

If that time has already passed, collection begins immediately. If the new
interval moves the due time into the future, the old timer is replaced by the
new due time.

Daemon controls remain status-only. The page can refresh status and open the
macOS Login Items and Extensions settings. It cannot install, replace,
register, or request extra privileges for the package-owned daemon.

Storage controls reveal the application support directory in Finder.
JSON/CSV export and Delete History appear in a compact action area. Delete
History requires a native destructive confirmation dialog before mutation.

Errors are not permanently embedded as raw text in the settings layout.

Changing the language must immediately update all visible main-window,
menu-bar, rule-editor, confirmation, result, and error text without requiring
an application restart. The selected language is persisted through the
existing settings repository. Rule aggregation labels and all other currently
hard-coded user-facing strings are moved into the localization resources.

The Notifications setting controls actual delivery:

- when enabled, real rule matches and test-rule simulations may request
  notification authorization and post a macOS notification;
- when disabled, neither real nor simulated matches request authorization or
  post a macOS notification;
- rule evaluation and application-local result feedback still occur when
  notifications are disabled.

## Rule Editor

Rules open in a compact native modal overlay:

- title, Add Rule, and Close controls at the top;
- a scrollable rule list in the body;
- inline controls for name, enabled state, metric, aggregation, comparison,
  threshold, window, and cooldown;
- Test, Delete, and Save actions for each rule.

Editing occurs in draft values rather than directly mutating the persisted
model. Closing the overlay or clicking its backdrop:

- closes immediately if there are no draft changes;
- otherwise presents a native Save, Discard, or Cancel decision.

Delete Rule uses a native destructive confirmation. Saving validates that the
selected aggregation is allowed for the metric, threshold is finite, and
window and cooldown values are finite and non-negative. Validation messages
appear next to the affected draft rather than as a global raw error.

Test Rule always produces an in-application result sheet or alert describing
the simulated metric, observed value, comparison, and threshold. This feedback
is independent of notification permission, so pressing Test can never appear
to do nothing. If Notifications is enabled, the same test also attempts the
existing macOS notification path. A notification denial or delivery failure is
reported in the application result without changing or saving the rule.

## Functional Completeness

The redesign is not considered complete if controls only render correctly.
Every visible interactive element must have an observable and verified result:

- language selection updates all visible localized UI immediately;
- interval edits persist and reschedule collection;
- notification and launch-at-login switches control their underlying system
  behavior and reflect failures;
- daemon refresh updates displayed status;
- the system-settings and Finder actions open their documented destinations;
- JSON and CSV actions create the selected file or report cancellation/error;
- destructive actions require confirmation and mutate only after approval;
- Add, Save, Test, and Delete Rule provide visible success, validation,
  cancellation, or error feedback;
- range controls, metric focus, page indicators, gestures, keyboard commands,
  and Collect Now update the expected state.

The implementation begins with an audit that maps every visible control to its
model action and user-visible outcome. Any control without a complete event
path is repaired or removed; inert placeholders are not retained.

## Loading, Errors, and Service State

- Collection failures use a dismissible native alert or compact error
  presentation with the actionable message.
- If the daemon is unavailable, the message includes a direct action to open
  macOS Login Items and Extensions settings.
- Database bootstrap failure presents an explicit unavailable state instead
  of a mostly empty window.
- Successful collection clears the current collection error and refreshes
  samples, rule state, and the next scheduled time.
- Existing history remains readable when collection or the daemon is
  unavailable.

## Localization, Appearance, and Accessibility

All new user-facing strings are available in English and Simplified Chinese.
The language setting continues to support system, English, and Simplified
Chinese.

Colors preserve semantic identity but adapt to light and dark appearances.
Text and control backgrounds use system colors with sufficient contrast.

Interactive page indicators, metric cards, toolbar actions, range controls,
and rule actions have localized accessibility labels and selected-state
semantics. Keyboard focus remains visible. Color is never the only way to
identify a metric or health state.

The redesign uses no global keyboard or pointer monitoring and therefore does
not require Accessibility permission.

## Component Boundaries

Implementation must keep these responsibilities separate:

- `MainWindowView`: shared window composition and presentation.
- Page-navigation controller or adapter: normalized pointer, scroll, keyboard,
  focus, and boundary behavior.
- `OverviewView`: status summary and fixed metric grid.
- `TrendPageView`: history-page composition and selection state.
- Chart-series builder: filtering, conversion, ordering, deduplication, and
  axis-domain input.
- Settings sections: presentation and committed setting changes.
- Rule draft editor: validation, dirty-state tracking, save, discard, and
  delete decisions.
- `AppModel`: orchestration, persistence, collection, service status, and
  scheduler interaction.

View files should not duplicate metric ordering, colors, or chart conversion
rules. Those definitions must have one shared source.

## Verification

### Unit and Harness Tests

Tests must cover:

- every visible control has a connected action and observable state or
  presentation outcome;
- changing language refreshes the main window, menu bar, rule editor, and
  active presentation and persists across model reload;
- notification-disabled collection and rule tests never request or post a
  system notification;
- notification-enabled collection and rule tests use the notification client;
- Test Rule always reports an in-application simulated result, including when
  notification delivery is denied or disabled;
- two metrics with two timestamps remain two chronological series;
- three metrics with two timestamps remain three chronological series;
- unordered samples are sorted per metric;
- duplicate metric/timestamp values use the documented last-value policy;
- focused metrics do not include points from other metrics;
- equal-value and empty-value axis domains are valid and deterministic;
- metric colors and event membership match this specification;
- collection interval shortening, lengthening, startup, and wake behavior;
- page boundary clamping and one-page-per-gesture behavior;
- navigation suppression while editing or while the rule modal is open;
- rule draft save, discard, validation, and dirty-state decisions;
- destructive confirmation paths do not mutate data before confirmation;
- existing offline, least-privilege, package, and daemon tests remain green.

The chart-series regression tests must model the exact failure pattern shown
in the reported screenshots: multiple metrics sharing each sample timestamp.

### Visual and Interaction Verification

Verify the application at its normal and minimum supported window sizes in:

- English and Simplified Chinese;
- light and dark mode;
- populated, empty, collecting, daemon-unavailable, and error states.

Manually verify trackpad or Magic Mouse swipe, conventional mouse drag,
keyboard arrows, page-indicator clicks, chart metric selection, and editing
focus behavior.

### Build Verification

Run the complete test suite and build the application. After verification,
produce a replacement PKG and DMG using the existing offline personal
distribution process. Building the artifacts must not install them or load a
daemon.

## Acceptance Criteria

- The native UI is recognizably faithful to the final approved HTML prototype
  without simulating browser or window chrome.
- The overview is compact and contains the specified ten metrics.
- History charts never connect points belonging to different metrics.
- Chart colors, metric membership, focus, range filtering, ordering, and axes
  match this specification.
- Page arrows are absent; all approved swipe, drag, keyboard, and indicator
  navigation works without stealing editing input.
- Settings and rule editing preserve existing functionality with native
  confirmations and clear errors.
- Language selection, rule testing, notifications, and every other visible
  control have verified working event paths and user-visible outcomes.
- Light mode, dark mode, English, Chinese, empty data, and failures remain
  readable and stable.
- No new network behavior or unnecessary permission is introduced.
- Tests pass and replacement PKG and DMG artifacts are produced.

## Commit Attribution

Commits produced for this work use:

`Anon-233 <105512649+Anon-233@users.noreply.github.com>`

and include:

`Co-authored-by: Codex <codex@openai.com>`
