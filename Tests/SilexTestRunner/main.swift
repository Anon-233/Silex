import Foundation
import ServiceManagement
import SilexCore

struct HarnessFailure: Error, CustomStringConvertible {
    let description: String
}

struct HarnessTest {
    let name: String
    let body: () async throws -> Void
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw HarnessFailure(description: message)
    }
}

func requireEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    guard actual == expected else {
        throw HarnessFailure(description: "\(message): expected \(expected), got \(actual)")
    }
}

func sample(
    id: UUID = UUID(),
    date: Date,
    source: CollectionSource = .manual,
    temperature: Double = 30,
    readBytes: Int64 = 1_000_000,
    writtenBytes: Int64 = 2_000_000,
    spare: Double = 100,
    used: Double = 0
) -> DriveSample {
    DriveSample(
        id: id,
        collectedAt: date,
        source: source,
        modelName: "APPLE SSD",
        serialNumber: "serial",
        firmwareVersion: "firmware",
        nvmeVersion: "1.2",
        smartPassed: true,
        criticalWarning: 0,
        temperatureCelsius: temperature,
        availableSparePercent: spare,
        availableSpareThresholdPercent: 99,
        percentageUsed: used,
        dataReadBytes: readBytes,
        dataWrittenBytes: writtenBytes,
        hostReadCommands: 100,
        hostWriteCommands: 200,
        controllerBusyMinutes: 3,
        powerCycles: 10,
        powerOnHours: 20,
        unsafeShutdowns: 1,
        mediaErrors: 0,
        errorLogEntries: 0,
        smartctlExitStatus: 0,
        rawJSON: Data(#"{"sample":true}"#.utf8)
    )
}

func temporaryDatabase() throws -> Database {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SilexHarness-\(UUID().uuidString)", isDirectory: true)
    return try Database(url: directory.appendingPathComponent("silex.sqlite3"))
}

func appleFixture() throws -> Data {
    guard let url = Bundle.module.url(
        forResource: "apple-nvme",
        withExtension: "json",
        subdirectory: "Fixtures"
    ) else {
        throw HarnessFailure(description: "apple-nvme.json fixture is missing")
    }
    return try Data(contentsOf: url)
}

func runScript(_ path: String, _ arguments: [String]) throws -> String {
    let process = Process()
    let output = Pipe()
    let errors = Pipe()
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    process.executableURL = root.appendingPathComponent(path)
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = errors
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw HarnessFailure(
            description: String(
                decoding: errors.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
        )
    }
    return String(
        decoding: output.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
    ).trimmingCharacters(in: .whitespacesAndNewlines)
}

final class QueueCollector: SMARTCollecting, @unchecked Sendable {
    private var results: [SmartctlCommandResult]

    init(_ results: [SmartctlCommandResult]) {
        self.results = results
    }

    func collect() async throws -> SmartctlCommandResult {
        guard !results.isEmpty else {
            throw HarnessFailure(description: "collector queue is empty")
        }
        return results.removeFirst()
    }
}

final class RecordingNotifier: AlertNotifying, @unchecked Sendable {
    private(set) var matches: [AlertMatch] = []
    var sampleCount: (() throws -> Int)?
    private(set) var sampleCounts: [Int] = []

    func post(_ match: AlertMatch) async throws {
        matches.append(match)
        sampleCounts.append(try sampleCount?() ?? -1)
    }
}

struct NotifierFailure: Error, LocalizedError {
    var errorDescription: String? {
        "Notification delivery failed."
    }
}

final class FailingNotifier: AlertNotifying, @unchecked Sendable {
    private(set) var matches: [AlertMatch] = []

    func post(_ match: AlertMatch) async throws {
        matches.append(match)
        throw NotifierFailure()
    }
}

final class RecordingExecutor: ProcessExecuting, @unchecked Sendable {
    let result: ProcessResult
    private(set) var request: ProcessRequest?

    init(result: ProcessResult) {
        self.result = result
    }

    func run(_ request: ProcessRequest) throws -> ProcessResult {
        self.request = request
        return result
    }
}

final class RecordingCancellation: Cancellation, @unchecked Sendable {
    private(set) var calls = 0
    func cancel() { calls += 1 }
}

final class RecordingScheduler: OneShotScheduling, @unchecked Sendable {
    private(set) var dates: [Date] = []
    private(set) var tokens: [RecordingCancellation] = []

    func schedule(at date: Date, action: @escaping @Sendable () -> Void) -> any Cancellation {
        let token = RecordingCancellation()
        dates.append(date)
        tokens.append(token)
        return token
    }
}

final class FakeServiceProbe: ServiceProbing, @unchecked Sendable {
    let available: Bool

    init(available: Bool) {
        self.available = available
    }

    func isAvailable() async -> Bool {
        available
    }
}

let tests: [HarnessTest] = [
    HarnessTest(name: "smartctl parser decodes Apple NVMe JSON") {
        let data = try appleFixture()
        let parsed = try SmartctlParser().parse(
            data: data,
            source: .manual,
            collectedAt: Date(timeIntervalSince1970: 1_782_230_764)
        )
        try requireEqual(parsed.modelName, "APPLE SSD AP1024Z", "model")
        try requireEqual(parsed.temperatureCelsius, 30, "temperature")
        try requireEqual(parsed.dataReadBytes, 3_006_609 * 512_000, "read bytes")
        try requireEqual(parsed.dataWrittenBytes, 2_212_292 * 512_000, "written bytes")
        try requireEqual(parsed.rawJSON, data, "raw JSON")
    },
    HarnessTest(name: "smartctl parser accepts valid nonzero status") {
        let json = """
        {"smartctl":{"exit_status":4},"model_name":"APPLE SSD","smart_status":{"passed":false},
        "nvme_smart_health_information_log":{"critical_warning":1,"temperature":42}}
        """
        let parsed = try SmartctlParser().parse(
            data: Data(json.utf8),
            source: .scheduled,
            collectedAt: .now
        )
        try requireEqual(parsed.smartctlExitStatus, 4, "exit status")
        try require(!parsed.smartPassed, "failed SMART state must be preserved")
    },
    HarnessTest(name: "SQLite round trips samples, rules, and settings") {
        let database = try temporaryDatabase()
        let samples = SampleRepository(database: database)
        let rules = RuleRepository(database: database)
        let settings = SettingsRepository(database: database)
        let first = sample(date: Date(timeIntervalSince1970: 100))
        let second = sample(date: Date(timeIntervalSince1970: 200), source: .scheduled)
        try samples.insert(second)
        try samples.insert(first)
        try requireEqual(try samples.all(), [first, second], "sample ordering")

        let rule = AlertRule(
            name: "Warm", metric: .temperature, aggregation: .maximum,
            windowHours: 24, comparison: .greaterThan, threshold: 60,
            cooldownHours: 8, isEnabled: true
        )
        try rules.save(rule)
        try requireEqual(try rules.all(), [rule], "rule round trip")

        let value = AppSettings(
            collectionIntervalHours: 6,
            smartctlPath: "/opt/homebrew/bin/smartctl",
            language: .simplifiedChinese,
            notificationsEnabled: true,
            launchAtLogin: true
        )
        try settings.save(value)
        try requireEqual(try settings.load(), value, "settings round trip")
        try requireEqual(try database.schemaVersion(), 1, "schema version")
    },
    HarnessTest(name: "history ranges and rates use real timestamps") {
        let analyzer = HistoryAnalyzer()
        let now = Date(timeIntervalSince1970: 4_000_000)
        let values = [
            sample(date: now.addingTimeInterval(-40 * 86_400)),
            sample(date: now.addingTimeInterval(-10 * 86_400)),
            sample(date: now.addingTimeInterval(-23 * 3_600), writtenBytes: 2_000_000_000),
            sample(date: now.addingTimeInterval(-20.5 * 3_600), writtenBytes: 7_000_000_000)
        ]
        try requireEqual(analyzer.filtered(values, range: .hours24, now: now).count, 2, "24h count")
        try requireEqual(analyzer.filtered(values, range: .days30, now: now).count, 3, "30d count")
        let stats = analyzer.statistics(for: .dataWritten, samples: Array(values.suffix(2)))
        try requireEqual(stats.recentRatePerHour, 2, "irregular rate")
    },
    HarnessTest(name: "chart builder keeps read and write as separate ordered series") {
        let first = sample(
            date: Date(timeIntervalSince1970: 100),
            readBytes: 1_000_000_000_000,
            writtenBytes: 2_000_000_000_000
        )
        let second = sample(
            date: Date(timeIntervalSince1970: 200),
            readBytes: 3_000_000_000_000,
            writtenBytes: 4_000_000_000_000
        )
        let series = ChartSeriesBuilder().build(
            metrics: [.dataRead, .dataWritten],
            samples: [second, first],
            range: .all,
            now: second.collectedAt
        ) { metric, value in
            switch metric {
            case .dataRead, .dataWritten:
                value / 1_000
            default:
                value
            }
        }

        try requireEqual(
            series.map(\.metric),
            [.dataRead, .dataWritten],
            "read/write series identity"
        )
        try requireEqual(
            series[0].points.map(\.date),
            [first.collectedAt, second.collectedAt],
            "read point order"
        )
        try requireEqual(
            series[1].points.map(\.date),
            [first.collectedAt, second.collectedAt],
            "write point order"
        )
        try requireEqual(
            series[0].points.map(\.value),
            [1, 3],
            "read values"
        )
        try requireEqual(
            series[1].points.map(\.value),
            [2, 4],
            "write values"
        )
    },
    HarnessTest(name: "chart builder keeps wear metrics separate and deduplicates timestamps") {
        let duplicateDate = Date(timeIntervalSince1970: 100)
        let first = sample(date: duplicateDate, spare: 100, used: 0)
        let replacement = sample(date: duplicateDate, spare: 98, used: 2)
        let second = sample(
            date: Date(timeIntervalSince1970: 200),
            spare: 97,
            used: 3
        )
        let series = ChartSeriesBuilder().build(
            metrics: [.availableSpare, .percentageUsed, .availableSpareThreshold],
            samples: [first, replacement, second],
            range: .all,
            now: second.collectedAt
        )

        try requireEqual(
            series.map(\.metric),
            [.availableSpare, .percentageUsed, .availableSpareThreshold],
            "wear series identity"
        )
        try requireEqual(series[0].points.map(\.value), [98, 97], "spare deduplication")
        try requireEqual(series[1].points.map(\.value), [2, 3], "used deduplication")
        try requireEqual(series[2].points.map(\.value), [99, 99], "threshold series")
    },
    HarnessTest(name: "chart axis domains are finite and deterministic") {
        let builder = ChartAxisDomainBuilder()
        try requireEqual(
            builder.domain(values: [10, 20], kind: .nonnegative),
            ChartAxisDomain(lower: 9, upper: 21),
            "normal domain"
        )
        try requireEqual(
            builder.domain(values: [0, 0], kind: .nonnegative),
            ChartAxisDomain(lower: 0, upper: 1),
            "zero domain"
        )
        try requireEqual(
            builder.domain(values: [100, 100], kind: .percentage),
            ChartAxisDomain(lower: 99, upper: 100),
            "full percentage domain"
        )
        try requireEqual(
            builder.domain(values: [50, 50], kind: .percentage),
            ChartAxisDomain(lower: 47.5, upper: 52.5),
            "centered percentage domain"
        )
        try requireEqual(
            builder.domain(values: [], kind: .unconstrained),
            nil,
            "empty domain"
        )
    },
    HarnessTest(name: "alert engine evaluates aggregation and cooldown") {
        let engine = AlertEngine()
        let now = Date(timeIntervalSince1970: 100_000)
        let values = [
            sample(date: now.addingTimeInterval(-2 * 3_600), temperature: 20),
            sample(date: now, temperature: 40)
        ]
        var rule = AlertRule(
            name: "Warm", metric: .temperature, aggregation: .maximum,
            windowHours: 24, comparison: .greaterThan, threshold: 30,
            cooldownHours: 8, isEnabled: true
        )
        try require(engine.evaluate(rule, samples: values, now: now) != nil, "rule should trigger")
        rule.lastTriggeredAt = now.addingTimeInterval(-3_600)
        try require(engine.evaluate(rule, samples: values, now: now) == nil, "cooldown should suppress")
        try require(engine.simulatedMatch(for: rule, now: now).isSimulation, "simulation flag")
    },
    HarnessTest(name: "smartctl runner and bundled privileged policy are fixed") {
        let executor = RecordingExecutor(
            result: ProcessResult(stdout: Data("{}".utf8), stderr: Data(), exitStatus: 0)
        )
        _ = try SmartctlRunner(executor: executor).collect(
            executablePath: "/opt/homebrew/bin/smartctl"
        )
        try requireEqual(executor.request?.arguments, ["-j", "-x", "/dev/disk0"], "arguments")
        let serviceURL = URL(
            fileURLWithPath:
                "/Library/PrivilegedHelperTools/com.anon233.Silex.Daemon"
        )
        try requireEqual(
            PrivilegedSMARTPolicy.bundledExecutableURL(
                serviceExecutableURL: serviceURL
            ).path,
            "/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl",
            "installed smartctl path"
        )
    },
    HarnessTest(name: "service controller only probes package-owned daemon") {
        let available = ServiceController(
            probe: FakeServiceProbe(available: true)
        )
        let unavailable = ServiceController(
            probe: FakeServiceProbe(available: false)
        )
        try requireEqual(
            await available.status(),
            .available,
            "available service"
        )
        try requireEqual(
            await unavailable.status(),
            .unavailable,
            "unavailable service"
        )
        try require(SMARTConnectionPolicy.accepts(effectiveUserID: 501, consoleUserID: 501), "console user")
        try require(!SMARTConnectionPolicy.accepts(effectiveUserID: 0, consoleUserID: 501), "root client")
    },
    HarnessTest(name: "coordinator persists before notifying and simulation is safe") {
        let database = try temporaryDatabase()
        let samples = SampleRepository(database: database)
        let rules = RuleRepository(database: database)
        let notifier = RecordingNotifier()
        notifier.sampleCount = { try samples.all().count }
        let raw = try appleFixture()
        let collector = QueueCollector([
            SmartctlCommandResult(stdout: raw, stderr: Data(), exitStatus: 0)
        ])
        let rule = AlertRule(
            name: "Warm", metric: .temperature, aggregation: .current,
            windowHours: 24, comparison: .greaterThan, threshold: 20,
            cooldownHours: 0, isEnabled: true
        )
        try rules.save(rule)
        let coordinator = CollectionCoordinator(
            collector: collector,
            samples: samples,
            rules: rules,
            notifier: notifier
        )
        _ = try await coordinator.collect(
            source: .manual,
            at: Date(timeIntervalSince1970: 1_000)
        )
        try requireEqual(notifier.sampleCounts, [1], "sample count at notification")
        let before = try samples.all().count
        _ = try await coordinator.test(rule: rule, at: Date(timeIntervalSince1970: 2_000))
        try requireEqual(try samples.all().count, before, "simulation must not write samples")
    },
    HarnessTest(name: "conditional notifier obeys notification setting") {
        let rule = AlertRule(
            name: "Warm", metric: .temperature, aggregation: .current,
            windowHours: 24, comparison: .greaterThan, threshold: 20,
            cooldownHours: 0, isEnabled: true
        )
        let match = AlertEngine().simulatedMatch(
            for: rule,
            now: Date(timeIntervalSince1970: 1_000)
        )
        let recorder = RecordingNotifier()

        try await ConditionalAlertNotifier(
            isEnabled: false,
            notifier: recorder
        ).post(match)
        try requireEqual(recorder.matches.count, 0, "disabled notification calls")

        try await ConditionalAlertNotifier(
            isEnabled: true,
            notifier: recorder
        ).post(match)
        try requireEqual(recorder.matches, [match], "enabled notification calls")
    },
    HarnessTest(name: "notification failure does not discard collected alert state") {
        let database = try temporaryDatabase()
        let samples = SampleRepository(database: database)
        let rules = RuleRepository(database: database)
        let notifier = FailingNotifier()
        let collector = QueueCollector([
            SmartctlCommandResult(
                stdout: try appleFixture(),
                stderr: Data(),
                exitStatus: 0
            )
        ])
        let rule = AlertRule(
            name: "Warm", metric: .temperature, aggregation: .current,
            windowHours: 24, comparison: .greaterThan, threshold: 20,
            cooldownHours: 0, isEnabled: true
        )
        try rules.save(rule)
        let collectedAt = Date(timeIntervalSince1970: 2_000)

        let outcome = try await CollectionCoordinator(
            collector: collector,
            samples: samples,
            rules: rules,
            notifier: notifier
        ).collect(source: .manual, at: collectedAt)

        try requireEqual(outcome.alerts.count, 1, "collected alerts")
        try requireEqual(outcome.notificationFailures.count, 1, "delivery failures")
        try requireEqual(
            outcome.notificationFailures.first?.ruleID,
            rule.id,
            "delivery failure rule"
        )
        try requireEqual(
            try rules.all().first?.lastTriggeredAt,
            collectedAt,
            "trigger timestamp persists"
        )
        try requireEqual(try samples.all().count, 1, "sample remains persisted")
    },
    HarnessTest(name: "scheduler cancels prior timer and computes due date") {
        let clock = RecordingScheduler()
        let scheduler = CollectionScheduler(scheduler: clock)
        scheduler.schedule(at: Date(timeIntervalSince1970: 100)) {}
        scheduler.schedule(at: Date(timeIntervalSince1970: 200)) {}
        try requireEqual(clock.tokens[0].calls, 1, "first timer cancellation")
        let now = Date(timeIntervalSince1970: 100_000)
        let next = CollectionScheduler.nextCollectionDate(
            lastCollectedAt: now.addingTimeInterval(-2 * 3_600),
            intervalHours: 8,
            now: now
        )
        try requireEqual(next, now.addingTimeInterval(6 * 3_600), "next collection date")
    },
    HarnessTest(name: "schedule planning handles wake, startup, and interval changes") {
        let now = Date(timeIntervalSince1970: 100_000)
        let last = now.addingTimeInterval(-10 * 3_600)

        let wakePlan = CollectionSchedulePlanner.plan(
            lastCollectedAt: last,
            intervalHours: 8,
            now: now
        )
        try require(wakePlan.isDueNow, "overdue wake must collect immediately")
        try requireEqual(wakePlan.scheduledAt, now, "overdue wake date")

        let shortened = CollectionSchedulePlanner.plan(
            lastCollectedAt: last,
            intervalHours: 4,
            now: now
        )
        try require(shortened.isDueNow, "shortened overdue interval must collect immediately")

        let lengthened = CollectionSchedulePlanner.plan(
            lastCollectedAt: last,
            intervalHours: 12,
            now: now
        )
        try require(!lengthened.isDueNow, "lengthened interval must wait")
        try requireEqual(
            lengthened.scheduledAt,
            last.addingTimeInterval(12 * 3_600),
            "lengthened interval date"
        )

        let firstLaunch = CollectionSchedulePlanner.plan(
            lastCollectedAt: nil,
            intervalHours: 8,
            now: now
        )
        try require(firstLaunch.isDueNow, "first launch must collect immediately")
        try requireEqual(
            CollectionSchedulePlanner.normalizedIntervalHours(0),
            0.25,
            "minimum interval"
        )
    },
    HarnessTest(name: "page navigation is bounded and ignores blocked or vertical input") {
        var navigation = PageNavigationState(page: 1, pageCount: 6)
        try requireEqual(
            navigation.finishDrag(width: -80, height: 5, isBlocked: false),
            2,
            "horizontal advance"
        )
        try requireEqual(
            navigation.finishDrag(width: -90, height: 4, isBlocked: true),
            2,
            "blocked navigation"
        )
        try requireEqual(
            navigation.finishDrag(width: -80, height: 100, isBlocked: false),
            2,
            "vertical input"
        )
        navigation.go(to: 99)
        try requireEqual(navigation.page, 5, "upper page clamp")
        navigation.move(.next, isBlocked: false)
        try requireEqual(navigation.page, 5, "next boundary")
        navigation.go(to: -10)
        try requireEqual(navigation.page, 0, "lower page clamp")
        navigation.move(.previous, isBlocked: false)
        try requireEqual(navigation.page, 0, "previous boundary")
    },
    HarnessTest(name: "rule drafts validate fields and preserve persisted identity") {
        let id = UUID()
        let triggeredAt = Date(timeIntervalSince1970: 5_000)
        let rule = AlertRule(
            id: id,
            name: "Warm",
            metric: .temperature,
            aggregation: .maximum,
            windowHours: 24,
            comparison: .greaterThan,
            threshold: 60,
            cooldownHours: 8,
            isEnabled: true,
            lastTriggeredAt: triggeredAt
        )
        var valid = RuleDraft(rule: rule)
        try requireEqual(valid.validationErrors(), [], "valid draft")
        try requireEqual(try valid.makeRule(), rule, "rule reconstruction")
        try require(!valid.isDirty(comparedTo: rule), "unchanged draft")

        valid.threshold = 61
        try require(valid.isDirty(comparedTo: rule), "changed draft")

        var invalid = RuleDraft(rule: rule)
        invalid.name = " "
        invalid.metric = .availableSpareThreshold
        invalid.aggregation = .average
        invalid.threshold = .infinity
        invalid.windowHours = -1
        invalid.cooldownHours = -1
        try requireEqual(
            invalid.validationErrors(),
            [
                .emptyName,
                .invalidAggregation,
                .invalidThreshold,
                .invalidWindow,
                .invalidCooldown
            ],
            "invalid draft fields"
        )
        do {
            _ = try invalid.makeRule()
            throw HarnessFailure(description: "invalid draft unexpectedly created a rule")
        } catch let error as RuleDraftError {
            try requireEqual(
                error,
                .validation(invalid.validationErrors()),
                "draft validation error"
            )
        }
    },
    HarnessTest(name: "privileged service has a finite idle lifetime") {
        try requireEqual(
            PrivilegedServiceIdlePolicy.timeout,
            30,
            "privileged service idle timeout"
        )
    },
    HarnessTest(name: "exporter preserves JSON and stable CSV") {
        let value = sample(date: Date(timeIntervalSince1970: 1_000))
        let exporter = HistoryExporter()
        let json = try exporter.json(samples: [value])
        try requireEqual(try JSONDecoder.iso8601.decode([DriveSample].self, from: json), [value], "JSON")
        let csv = String(decoding: exporter.csv(samples: [value]), as: UTF8.self)
        try require(csv.hasPrefix("id,collectedAt,source,modelName"), "CSV header")
    },
    HarnessTest(name: "launch daemon plist is restricted") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let data = try Data(
            contentsOf: root.appendingPathComponent(
                "Resources/LaunchDaemons/com.anon233.Silex.Daemon.plist"
            )
        )
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = plist as? [String: Any] else {
            throw HarnessFailure(description: "daemon plist is not a dictionary")
        }
        try requireEqual(dictionary["UserName"] as? String, "root", "daemon user")
        try require(dictionary["KeepAlive"] == nil, "daemon must be on demand")
        try requireEqual(
            dictionary["ProgramArguments"] as? [String],
            [SMARTServiceConstants.installedServicePath],
            "fixed installed helper"
        )
        try require(dictionary["BundleProgram"] == nil, "not app-relative")
        try requireEqual(
            dictionary["AssociatedBundleIdentifiers"] as? [String],
            ["com.anon233.Silex"],
            "background item association"
        )
    },
    HarnessTest(name: "background service bundle has readable stable upgrade metadata") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let helperInfoURL = root.appendingPathComponent(
            "Resources/PrivilegedHelper/Info.plist"
        )
        let helperInfoData = try Data(contentsOf: helperInfoURL)
        let helperInfo = try PropertyListSerialization.propertyList(
            from: helperInfoData,
            format: nil
        ) as? [String: Any] ?? [:]
        try requireEqual(
            helperInfo["CFBundleIdentifier"] as? String,
            "com.anon233.Silex.Daemon",
            "stable helper identifier"
        )
        try requireEqual(
            helperInfo["CFBundleExecutable"] as? String,
            "SilexDaemon",
            "helper executable name"
        )
        try requireEqual(
            helperInfo["CFBundleDisplayName"] as? String,
            "Silex SMART Service",
            "default helper display name"
        )

        let english = try String(
            contentsOf: root.appendingPathComponent(
                "Resources/PrivilegedHelper/en.lproj/InfoPlist.strings"
            ),
            encoding: .utf8
        )
        let chinese = try String(
            contentsOf: root.appendingPathComponent(
                "Resources/PrivilegedHelper/zh-Hans.lproj/InfoPlist.strings"
            ),
            encoding: .utf8
        )
        try require(
            english.contains("\"Silex SMART Service\""),
            "English helper display name"
        )
        try require(
            chinese.contains("\"Silex SMART 后台服务\""),
            "Chinese helper display name"
        )

        let postinstall = try String(
            contentsOf: root.appendingPathComponent(
                "Packaging/Scripts/postinstall"
            ),
            encoding: .utf8
        )
        let uninstaller = try String(
            contentsOf: root.appendingPathComponent(
                "Packaging/Uninstall Silex.applescript"
            ),
            encoding: .utf8
        )
        let build = try String(
            contentsOf: root.appendingPathComponent(
                "Scripts/build-installer.sh"
            ),
            encoding: .utf8
        )
        let verifier = try String(
            contentsOf: root.appendingPathComponent(
                "Scripts/verify-installer.sh"
            ),
            encoding: .utf8
        )
        let helperBundlePath =
            "/Library/PrivilegedHelperTools/SilexDaemon.app"

        try require(
            SMARTServiceConstants.installedServicePath.hasPrefix(
                helperBundlePath
            ),
            "service executable is inside named helper bundle"
        )
        try require(
            postinstall.contains(helperBundlePath),
            "postinstall secures helper bundle"
        )
        try require(
            uninstaller.contains(helperBundlePath),
            "uninstaller contains helper bundle path"
        )
        try require(
            build.contains("Resources/PrivilegedHelper/Info.plist")
                && build.contains("SilexDaemon.app/Contents/MacOS")
                && build.contains("InfoPlist.strings"),
            "build assembles named helper bundle"
        )
        try require(
            verifier.contains("SilexDaemon.app")
                && verifier.contains("CFBundleDisplayName")
                && verifier.contains("PAYLOAD_HELPER_COUNT")
                && !verifier.contains("sfltool resetbtm"),
            "verifier enforces readable single helper"
        )
    },
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
        try require(
            !content.contains("enablePrivilegedService"),
            "no app registration"
        )
        let appModelContent = try String(
            contentsOf: root.appendingPathComponent("Sources/SilexApp/AppModel.swift"),
            encoding: .utf8
        )
        try require(
            !appModelContent.contains("brew install"),
            "no Homebrew auto-execution in AppModel"
        )
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
    },
    HarnessTest(name: "installer version comparison and downgrade policy are deterministic") {
        try requireEqual(
            try runScript(
                "Packaging/Scripts/version-compare.sh",
                ["0.1.0", "0.2.0"]
            ),
            "-1",
            "older version"
        )
        try requireEqual(
            try runScript(
                "Packaging/Scripts/version-compare.sh",
                ["1.2.3", "1.2.3"]
            ),
            "0",
            "equal version"
        )
        try requireEqual(
            try runScript(
                "Packaging/Scripts/version-compare.sh",
                ["2.0.0", "1.9.9"]
            ),
            "1",
            "newer version"
        )

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let preinstall = try String(
            contentsOf: root.appendingPathComponent(
                "Packaging/Scripts/preinstall.in"
            ),
            encoding: .utf8
        )
        try require(
            preinstall.contains("/Applications/Silex.app"),
            "fixed app path"
        )
        try require(
            preinstall.contains("@SILEX_VERSION@")
                && preinstall.contains("@SILEX_BUILD@"),
            "version placeholders"
        )
        try require(
            preinstall.contains("CFBundleShortVersionString")
                && preinstall.contains("CFBundleVersion"),
            "both versions must be compared"
        )
        try require(
            !preinstall.contains("Application Support"),
            "preinstall must preserve user data"
        )
    },
    HarnessTest(name: "package build uses stable identifiers and fixed payloads") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let distribution = try String(
            contentsOf: root.appendingPathComponent(
                "Packaging/Distribution.xml.in"
            ),
            encoding: .utf8
        )
        let postinstall = try String(
            contentsOf: root.appendingPathComponent(
                "Packaging/Scripts/postinstall"
            ),
            encoding: .utf8
        )
        let build = try String(
            contentsOf: root.appendingPathComponent(
                "Scripts/build-installer.sh"
            ),
            encoding: .utf8
        )

        try require(
            distribution.contains("com.anon233.Silex.pkg"),
            "stable package ID"
        )
        try require(distribution.contains("26.0"), "minimum macOS")
        try require(
            postinstall.contains("/Library/LaunchDaemons/"),
            "fixed daemon plist"
        )
        try require(
            !postinstall.contains("launchctl enable"),
            "preserve disabled state"
        )
        try require(
            postinstall.contains("print-disabled system"),
            "detect user disable"
        )
        try require(build.contains("pkgbuild"), "component package")
        try require(build.contains("productbuild"), "product package")
        try require(
            build.contains("--ownership recommended"),
            "root-owned install"
        )
        try require(
            build.contains("--component-plist")
                && build.contains("BundleIsRelocatable"),
            "app bundle must use explicit non-relocatable component metadata"
        )
        try require(
            build.contains("mktemp -d")
                && build.contains("installer-work.XXXXXX"),
            "each build must use an isolated staging directory"
        )
        for path in [
            "Applications/Silex.app",
            "Library/LaunchDaemons/com.anon233.Silex.Daemon.plist",
            "Library/PrivilegedHelperTools/SilexDaemon.app",
            "Library/PrivilegedHelperTools/com.anon233.Silex.smartctl"
        ] {
            try require(build.contains(path), "missing payload path \(path)")
        }
        try require(!build.contains("/usr/bin/sudo"), "build must not use sudo")
        try require(
            !build.contains("/usr/sbin/installer"),
            "build must not install its output"
        )
    },
    HarnessTest(name: "distribution includes authorized uninstall and DMG assembly") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let uninstaller = try String(
            contentsOf: root.appendingPathComponent(
                "Packaging/Uninstall Silex.applescript"
            ),
            encoding: .utf8
        )
        let instructions = try String(
            contentsOf: root.appendingPathComponent("Packaging/README.txt"),
            encoding: .utf8
        )
        let build = try String(
            contentsOf: root.appendingPathComponent(
                "Scripts/build-installer.sh"
            ),
            encoding: .utf8
        )

        try require(
            uninstaller.contains("with administrator privileges"),
            "authorized uninstall"
        )
        try require(
            uninstaller.contains(
                "system/com.anon233.Silex.Daemon"
            ),
            "fixed daemon label"
        )
        try require(
            uninstaller.contains("com.anon233.Silex.pkg"),
            "forget package receipt"
        )
        try require(
            uninstaller.contains("/Applications/Silex.app"),
            "remove fixed app path"
        )
        try require(
            !uninstaller.contains(
                "/bin/rm -rf ~/Library/Application Support/Silex"
            )
                && !uninstaller.contains(
                    "/bin/rm -rf \"$HOME/Library/Application Support/Silex\""
                ),
            "uninstaller must preserve history"
        )
        try require(
            instructions.contains("Install Silex.pkg")
                && instructions.contains("后台项目"),
            "bilingual install and daemon guidance"
        )
        try require(build.contains("osacompile"), "compile uninstaller")
        try require(build.contains("hdiutil create"), "create disk image")
        try require(
            build.contains("Install Silex.pkg")
                && build.contains("Uninstall Silex.app"),
            "expected DMG contents"
        )
    },
    HarnessTest(name: "source and packaging enforce offline least privilege") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceRoot = root.appendingPathComponent("Sources")
        let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )
        let bannedSourceText = [
            "URLSession",
            "import Network",
            "NWConnection",
            "import WebKit",
            "WKWebView",
            "http://",
            "https://",
            "brew install"
        ]
        let allowlist: Set<String> = ["SettingsView.swift"]
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else {
                continue
            }
            let source = try String(contentsOf: url, encoding: .utf8)
            for banned in bannedSourceText {
                guard !allowlist.contains(url.lastPathComponent) else {
                    continue
                }
                try require(
                    !source.contains(banned),
                    "\(url.lastPathComponent) contains \(banned)"
                )
            }
        }

        let entitlementsData = try Data(
            contentsOf: root.appendingPathComponent(
                "Resources/App/Silex.entitlements"
            )
        )
        let entitlements = try PropertyListSerialization.propertyList(
            from: entitlementsData,
            format: nil
        ) as? [String: Any] ?? [:]
        for key in entitlements.keys {
            let normalized = key.lowercased()
            try require(
                !normalized.contains("network")
                    && !normalized.contains("client")
                    && !normalized.contains("server"),
                "network entitlement \(key)"
            )
        }

        let infoData = try Data(
            contentsOf: root.appendingPathComponent(
                "Resources/App/Info.plist"
            )
        )
        let info = try PropertyListSerialization.propertyList(
            from: infoData,
            format: nil
        ) as? [String: Any] ?? [:]
        let privacyKeys = info.keys.filter {
            $0.hasPrefix("NS") && $0.hasSuffix("UsageDescription")
        }
        try requireEqual(privacyKeys, [], "unrelated privacy descriptions")

        let verifier = try String(
            contentsOf: root.appendingPathComponent(
                "Scripts/verify-installer.sh"
            ),
            encoding: .utf8
        )
        for required in [
            "codesign --verify",
            "otool -L",
            "pkgutil --expand-full",
            "xmllint --xpath",
            "relocate/bundle",
            "hdiutil verify",
            "hdiutil attach",
            "Network.framework",
            "CFNetwork.framework",
            "WebKit.framework"
        ] {
            try require(
                verifier.contains(required),
                "verifier missing \(required)"
            )
        }
    },
    HarnessTest(name: "signing and notarization are optional credentialed paths") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let buildApp = try String(
            contentsOf: root.appendingPathComponent("Scripts/build-app.sh"),
            encoding: .utf8
        )
        let buildInstaller = try String(
            contentsOf: root.appendingPathComponent(
                "Scripts/build-installer.sh"
            ),
            encoding: .utf8
        )
        let combined = buildApp + buildInstaller
        for input in [
            "APP_SIGN_IDENTITY",
            "INSTALLER_SIGN_IDENTITY",
            "NOTARY_PROFILE"
        ] {
            try require(combined.contains(input), "missing \(input)")
        }
        try require(
            buildApp.contains("--options runtime")
                && buildApp.contains("--timestamp"),
            "hardened Developer ID app signing"
        )
        try require(
            buildInstaller.contains("notarytool submit")
                && buildInstaller.contains("--keychain-profile")
                && buildInstaller.contains("stapler staple"),
            "keychain-profile notarization"
        )
        for plaintextCredential in [
            "--apple-id",
            "--password",
            "--team-id"
        ] {
            try require(
                !buildInstaller.contains(plaintextCredential),
                "plaintext credential option \(plaintextCredential)"
            )
        }
    },
    HarnessTest(name: "README documents personal installation and daemon control") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let readme = try String(
            contentsOf: root.appendingPathComponent("README.md"),
            encoding: .utf8
        )
        for required in [
            "Scripts/build-installer.sh 0.1.0 1",
            "/Applications/Silex.app",
            "com.anon233.Silex.pkg",
            "launchctl print system/com.anon233.Silex.Daemon",
            "System Settings",
            "Background Items",
            "offline",
            "Developer ID",
            "NOTARY_PROFILE"
        ] {
            try require(readme.contains(required), "README missing \(required)")
        }
    },
    HarnessTest(name: "English and Chinese localization keys match") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/SilexApp/Resources")
        func keys(_ path: String) throws -> Set<String> {
            let content = try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
            return Set(content.split(separator: "\n").compactMap { line in
                let text = line.trimmingCharacters(in: .whitespaces)
                guard text.hasPrefix("\""), let end = text.dropFirst().firstIndex(of: "\"") else {
                    return nil
                }
                return String(text[text.index(after: text.startIndex)..<end])
            })
        }
        let english = try keys("en.lproj/Localizable.strings")
        let chinese = try keys("zh-Hans.lproj/Localizable.strings")
        try requireEqual(english, chinese, "localization key parity")
        try require(english.contains("action.collect"), "required localization key")
        for required in [
            "aggregation.current",
            "aggregation.ratePerHour",
            "comparison.greaterThan",
            "dialog.deleteHistory.title",
            "dialog.unsavedRules.title",
            "result.ruleTest.title",
            "result.ruleTest.notificationDisabled",
            "overview.alerts",
            "overview.device",
            "status.nextCollection"
        ] {
            try require(english.contains(required), "missing localization key \(required)")
        }
    },
    HarnessTest(name: "app model exposes live presentation and notification policy") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appModel = try String(
            contentsOf: root.appendingPathComponent("Sources/SilexApp/AppModel.swift"),
            encoding: .utf8
        )
        let main = try String(
            contentsOf: root.appendingPathComponent("Sources/SilexApp/main.swift"),
            encoding: .utf8
        )
        let localization = try String(
            contentsOf: root.appendingPathComponent("Sources/SilexApp/Localization.swift"),
            encoding: .utf8
        )
        let ruleOverlay = try String(
            contentsOf: root.appendingPathComponent("Sources/SilexApp/Views/RuleOverlay.swift"),
            encoding: .utf8
        )

        try require(
            appModel.contains("@Published var presentedAlert"),
            "app alert presentation state"
        )
        try require(
            appModel.contains("@Published var ruleTestPresentation"),
            "rule test presentation state"
        )
        try require(
            appModel.contains("ConditionalAlertNotifier")
                && appModel.contains("settings.notificationsEnabled"),
            "notification setting policy"
        )
        try require(
            (main + localization).contains(".environment(\\.locale, model.locale)"),
            "language change must propagate locale environment"
        )
        for hardCoded in [
            "\"Current\"",
            "\"Increase\"",
            "\"Rate/h\"",
            "\"Average\"",
            "\"Minimum\"",
            "\"Maximum\""
        ] {
            try require(
                !ruleOverlay.contains(hardCoded),
                "hard-coded aggregation label \(hardCoded)"
            )
        }
    },
    HarnessTest(name: "window shell uses native input without arrow buttons") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let mainWindow = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/SilexApp/Views/MainWindowView.swift"
            ),
            encoding: .utf8
        )
        let configurator = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/SilexApp/Views/WindowConfigurator.swift"
            ),
            encoding: .utf8
        )
        let appMain = try String(
            contentsOf: root.appendingPathComponent("Sources/SilexApp/main.swift"),
            encoding: .utf8
        )

        for removed in [
            "chevron.left",
            "chevron.right",
            "action.previous",
            "action.next"
        ] {
            try require(!mainWindow.contains(removed), "removed shell control \(removed)")
        }
        try require(
            mainWindow.contains("WindowInputAdapter"),
            "window-scoped input adapter"
        )
        try require(
            mainWindow.contains("ForEach(0..<model.pageCount"),
            "clickable page indicators"
        )
        try require(
            configurator.contains("width: 760")
                && configurator.contains("height: 570"),
            "minimum content size"
        )
        try require(
            appMain.contains("width: 900")
                && appMain.contains("height: 675"),
            "default content size"
        )
    },
    HarnessTest(name: "overview and trend views match approved metric contract") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let overview = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/SilexApp/Views/OverviewView.swift"
            ),
            encoding: .utf8
        )
        let trend = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/SilexApp/Views/TrendPageView.swift"
            ),
            encoding: .utf8
        )
        let presentationURL = root.appendingPathComponent(
            "Sources/SilexApp/MetricPresentation.swift"
        )
        try require(
            FileManager.default.fileExists(atPath: presentationURL.path),
            "central metric presentation mapping"
        )
        let presentation = try String(
            contentsOf: presentationURL,
            encoding: .utf8
        )

        for approved in [
            "overview.temperature",
            "overview.spare",
            "overview.used",
            "overview.read",
            "overview.written",
            "overview.powerCycles",
            "overview.unsafeShutdowns",
            "overview.mediaErrors",
            "overview.alerts",
            "overview.device"
        ] {
            try require(overview.contains(approved), "overview metric \(approved)")
        }
        for removed in [
            "internaldrive",
            "thermometer.medium",
            "gauge.with.dots",
            "count: 4"
        ] {
            try require(!overview.contains(removed), "removed overview layout \(removed)")
        }
        try require(
            trend.contains("[.powerCycles, .unsafeShutdowns, .mediaErrors]"),
            "event metrics"
        )
        try require(!trend.contains(".errorLogEntries]"), "no error log event series")
        try require(
            trend.contains("ChartSeriesBuilder"),
            "prepared chart series"
        )
        try require(
            trend.contains("series: .value"),
            "explicit Swift Charts series"
        )
        try require(
            trend.contains("SpatialTapGesture")
                && !trend.contains("DragGesture(minimumDistance: 0)"),
            "chart click does not consume page drag"
        )
        for mapping in [
            "case .dataWritten:",
            "case .temperature, .availableSpare:",
            "case .percentageUsed:",
            "case .availableSpareThreshold, .unsafeShutdowns:",
            "case .mediaErrors:"
        ] {
            try require(presentation.contains(mapping), "metric presentation \(mapping)")
        }
    },
    HarnessTest(name: "native visual tokens faithfully map the HTML prototype") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let themeURL = root.appendingPathComponent(
            "Sources/SilexApp/SilexTheme.swift"
        )
        try require(
            FileManager.default.fileExists(atPath: themeURL.path),
            "shared HTML-derived theme"
        )
        let theme = try String(contentsOf: themeURL, encoding: .utf8)
        let mainWindow = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/SilexApp/Views/MainWindowView.swift"
            ),
            encoding: .utf8
        )
        let overview = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/SilexApp/Views/OverviewView.swift"
            ),
            encoding: .utf8
        )
        let card = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/SilexApp/Views/OverviewMetricCard.swift"
            ),
            encoding: .utf8
        )

        for token in [
            "0xEEF2F6",
            "0xFFFFFF",
            "0xF8FAFC",
            "0xD6DEE9",
            "0x142033",
            "0x64748B",
            "0x2563EB",
            "0x16A34A"
        ] {
            try require(theme.contains(token), "HTML color token \(token)")
        }
        try require(
            mainWindow.contains("VStack(spacing: 8)")
                && mainWindow.contains(".frame(height: 44)")
                && mainWindow.contains(".frame(width: 28, height: 28)"),
            "HTML shell dimensions"
        )
        try require(
            mainWindow.contains("headerSubtitle")
                && mainWindow.contains("/dev/disk0")
                && mainWindow.contains("action.rules"),
            "complete HTML toolbar content"
        )
        try require(
            !mainWindow.contains("if model.currentPage >= 2"),
            "rules button is available from overview"
        )
        try require(
            overview.contains(".font(.system(size: 28")
                && overview.contains("SilexTheme.green")
                && overview.contains(".frame(height: 54)"),
            "HTML health status hierarchy"
        )
        try require(
            card.contains("SilexTheme.soft")
                && card.contains("size: 22")
                && card.contains("alignment: .leading")
                && !card.contains("Spacer(minLength: 0)")
                && !card.contains(".topLeading"),
            "HTML vertically centered metric card"
        )
    },
    HarnessTest(name: "settings and rules use confirmed functional workflows") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let settings = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/SilexApp/Views/SettingsView.swift"
            ),
            encoding: .utf8
        )
        let rules = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/SilexApp/Views/RuleOverlay.swift"
            ),
            encoding: .utf8
        )
        let mainWindow = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/SilexApp/Views/MainWindowView.swift"
            ),
            encoding: .utf8
        )

        try require(
            settings.contains("confirmationDialog")
                && settings.contains("dialog.deleteHistory.title"),
            "delete history confirmation"
        )
        for action in [
            "model.saveSettings()",
            "model.refreshServiceStatus()",
            "model.openBackgroundItemsSettings()",
            "model.showStorageInFinder()",
            "model.exportJSON()",
            "model.exportCSV()",
            "model.deleteHistory()"
        ] {
            try require(settings.contains(action), "settings action \(action)")
        }
        try require(!settings.contains("model.lastError"), "no raw settings error text")
        try require(rules.contains("RuleDraft"), "draft rule editing")
        try require(!rules.contains("ForEach($model.rules)"), "no direct persisted rule binding")
        try require(
            rules.contains("dialog.unsavedRules.title")
                && rules.contains("dialog.deleteRule.title")
                && rules.contains("confirmationDialog"),
            "rule confirmations"
        )
        try require(
            rules.contains("model.testRule")
                && mainWindow.contains("$model.ruleTestPresentation"),
            "visible rule test result"
        )
        if
            let saveStart = rules.range(of: "private func saveDraft"),
            let testStart = rules.range(
                of: "private func testDraft",
                range: saveStart.upperBound..<rules.endIndex
            )
        {
            let saveBody = rules[saveStart.lowerBound..<testStart.lowerBound]
            try require(
                !saveBody.contains("reloadDrafts()"),
                "saving one rule must preserve other drafts"
            )
            try require(
                saveBody.contains("baselineRules"),
                "saved draft updates its baseline"
            )
        } else {
            throw HarnessFailure(description: "rule save function boundaries missing")
        }
    },
    HarnessTest(name: "app packaging metadata is native and non-Dock") {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let infoURL = root.appendingPathComponent("Resources/App/Info.plist")
        let data = try Data(contentsOf: infoURL)
        guard
            let info = try PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any]
        else {
            throw HarnessFailure(description: "Info.plist is not a dictionary")
        }
        try requireEqual(info["CFBundleIdentifier"] as? String, "com.anon233.Silex", "bundle ID")
        try requireEqual(info["CFBundleExecutable"] as? String, "Silex", "executable")
        try requireEqual(info["LSMinimumSystemVersion"] as? String, "26.0", "minimum system")
        try requireEqual(info["LSUIElement"] as? Bool, true, "menu bar app")
        try require(
            FileManager.default.isExecutableFile(
                atPath: root.appendingPathComponent("Scripts/build-app.sh").path
            ),
            "build-app.sh must be executable"
        )
        let script = try String(
            contentsOf: root.appendingPathComponent("Scripts/build-app.sh"),
            encoding: .utf8
        )
        try require(
            !script.contains("$BIN_PATH/SilexDaemon")
                && !script.contains("PrivilegedHelperTools/smartctl")
                && !script.contains("Library/LaunchDaemons"),
            "application bundle must not contain system daemon payloads"
        )
    }
]

extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

Task {
    var failures = 0
    for test in tests {
        do {
            try await test.body()
            print("PASS \(test.name)")
        } catch {
            failures += 1
            print("FAIL \(test.name): \(error)")
        }
    }
    print("\(tests.count - failures)/\(tests.count) tests passed")
    exit(failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE)
}
dispatchMain()
