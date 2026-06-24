# Silex Personal Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an offline, least-privilege `Silex-<version>.pkg` and `Silex-<version>.dmg` that install one updatable copy of Silex plus its restricted on-demand SMART daemon.

**Architecture:** The PKG owns the system daemon lifecycle and installs fixed files under `/Applications` and `/Library`; the application only probes the fixed XPC service and opens macOS Background Items settings for user control. Packaging scripts stage deterministic payloads, reject normal downgrades, preserve user data, support ad-hoc personal builds, and optionally use Developer ID signing and notarization.

**Tech Stack:** Swift 6.3, SwiftUI/AppKit, NSXPC, launchd, POSIX shell, AppleScript, `codesign`, `pkgbuild`, `productbuild`, `hdiutil`, `notarytool`, and the existing executable test harness.

---

## File structure

- Modify `Sources/SilexCore/SMARTServiceProtocol.swift`: fixed installed service and smartctl names plus XPC probe method.
- Modify `Sources/SilexCore/SMARTServiceClient.swift`: reusable XPC connection and asynchronous availability probe.
- Modify `Sources/SilexCore/ServiceController.swift`: status-only controller; remove app-side daemon registration.
- Modify `Sources/SilexSMARTService/SMARTService.swift`: answer probe requests without running smartctl.
- Modify `Sources/SilexApp/AppModel.swift`: asynchronous service refresh and Background Items navigation.
- Modify `Sources/SilexApp/Views/SettingsView.swift`: remove Homebrew/path controls; expose daemon status, refresh, and system control location.
- Modify `Sources/SilexApp/Views/MainWindowView.swift`: remove obsolete install sheet.
- Delete `Sources/SilexApp/Views/InstallSheet.swift`: remove network-capable Homebrew installer.
- Modify both localization files: service availability and Background Items labels.
- Modify `Resources/LaunchDaemons/com.anon233.Silex.SMARTService.plist`: package-installed absolute executable path.
- Modify `Scripts/build-app.sh`: build only the application and accept release version/signing inputs.
- Create `Packaging/Distribution.xml.in`: stable product package metadata and macOS requirement.
- Create `Packaging/Scripts/preinstall.in`: downgrade check and old-daemon shutdown.
- Create `Packaging/Scripts/postinstall`: fixed permissions and daemon reload while preserving a user-disabled state.
- Create `Packaging/Scripts/version-compare.sh`: deterministic dotted-numeric comparison.
- Create `Packaging/Uninstall Silex.applescript`: authorized fixed-path uninstall that preserves user data.
- Create `Packaging/README.txt`: bilingual install, control, update, and uninstall instructions.
- Create `Scripts/build-installer.sh`: stage, sign, package, optionally notarize, and create the DMG.
- Create `Scripts/verify-installer.sh`: expand and inspect the package and mount and inspect the DMG without installing.
- Modify `Tests/SilexTestRunner/main.swift`: service probe, package layout, version comparison, offline, permissions, and script safety tests.
- Modify `README.md`: personal build, install, update, daemon control, offline policy, and optional signing documentation.

### Task 1: Convert the daemon contract to package-owned, status-only operation

**Files:**
- Modify: `Tests/SilexTestRunner/main.swift`
- Modify: `Sources/SilexCore/SMARTServiceProtocol.swift`
- Modify: `Sources/SilexCore/SMARTServiceClient.swift`
- Modify: `Sources/SilexCore/ServiceController.swift`
- Modify: `Sources/SilexSMARTService/SMARTService.swift`

- [ ] **Step 1: Write the failing installed-layout and service-probe tests**

Replace `FakeRegistration` with:

```swift
final class FakeServiceProbe: ServiceProbing, @unchecked Sendable {
    let available: Bool

    init(available: Bool) {
        self.available = available
    }

    func isAvailable() async -> Bool {
        available
    }
}
```

Update the SMART policy assertion to require:

```swift
let serviceURL = URL(
    fileURLWithPath:
        "/Library/PrivilegedHelperTools/com.anon233.Silex.SMARTService"
)
try requireEqual(
    PrivilegedSMARTPolicy.bundledExecutableURL(
        serviceExecutableURL: serviceURL
    ).path,
    "/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl",
    "installed smartctl path"
)
```

Replace the registration test with:

