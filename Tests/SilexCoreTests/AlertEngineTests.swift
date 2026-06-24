import Foundation
import Testing
@testable import SilexCore

struct AlertEngineTests {
    private let engine = AlertEngine()
    private let now = Date(timeIntervalSince1970: 100_000)

    @Test
    func evaluatesEveryAggregation() throws {
        let samples = [
            makeSample(
                date: now.addingTimeInterval(-2 * 3_600),
                temperature: 20,
                writtenBytes: 2_000_000_000
            ),
            makeSample(
                date: now.addingTimeInterval(-3_600),
                temperature: 30,
                writtenBytes: 5_000_000_000
            ),
            makeSample(
                date: now,
                temperature: 40,
                writtenBytes: 8_000_000_000
            )
        ]

        #expect(try observed(.current, metric: .temperature, samples: samples) == 40)
        #expect(try observed(.increase, metric: .dataWritten, samples: samples) == 6)
        #expect(try observed(.ratePerHour, metric: .dataWritten, samples: samples) == 3)
        #expect(try observed(.average, metric: .temperature, samples: samples) == 30)
        #expect(try observed(.minimum, metric: .temperature, samples: samples) == 20)
        #expect(try observed(.maximum, metric: .temperature, samples: samples) == 40)
    }

    @Test
    func supportsEveryComparison() {
        #expect(engine.compare(11, .greaterThan, 10))
        #expect(engine.compare(10, .greaterThanOrEqual, 10))
        #expect(engine.compare(9, .lessThan, 10))
        #expect(engine.compare(10, .lessThanOrEqual, 10))
    }

    @Test
    func suppressesDisabledAndCoolingDownRules() {
        let sample = makeSample(date: now, temperature: 70)
        var disabled = rule(threshold: 60)
        disabled.isEnabled = false
        var coolingDown = rule(threshold: 60)
        coolingDown.lastTriggeredAt = now.addingTimeInterval(-3_600)

        #expect(engine.evaluate(disabled, samples: [sample], now: now) == nil)
        #expect(engine.evaluate(coolingDown, samples: [sample], now: now) == nil)
    }

    @Test
    func returnsMatchWithObservedValueWhenRuleTriggers() throws {
        let sample = makeSample(date: now, temperature: 70)
        let rule = rule(threshold: 60)

        let match = try #require(engine.evaluate(rule, samples: [sample], now: now))

        #expect(match.ruleID == rule.id)
        #expect(match.observedValue == 70)
        #expect(match.threshold == 60)
        #expect(match.triggeredAt == now)
    }

    @Test
    func simulatedMatchDoesNotNeedSamples() {
        let rule = rule(threshold: 60)

        let match = engine.simulatedMatch(for: rule, now: now)

        #expect(match.ruleID == rule.id)
        #expect(match.observedValue > rule.threshold)
        #expect(match.isSimulation)
    }

    private func observed(
        _ aggregation: RuleAggregation,
        metric: Metric,
        samples: [DriveSample]
    ) throws -> Double {
        let rule = AlertRule(
            name: "Rule",
            metric: metric,
            aggregation: aggregation,
            windowHours: 24,
            comparison: .greaterThan,
            threshold: -1,
            cooldownHours: 0,
            isEnabled: true
        )
        return try #require(engine.observedValue(for: rule, samples: samples, now: now))
    }

    private func rule(threshold: Double) -> AlertRule {
        AlertRule(
            name: "High temperature",
            metric: .temperature,
            aggregation: .current,
            windowHours: 24,
            comparison: .greaterThan,
            threshold: threshold,
            cooldownHours: 8,
            isEnabled: true
        )
    }
}

