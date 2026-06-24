import Foundation
import Testing
@testable import SilexCore

struct CollectionCoordinatorTests {
    @Test
    func manualAndScheduledCollectionsSharePersistenceAndAlertPipeline() async throws {
        let context = try CoordinatorTestContext()
        let rawJSON = try fixtureData()
        let collector = QueueCollector(results: [
            SmartctlCommandResult(stdout: rawJSON, stderr: Data(), exitStatus: 0),
            SmartctlCommandResult(stdout: rawJSON, stderr: Data(), exitStatus: 0)
        ])
        let notifier = RecordingNotifier()
        notifier.sampleCount = { try context.samples.all().count }
        let rule = AlertRule(
            name: "Warm drive",
            metric: .temperature,
            aggregation: .current,
            windowHours: 24,
            comparison: .greaterThan,
            threshold: 20,
            cooldownHours: 0,
            isEnabled: true
        )
        try context.rules.save(rule)
        let coordinator = CollectionCoordinator(
            collector: collector,
            samples: context.samples,
            rules: context.rules,
            notifier: notifier
        )

        _ = try await coordinator.collect(
            source: .manual,
            at: Date(timeIntervalSince1970: 1_000)
        )
        _ = try await coordinator.collect(
            source: .scheduled,
            at: Date(timeIntervalSince1970: 2_000)
        )

        let stored = try context.samples.all()
        #expect(stored.map(\.source) == [.manual, .scheduled])
        #expect(notifier.matches.count == 2)
        #expect(notifier.sampleCountsAtPost == [1, 2])
    }

    @Test
    func simulatedAlertPostsNotificationWithoutWritingSample() async throws {
        let context = try CoordinatorTestContext()
        let notifier = RecordingNotifier()
        let coordinator = CollectionCoordinator(
            collector: QueueCollector(results: []),
            samples: context.samples,
            rules: context.rules,
            notifier: notifier
        )
        let rule = AlertRule(
            name: "Test",
            metric: .temperature,
            aggregation: .current,
            windowHours: 24,
            comparison: .greaterThan,
            threshold: 60,
            cooldownHours: 8,
            isEnabled: true
        )

        let match = try await coordinator.test(rule: rule, at: Date(timeIntervalSince1970: 3_000))

        #expect(match.isSimulation)
        #expect(notifier.matches == [match])
        #expect(try context.samples.all().isEmpty)
    }

    private func fixtureData() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "apple-nvme", withExtension: "json", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }
}

private struct CoordinatorTestContext {
    let database: Database
    let samples: SampleRepository
    let rules: RuleRepository

    init() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SilexCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
        database = try Database(url: directory.appendingPathComponent("silex.sqlite3"))
        samples = SampleRepository(database: database)
        rules = RuleRepository(database: database)
    }
}

private final class QueueCollector: SMARTCollecting, @unchecked Sendable {
    private var results: [SmartctlCommandResult]

    init(results: [SmartctlCommandResult]) {
        self.results = results
    }

    func collect() async throws -> SmartctlCommandResult {
        results.removeFirst()
    }
}

private final class RecordingNotifier: AlertNotifying, @unchecked Sendable {
    private(set) var matches: [AlertMatch] = []
    private(set) var sampleCountsAtPost: [Int] = []
    var sampleCount: (() throws -> Int)?

    func post(_ match: AlertMatch) async throws {
        matches.append(match)
        sampleCountsAtPost.append(try sampleCount?() ?? matches.count)
    }
}