```swift
HarnessTest(name: "service controller only probes package-owned daemon") {
    let available = ServiceController(probe: FakeServiceProbe(available: true))
    let unavailable = ServiceController(probe: FakeServiceProbe(available: false))
    try requireEqual(await available.status(), .available, "available service")
    try requireEqual(await unavailable.status(), .unavailable, "unavailable service")
    try require(SMARTConnectionPolicy.accepts(
        effectiveUserID: 501,
        consoleUserID: 501
    ), "console user")
    try require(!SMARTConnectionPolicy.accepts(
        effectiveUserID: 0,
        consoleUserID: 501
    ), "root client")
}
```

- [ ] **Step 2: Run the harness and verify RED**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/silex-clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/silex-swiftpm-module-cache \
swift run --disable-sandbox SilexTestRunner
```

Expected: compilation fails because `ServiceProbing`, `.available`,
`.unavailable`, and the new installed smartctl name do not exist.

- [ ] **Step 3: Implement the fixed installed contract**

In `SMARTServiceProtocol.swift`, define:

```swift
public enum SMARTServiceConstants {
    public static let machServiceName = "com.anon233.Silex.SMARTService"
    public static let launchDaemonPlistName =
        "com.anon233.Silex.SMARTService.plist"
    public static let installedServicePath =
        "/Library/PrivilegedHelperTools/com.anon233.Silex.SMARTService"
    public static let installedSmartctlPath =
        "/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl"
}

public enum PrivilegedSMARTPolicy {
    public static let bundledExecutableName =
        "com.anon233.Silex.smartctl"

    public static func bundledExecutableURL(
        serviceExecutableURL: URL
    ) -> URL {
        serviceExecutableURL
            .deletingLastPathComponent()
            .appendingPathComponent(bundledExecutableName)
    }

    public static func invocation(
        serviceExecutableURL: URL
    ) -> ProcessRequest {
        ProcessRequest(
            executableURL: bundledExecutableURL(
                serviceExecutableURL: serviceExecutableURL
            ),
            arguments: ["-j", "-x", "/dev/disk0"]
        )
    }
}

@objc(SilexSMARTServiceProtocol)
public protocol SMARTServiceProtocol {
    func probe(reply: @escaping (Bool) -> Void)
    func collectBuiltInDrive(
        reply: @escaping (NSData?, NSNumber, NSString?) -> Void
    )
}
```

In `SMARTService.swift`, add:

```swift
func probe(reply: @escaping (Bool) -> Void) {
    idleTerminator.beginRequest()
    defer { idleTerminator.endRequest() }
    reply(true)
}
```

- [ ] **Step 4: Implement asynchronous XPC probing and status-only control**

In `SMARTServiceClient.swift`, extract the proxy creation used by both methods:

```swift
private final class XPCReplyGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?

    init(_ continuation: CheckedContinuation<Value, any Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<Value, any Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}

private func withService<T: Sendable>(
    _ operation: @escaping @Sendable (
        SMARTServiceProtocol,
        @escaping @Sendable (Result<T, Error>) -> Void
    ) -> Void
) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        let gate = XPCReplyGate(continuation)
        let connection = NSXPCConnection(
            machServiceName: SMARTServiceConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(
            with: SMARTServiceProtocol.self
        )
        connection.resume()
        guard let service = connection.remoteObjectProxyWithErrorHandler({
            gate.resume(
                with: .failure(
                    SMARTServiceClientError.unavailable(
                        $0.localizedDescription
                    )
                )
            )
        }) as? SMARTServiceProtocol else {
            connection.invalidate()
            gate.resume(with: .failure(SMARTServiceClientError.emptyResponse))
            return
        }
        operation(service) { result in
            connection.invalidate()
            gate.resume(with: result)
        }
    }
}
```

Use it for collection and add:

```swift
public func probe() async -> Bool {
    (try? await withService { service, finish in
        service.probe { finish(.success($0)) }
    }) ?? false
}
```

Replace `ServiceController.swift` registration types with:

```swift
public enum BackgroundServiceStatus: Equatable, Sendable {
    case available
    case unavailable
}

public protocol ServiceProbing: Sendable {
    func isAvailable() async -> Bool
}

extension SMARTServiceClient: ServiceProbing {
    public func isAvailable() async -> Bool {
        await probe()
    }
}

public struct ServiceController: Sendable {
    private let probe: any ServiceProbing

