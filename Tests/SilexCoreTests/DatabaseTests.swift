import Foundation
import Testing
@testable import SilexCore

struct DatabaseTests {
    @Test
    func createsSchemaAndRoundTripsSamplesInDateOrder() throws {
        let context = try DatabaseTestContext()
        let repository = SampleRepository(database: context.database)
        let later = makeSample(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            date: Date(timeIntervalSince1970: 200),
            source: .scheduled,
            temperature: 35
        )
        let earlier = makeSample(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            date: Date(timeIntervalSince1970: 100),
            temperature: 25
        )

        try repository.insert(later)
        try repository.insert(earlier)

        let samples = try repository.all()
        #expect(samples == [earlier, later])
        #expect(try context.database.schemaVersion() == 1)
    }

    @Test
    func queriesSamplesSinceDateAndDeletesHistory() throws {
        let context = try DatabaseTestContext()
        let repository = SampleRepository(database: context.database)
        try repository.insert(makeSample(date: Date(timeIntervalSince1970: 100)))
        try repository.insert(makeSample(date: Date(timeIntervalSince1970: 200)))

        let recent = try repository.samples(since: Date(timeIntervalSince1970: 150))
        #expect(recent.count == 1)
        #expect(recent.first?.collectedAt == Date(timeIntervalSince1970: 200))

        try repository.deleteAll()
        #expect(try repository.all().isEmpty)
    }

    @Test
    func createsUpdatesListsAndDeletesRules() throws {
        let context = try DatabaseTestContext()
        let repository = RuleRepository(database: context.database)
        var rule = AlertRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            name: "High temperature",
            metric: .temperature,
            aggregation: .maximum,
            windowHours: 24,
            comparison: .greaterThan,
            threshold: 60,
            cooldownHours: 8,
            isEnabled: true
        )

        try repository.save(rule)
        #expect(try repository.all() == [rule])

        rule.threshold = 55
        rule.lastTriggeredAt = Date(timeIntervalSince1970: 300)
        try repository.save(rule)
        #expect(try repository.all() == [rule])

        try repository.delete(id: rule.id)
        #expect(try repository.all().isEmpty)
    }

    @Test
    func roundTripsSharedSettings() throws {
        let context = try DatabaseTestContext()
        let repository = SettingsRepository(database: context.database)
        let settings = AppSettings(
            collectionIntervalHours: 6,
            smartctlPath: "/opt/homebrew/bin/smartctl",
            language: .simplifiedChinese,
            notificationsEnabled: true,
            launchAtLogin: true
        )

        try repository.save(settings)

        #expect(try repository.load() == settings)
    }
}

private struct DatabaseTestContext {
    let directory: URL
    let database: Database

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SilexTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        database = try Database(url: directory.appendingPathComponent("silex.sqlite3"))
    }
}

