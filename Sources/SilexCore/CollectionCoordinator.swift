import Foundation

public protocol SamplePersisting: Sendable {
    func insert(_ sample: DriveSample) throws
    func all() throws -> [DriveSample]
}

public protocol RulePersisting: Sendable {
    func save(_ rule: AlertRule) throws
    func all() throws -> [AlertRule]
}

extension SampleRepository: SamplePersisting {}
extension RuleRepository: RulePersisting {}

public struct CollectionOutcome: Equatable, Sendable {
    public let sample: DriveSample
    public let alerts: [AlertMatch]

    public init(sample: DriveSample, alerts: [AlertMatch]) {
        self.sample = sample
        self.alerts = alerts
    }
}

public struct CollectionCoordinator: Sendable {
    private let collector: any SMARTCollecting
    private let parser: SmartctlParser
    private let samples: any SamplePersisting
    private let rules: any RulePersisting
    private let notifier: any AlertNotifying
    private let engine: AlertEngine

    public init(
        collector: any SMARTCollecting,
        parser: SmartctlParser = SmartctlParser(),
        samples: any SamplePersisting,
        rules: any RulePersisting,
        notifier: any AlertNotifying,
        engine: AlertEngine = AlertEngine()
    ) {
        self.collector = collector
        self.parser = parser
        self.samples = samples
        self.rules = rules
        self.notifier = notifier
        self.engine = engine
    }

    public func collect(
        source: CollectionSource,
        at date: Date = .now
    ) async throws -> CollectionOutcome {
        let command = try await collector.collect()
        let sample = try parser.parse(
            data: command.stdout,
            source: source,
            collectedAt: date
        )
        try samples.insert(sample)

        let history = try samples.all()
        let storedRules = try rules.all()
        var matches: [AlertMatch] = []

        for var rule in storedRules {
            guard let match = engine.evaluate(rule, samples: history, now: date) else {
                continue
            }
            try await notifier.post(match)
            rule.lastTriggeredAt = date
            try rules.save(rule)
            matches.append(match)
        }

        return CollectionOutcome(sample: sample, alerts: matches)
    }

    public func test(
        rule: AlertRule,
        at date: Date = .now
    ) async throws -> AlertMatch {
        let match = engine.simulatedMatch(for: rule, now: date)
        try await notifier.post(match)
        return match
    }
}