    public init() {
        probe = SMARTServiceClient()
    }

    public init(probe: any ServiceProbing) {
        self.probe = probe
    }

    public func status() async -> BackgroundServiceStatus {
        await probe.isAvailable() ? .available : .unavailable
    }
}
```

Keep `SMARTConnectionPolicy` and `PrivilegedServiceIdlePolicy` unchanged.

- [ ] **Step 5: Run the harness and verify GREEN**

Run the Task 1 harness command.

Expected: all tests pass, including installed smartctl path and service probe.

- [ ] **Step 6: Commit**

```bash
git add Tests/SilexTestRunner/main.swift \
  Sources/SilexCore/SMARTServiceProtocol.swift \
  Sources/SilexCore/SMARTServiceClient.swift \
  Sources/SilexCore/ServiceController.swift \
  Sources/SilexSMARTService/SMARTService.swift
git commit -m "refactor: make SMART daemon package managed" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

### Task 2: Expose daemon visibility without app-side installation

**Files:**
- Modify: `Tests/SilexTestRunner/main.swift`
- Modify: `Sources/SilexApp/AppModel.swift`
- Modify: `Sources/SilexApp/Views/SettingsView.swift`
- Modify: `Sources/SilexApp/Views/MainWindowView.swift`
- Delete: `Sources/SilexApp/Views/InstallSheet.swift`
- Modify: `Sources/SilexApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/SilexApp/Resources/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Write the failing offline UI source test**

Add:

```swift
HarnessTest(name: "settings expose package service without Homebrew installer") {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sources = [
        "Sources/SilexApp/AppModel.swift",
        "Sources/SilexApp/Views/SettingsView.swift",
        "Sources/SilexApp/Views/MainWindowView.swift"
    ]
    let content = try sources.map {
        try String(
            contentsOf: root.appendingPathComponent($0),
            encoding: .utf8
        )
    }.joined()
    try require(!content.contains("enablePrivilegedService"), "no app registration")
    try require(!content.contains("brew install"), "no Homebrew execution")
    try require(
        content.contains("openBackgroundItemsSettings"),
        "must expose macOS background controls"
    )
    try require(
        !FileManager.default.fileExists(
            atPath: root.appendingPathComponent(
                "Sources/SilexApp/Views/InstallSheet.swift"
            ).path
        ),
        "network-capable install sheet must be removed"
    )
}
```

- [ ] **Step 2: Run the harness and verify RED**

Run the standard harness command.

Expected: the new test fails because the install sheet and Homebrew controls
still exist.

- [ ] **Step 3: Update `AppModel` to probe and open system controls**

Use:

```swift
@Published var serviceStatus: BackgroundServiceStatus = .unavailable
```

Remove `isInstallSheetPresented`, `autoFillSmartctlPath()`,
`enablePrivilegedService()`, and the daemon registration settings navigation.
Change bootstrap to:

```swift
applyLaunchAtLoginSetting()
observeWake()
Task { [weak self] in
    await self?.refreshServiceStatus()
}
```

Expose:

```swift
func refreshServiceStatus() async {
    serviceStatus = await serviceController.status()
    scheduleNextCollection()
}

func openBackgroundItemsSettings() {
    guard let url = URL(
        string:
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
    ) else {
        return
    }
    NSWorkspace.shared.open(url)
}
```

Change scheduler gating to:

```swift
guard serviceStatus == .available else {
    scheduler.cancel()
    return
}
```

After a failed collection, call `await refreshServiceStatus()` before returning.

- [ ] **Step 4: Replace settings controls**

Delete the smartctl path row. Replace the service row with:

```swift
settingRow("settings.service") {
    HStack {
        Text(serviceStatus)
            .foregroundStyle(
                model.serviceStatus == .available ? .green : .secondary
            )
        Button {
            Task { await model.refreshServiceStatus() }
        } label: {
            LocalizedLabel("action.refresh")
        }
        .buttonStyle(.plain)
        Button {
            model.openBackgroundItemsSettings()
        } label: {
            LocalizedLabel("action.backgroundItems")
        }
        .buttonStyle(.plain)
    }
}
```

Map `.available` and `.unavailable` to new localization keys. Remove the
approval warning, sheet presentation, and `InstallSheet.swift`.

Add equivalent English and Simplified Chinese strings:

```text
"action.refresh" = "Refresh";
"action.backgroundItems" = "Background Items…";
"status.service.available" = "Available";
"status.service.unavailable" = "Unavailable or disabled";
```

```text
"action.refresh" = "刷新";
"action.backgroundItems" = "后台项目…";
"status.service.available" = "可用";
"status.service.unavailable" = "不可用或已禁用";
```

- [ ] **Step 5: Run tests and build**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/silex-clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/silex-swiftpm-module-cache \
swift run --disable-sandbox SilexTestRunner
env CLANG_MODULE_CACHE_PATH=/tmp/silex-clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/silex-swiftpm-module-cache \
swift build --disable-sandbox
```

Expected: all harness tests pass and all targets compile.

- [ ] **Step 6: Commit**

```bash
git add Sources/SilexApp Tests/SilexTestRunner/main.swift
git commit -m "feat: expose system daemon controls" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

### Task 3: Define package-installed launchd payload

**Files:**
- Modify: `Tests/SilexTestRunner/main.swift`
- Modify: `Resources/LaunchDaemons/com.anon233.Silex.SMARTService.plist`
- Modify: `Scripts/build-app.sh`

- [ ] **Step 1: Write failing LaunchDaemon and app-bundle tests**

Extend the plist test with:

```swift
let arguments = dictionary["ProgramArguments"] as? [String]
try requireEqual(
    arguments,
    [SMARTServiceConstants.installedServicePath],
    "fixed installed helper"
)
try require(dictionary["BundleProgram"] == nil, "not app-relative")
try requireEqual(
    dictionary["AssociatedBundleIdentifiers"] as? [String],
    ["com.anon233.Silex"],
    "background item association"
)
```

Change the app build script assertion to require that it does not copy
`SilexSMARTService`, the daemon plist, or smartctl into the application bundle.

- [ ] **Step 2: Run the harness and verify RED**

Run the standard harness command.

Expected: plist and build-script assertions fail.

- [ ] **Step 3: Convert the daemon plist to absolute package paths**

Use:

```xml
<key>ProgramArguments</key>
<array>
    <string>/Library/PrivilegedHelperTools/com.anon233.Silex.SMARTService</string>
</array>
<key>MachServices</key>
<dict>
    <key>com.anon233.Silex.SMARTService</key>
    <true/>
</dict>
<key>UserName</key>
<string>root</string>
<key>RunAtLoad</key>
<false/>
<key>AssociatedBundleIdentifiers</key>
<array>
    <string>com.anon233.Silex</string>
</array>
```

Do not add `KeepAlive`, network settings, or arbitrary arguments.

- [ ] **Step 4: Make `build-app.sh` application-only and version-aware**

Support:

```bash
SILEX_VERSION="${SILEX_VERSION:-0.1.0}"
SILEX_BUILD="${SILEX_BUILD:-1}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:--}"
```

Validate `SILEX_VERSION` against `^[0-9]+\.[0-9]+\.[0-9]+$` and
`SILEX_BUILD` against `^[1-9][0-9]*$`. Copy only the app executable,
localizations, plist, and icon. Write versions into the copied plist with:

```bash
/usr/bin/plutil -replace CFBundleShortVersionString \
  -string "$SILEX_VERSION" "$CONTENTS/Info.plist"
/usr/bin/plutil -replace CFBundleVersion \
  -string "$SILEX_BUILD" "$CONTENTS/Info.plist"
```

For ad-hoc signing use `codesign --sign -`. For a Developer ID identity add
`--options runtime --timestamp`. Do not place helper binaries inside the app.

- [ ] **Step 5: Run tests and package the app**

Run the standard harness, then:

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/silex-clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/silex-swiftpm-module-cache \
SILEX_VERSION=0.1.0 SILEX_BUILD=1 Scripts/build-app.sh --adhoc
codesign --verify --deep --strict dist/Silex.app
```

Expected: tests pass and the application verifies without privileged payloads.

- [ ] **Step 6: Commit**

```bash
git add Tests/SilexTestRunner/main.swift \
  Resources/LaunchDaemons/com.anon233.Silex.SMARTService.plist \
  Scripts/build-app.sh
git commit -m "build: separate app and system daemon payloads" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

### Task 4: Add deterministic version and downgrade policy

**Files:**
- Modify: `Tests/SilexTestRunner/main.swift`
- Create: `Packaging/Scripts/version-compare.sh`
- Create: `Packaging/Scripts/preinstall.in`

- [ ] **Step 1: Write failing executable version-policy tests**

Add a test helper that runs a process and tests:

```swift
try requireEqual(
    try runScript("Packaging/Scripts/version-compare.sh", ["0.1.0", "0.2.0"]),
    "-1",
    "older version"
)
try requireEqual(
    try runScript("Packaging/Scripts/version-compare.sh", ["1.2.3", "1.2.3"]),
    "0",
    "equal version"
)
try requireEqual(
    try runScript("Packaging/Scripts/version-compare.sh", ["2.0.0", "1.9.9"]),
    "1",
    "newer version"
)
```

Also assert `preinstall.in` contains fixed `/Applications/Silex.app`, compares
both short and build versions, contains `@SILEX_VERSION@` and
`@SILEX_BUILD@`, and never deletes Application Support.

- [ ] **Step 2: Run the harness and verify RED**

Expected: the test fails because the scripts do not exist.

- [ ] **Step 3: Implement dotted-numeric comparison**

Create an executable POSIX shell script that validates exactly two dotted
numeric inputs, compares each numeric component without `sort -V`, prints
`-1`, `0`, or `1`, and exits nonzero for malformed input. Use `awk` with:

```awk
function cmp(a, b, left, right, count, i) {
    count = split(a, left, ".")
    if (split(b, right, ".") > count) count = split(b, right, ".")
    for (i = 1; i <= count; i++) {
        if ((left[i] + 0) < (right[i] + 0)) return -1
        if ((left[i] + 0) > (right[i] + 0)) return 1
    }
    return 0
}
```

- [ ] **Step 4: Implement the preinstall template**

The script must:

- read installed `CFBundleShortVersionString` and `CFBundleVersion` with
  `/usr/libexec/PlistBuddy`;
- compare against substituted package values;
- reject a newer installed short version or a newer build of the same short
  version unless `@ALLOW_DOWNGRADE@` is `1`;
- stop an already-loaded service with
  `launchctl bootout system/com.anon233.Silex.SMARTService`;
- never delete the application or user data.

- [ ] **Step 5: Run the harness and verify GREEN**

Run the standard harness command.

Expected: comparison and static safety tests pass.

- [ ] **Step 6: Commit**

```bash
git add Packaging/Scripts Tests/SilexTestRunner/main.swift
git commit -m "build: enforce installer version policy" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

### Task 5: Build the component and product packages

**Files:**
- Modify: `Tests/SilexTestRunner/main.swift`
- Create: `Packaging/Distribution.xml.in`
- Create: `Packaging/Scripts/postinstall`
- Create: `Scripts/build-installer.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Write failing package metadata and script-safety tests**

Add assertions for:

```swift
try require(distribution.contains("com.anon233.Silex.pkg"), "stable package ID")
try require(distribution.contains("26.0"), "minimum macOS")
try require(postinstall.contains("/Library/LaunchDaemons/"), "fixed daemon plist")
try require(!postinstall.contains("launchctl enable"), "preserve disabled state")
try require(postinstall.contains("print-disabled system"), "detect user disable")
try require(build.contains("pkgbuild"), "component package")
try require(build.contains("productbuild"), "product package")
try require(build.contains("--ownership recommended"), "root-owned install")
```

Also assert the build script accepts only numeric semantic versions/builds and
stages exactly the four installed payload paths from the specification.

- [ ] **Step 2: Run the harness and verify RED**

Expected: tests fail because packaging files do not exist.

- [ ] **Step 3: Create the Distribution XML template**

Define one visible choice and one package reference:

```xml
<installer-gui-script minSpecVersion="2">
    <title>Silex</title>
    <options customize="never" require-scripts="true"/>
    <allowed-os-versions>
        <os-version min="26.0"/>
    </allowed-os-versions>
    <choices-outline>
        <line choice="default">
            <line choice="com.anon233.Silex.pkg"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.anon233.Silex.pkg" visible="false">
        <pkg-ref id="com.anon233.Silex.pkg"/>
    </choice>
    <pkg-ref id="com.anon233.Silex.pkg"
        version="@PACKAGE_VERSION@">Silex-component.pkg</pkg-ref>
</installer-gui-script>
```

- [ ] **Step 4: Implement the postinstall script**

Set root ownership and modes for the application, plist, helper, and smartctl.
Check:

```bash
/bin/launchctl print-disabled system |
  /usr/bin/grep -Eq '"com\.anon233\.Silex\.SMARTService"[[:space:]]*=>[[:space:]]*true'
```

If disabled, exit successfully without bootstrapping. Otherwise run:

```bash
/bin/launchctl bootstrap system \
  /Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist
```

Never call `launchctl enable`.

- [ ] **Step 5: Implement `build-installer.sh`**

The script must:

1. Parse `VERSION BUILD` plus optional `--allow-downgrade`.
2. Resolve and validate `SMARTCTL_PATH`.
3. Invoke `build-app.sh` with version, build, and app signing identity.
4. Build `SilexSMARTService` in release mode.
5. Stage:
   - `Applications/Silex.app`
   - `Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist`
   - `Library/PrivilegedHelperTools/com.anon233.Silex.SMARTService`
   - `Library/PrivilegedHelperTools/com.anon233.Silex.smartctl`
6. Sign smartctl, helper, and app in inside-out order.
7. Materialize preinstall and Distribution templates with fixed values.
8. Run `pkgbuild --ownership recommended --identifier
   com.anon233.Silex.pkg --version "$VERSION.$BUILD"`.
9. Run `productbuild`, adding `--sign "$INSTALLER_SIGN_IDENTITY"` only when set.

Do not call `installer`, `sudo`, `launchctl`, or write outside `dist`.

- [ ] **Step 6: Run tests and create the PKG**

Run the standard harness, then outside the restricted sandbox when necessary:

```bash
Scripts/build-installer.sh 0.1.0 1
pkgutil --check-signature dist/Silex-0.1.0.pkg
pkgutil --expand-full dist/Silex-0.1.0.pkg /tmp/Silex-expanded
```

Expected: the package exists and expands to the stable receipt and expected
payload. An unsigned personal package may report no Developer ID signature;
that is expected.

- [ ] **Step 7: Commit**

```bash
git add .gitignore Packaging Scripts/build-installer.sh \
  Tests/SilexTestRunner/main.swift
git commit -m "build: create updatable Silex package" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

### Task 6: Add authorized uninstall and DMG assembly

**Files:**
- Modify: `Tests/SilexTestRunner/main.swift`
- Create: `Packaging/Uninstall Silex.applescript`
- Create: `Packaging/README.txt`
- Modify: `Scripts/build-installer.sh`

- [ ] **Step 1: Write failing uninstall and DMG tests**

Assert the uninstaller:

- uses `with administrator privileges`;
- contains only fixed Silex paths;
- boots out the fixed daemon label;
- forgets `com.anon233.Silex.pkg`;
- removes `/Applications/Silex.app`;
- does not remove `~/Library/Application Support/Silex`.

Assert the build script runs `osacompile` and `hdiutil create` with a staged
folder containing the package, README, and uninstaller.

- [ ] **Step 2: Run the harness and verify RED**

Expected: tests fail because the uninstaller and DMG assembly do not exist.

- [ ] **Step 3: Create the fixed-path AppleScript uninstaller**

Use a confirmation dialog, then:

```applescript
do shell script "/bin/launchctl bootout system/com.anon233.Silex.SMARTService >/dev/null 2>&1 || true; /bin/rm -f /Library/LaunchDaemons/com.anon233.Silex.SMARTService.plist; /bin/rm -f /Library/PrivilegedHelperTools/com.anon233.Silex.SMARTService; /bin/rm -f /Library/PrivilegedHelperTools/com.anon233.Silex.smartctl; /bin/rm -rf /Applications/Silex.app; /usr/sbin/pkgutil --forget com.anon233.Silex.pkg >/dev/null 2>&1 || true" with administrator privileges
```

The completion dialog must state that history was preserved and show the
optional user-data path for manual deletion.

- [ ] **Step 4: Add bilingual instructions**

Document:

- double-clicking `Install Silex.pkg`;
- macOS-controlled Touch ID/password authentication;
- in-place update behavior;
- Background Items location and `launchctl print` diagnostic command;
- offline operation and requested permissions;
- uninstaller behavior and preserved history.

- [ ] **Step 5: Assemble the compressed read-only DMG**

Compile the uninstaller:

```bash
/usr/bin/osacompile -o "$DMG_ROOT/Uninstall Silex.app" \
  "$ROOT/Packaging/Uninstall Silex.applescript"
```

Stage the package as `Install Silex.pkg`, copy `README.txt`, ad-hoc sign the
uninstaller application, and create:

```bash
/usr/bin/hdiutil create -ov -format UDZO -volname "Silex $VERSION" \
  -srcfolder "$DMG_ROOT" "$DIST/Silex-$VERSION.dmg"
```

- [ ] **Step 6: Run tests and verify the disk image**

Run the standard harness, then:

```bash
hdiutil verify dist/Silex-0.1.0.dmg
```

Mount read-only to a temporary mount point and verify exactly:

- `Install Silex.pkg`
- `README.txt`
- `Uninstall Silex.app`

Detach the image after inspection.

- [ ] **Step 7: Commit**

```bash
git add Packaging Scripts/build-installer.sh Tests/SilexTestRunner/main.swift
git commit -m "build: wrap installer in personal distribution image" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

### Task 7: Enforce offline and least-privilege policy

**Files:**
- Modify: `Tests/SilexTestRunner/main.swift`
- Create: `Scripts/verify-installer.sh`
- Modify: `Scripts/build-installer.sh`

- [ ] **Step 1: Write the failing source and artifact audit tests**

Recursively scan `.swift` files under `Sources` and reject:

```text
URLSession
import Network
NWConnection
import WebKit
WKWebView
http://
https://
brew install
```

Parse `Resources/App/Silex.entitlements` and reject any keys containing:

```text
network
client
server
```

Parse `Info.plist` and reject unrelated `NS*UsageDescription` keys. Permit no
privacy usage description in the current application.

- [ ] **Step 2: Run the harness and verify RED**

Expected: the source scan passes only after the Homebrew install UI deletion,
but the artifact verification script check fails because it does not exist.

- [ ] **Step 3: Implement artifact verification**

`verify-installer.sh VERSION` must:

1. Verify the app and nested code with `codesign --verify --deep --strict`.
2. Lint application and LaunchDaemon plists.
3. Run `otool -L` on app, helper, and smartctl and reject
   `Network.framework`, `CFNetwork.framework`, and `WebKit.framework`.
4. Dump app entitlements with `codesign -d --entitlements :-` and reject
   network entitlements.
5. Expand the package and verify receipt ID, paths, executable modes, and
   absence of Application Support paths.
6. Verify and read-only mount the DMG, inspect its three expected entries, and
   detach it in a trap.

All temporary files must be under `/tmp` and removed on exit.

- [ ] **Step 4: Make artifact verification part of the build**

At the end of `build-installer.sh`, invoke:

```bash
"$ROOT/Scripts/verify-installer.sh" "$VERSION"
```

The build must fail if any audit fails.

- [ ] **Step 5: Run full tests and artifact verification**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/silex-clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/silex-swiftpm-module-cache \
swift run --disable-sandbox SilexTestRunner
Scripts/build-installer.sh 0.1.0 1
Scripts/verify-installer.sh 0.1.0
```

Expected: all source audits and artifact audits pass.

- [ ] **Step 6: Commit**

```bash
git add Scripts Tests/SilexTestRunner/main.swift
git commit -m "test: enforce offline least-privilege distribution" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

### Task 8: Add optional Developer ID signing and notarization

**Files:**
- Modify: `Tests/SilexTestRunner/main.swift`
- Modify: `Scripts/build-app.sh`
- Modify: `Scripts/build-installer.sh`
- Modify: `Scripts/verify-installer.sh`

- [ ] **Step 1: Write failing signing-path tests**

Assert the scripts recognize:

```text
APP_SIGN_IDENTITY
INSTALLER_SIGN_IDENTITY
NOTARY_PROFILE
```

Assert `--options runtime --timestamp` is used only for non-ad-hoc application
signing, `productbuild --sign` is conditional, and notarization credentials are
referenced only by keychain profile name.

- [ ] **Step 2: Run the harness and verify RED**

Expected: notarization assertions fail.

- [ ] **Step 3: Implement conditional signing**

Sign smartctl and helper first, then the application. With a Developer ID
identity use:

```bash
codesign --force --sign "$APP_SIGN_IDENTITY" \
  --options runtime --timestamp <path>
```

With no identity use `--sign -` and no timestamp.

- [ ] **Step 4: Implement conditional notarization**

When `NOTARY_PROFILE` is set, require both signing identities, then:

```bash
xcrun notarytool submit "$PKG" \
  --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$PKG"
```

Create the DMG, submit it the same way, staple it, and validate both tickets.
Never print keychain contents or accept plaintext Apple credentials.

- [ ] **Step 5: Run local-path tests**

Run the harness and a local ad-hoc installer build without signing identities.

Expected: personal build succeeds and no network notarization command runs.
The Developer ID path is statically verified but not invoked without supplied
credentials.

- [ ] **Step 6: Commit**

```bash
git add Scripts Tests/SilexTestRunner/main.swift
git commit -m "build: support signed notarized distributions" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

### Task 9: Document operation, update, control, and recovery

**Files:**
- Modify: `README.md`
- Modify: `Packaging/README.txt`

- [ ] **Step 1: Write the failing documentation assertions**

Add a harness test requiring README coverage of:

```text
Scripts/build-installer.sh 0.1.0 1
/Applications/Silex.app
com.anon233.Silex.pkg
launchctl print system/com.anon233.Silex.SMARTService
System Settings
Background Items
offline
Developer ID
NOTARY_PROFILE
```

- [ ] **Step 2: Run the harness and verify RED**

Expected: documentation test fails.

- [ ] **Step 3: Update documentation**

Document:

- prerequisites and `SMARTCTL_PATH`;
- personal PKG/DMG build command;
- generated artifact paths;
- installation and Touch ID/password caveat;
- same-package in-place updates and downgrade rejection;
- daemon visibility in System Settings, Console, and `launchctl`;
- behavior when the daemon is disabled;
- uninstall and retained history;
- explicit offline and least-privilege policy;
- optional Developer ID and notarization environment variables.

- [ ] **Step 4: Run tests and inspect docs**

Run the standard harness and search for placeholder text:

```bash
rg -n "TBD|TODO|FIXME" README.md Packaging docs/superpowers
```

Expected: documentation test passes and no unresolved placeholders appear.

- [ ] **Step 5: Commit**

```bash
git add README.md Packaging/README.txt Tests/SilexTestRunner/main.swift
git commit -m "docs: explain personal installation and daemon control" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

### Task 10: Final reproducible build and review

**Files:**
- Verify only; modify files only if a test exposes a defect.

- [ ] **Step 1: Run the complete source test suite**

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/silex-clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/silex-swiftpm-module-cache \
swift run --disable-sandbox SilexTestRunner
```

Expected: every test prints `PASS` and the final count reports zero failures.

- [ ] **Step 2: Build all Swift targets**

```bash
env CLANG_MODULE_CACHE_PATH=/tmp/silex-clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/silex-swiftpm-module-cache \
swift build --disable-sandbox
```

Expected: build succeeds without compiler errors.

- [ ] **Step 3: Build the personal installer**

```bash
Scripts/build-installer.sh 0.1.0 1
```

Expected:

- `dist/Silex-0.1.0.pkg`
- `dist/Silex-0.1.0.dmg`

No installation or daemon loading occurs on the build Mac.

- [ ] **Step 4: Verify artifacts independently**

```bash
Scripts/verify-installer.sh 0.1.0
```

Expected: signatures, plists, payload paths, permissions, offline audit,
package expansion, and DMG mount inspection all pass.

- [ ] **Step 5: Review Git attribution and working tree**

```bash
git log --format='%(trailers:key=Co-authored-by,valueonly)' |
  grep -v '^$' |
  grep -v '^Codex <codex@openai.com>$'
git diff --check
git status --short --branch
```

Expected: no unexpected trailer values, no whitespace errors, and a clean
working tree after the final commit.

- [ ] **Step 6: Perform security-focused diff review**

Confirm:

- no network code or entitlement;
- no Homebrew command runs from the app;
- no app-side daemon registration;
- no package script accepts user paths or shell fragments;
- no package script deletes Application Support;
- no `launchctl enable`;
- root service still exposes only probe and fixed SMART collection;
- installer build itself never uses `sudo`, `installer`, or modifies system
  paths.

- [ ] **Step 7: Commit any review-only corrections**

If review found a defect, fix it test-first and commit:

```bash
git add <corrected-files>
git commit -m "fix: harden personal installer verification" \
  --trailer "Co-authored-by: Codex <codex@openai.com>"
```

If no correction was required, do not create an empty commit.
