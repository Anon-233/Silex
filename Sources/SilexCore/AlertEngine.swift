import Foundation

public struct AlertMatch: Equatable, Sendable {
    public let ruleID: UUID
    public let ruleName: String
    public let metric: Metric
    public let observedValue: Double
    public let threshold: Double
    public let triggeredAt: Date
    public let isSimulation: Bool

    public init(
        ruleID: UUID,
        ruleName: String,
        metric: Metric,
        observedValue: Double,
        threshold: Double,
        triggeredAt: Date,
        isSimulation: Bool
    ) {
        self.ruleID = ruleID
        self.ruleName = ruleName
        self.metric = metric
        self.observedValue = observedValue
        self.threshold = threshold
        self.triggeredAt = triggeredAt
        self.isSimulation = isSimulation
    }
}

public struct AlertEngine: Sendable {
    private let analyzer = HistoryAnalyzer()

    public init() {}

    public func evaluate(
        _ rule: AlertRule,
        samples: [DriveSample],
        now: Date
    ) -> AlertMatch? {
        guard rule.isEnabled, !isCoolingDown(rule, now: now) else {
            return nil
        }
        guard let observed = observedValue(for: rule, samples: samples) else {
            return nil
        }
        guard compare(observed, rule.comparison, rule.threshold) else {
            return nil
        }
        return AlertMatch(
            ruleID: rule.id,
            ruleName: rule.name,
            metric: rule.metric,
            observedValue: observed,
            threshold: rule.threshold,
            triggeredAt: now,
            isSimulation: false
        )
    }

    public func observedValue(
        for rule: AlertRule,
        samples: [DriveSample]
    ) -> Double? {
        let sorted = samples.sorted { $0.collectedAt < $1.collectedAt }
        let statistics = analyzer.statistics(for: rule.metric, samples: sorted)

        switch rule.aggregation {
        case .current:
            return statistics.latest
        case .increase:
            let values = sorted.compactMap { rule.metric.value(in: $0) }
            guard let first = values.first, let last = values.last, values.count >= 2 else {
                return nil
            }
            return last - first
        case .ratePerHour:
            return statistics.averageRatePerHour
        case .average:
            return statistics.average
        case .minimum:
            return statistics.minimum
        case .maximum:
            return statistics.maximum
        }
    }

    public func compare(
        _ observed: Double,
        _ comparison: RuleComparison,
        _ threshold: Double
    ) -> Bool {
        switch comparison {
        case .greaterThan:
            observed > threshold
        case .greaterThanOrEqual:
            observed >= threshold
        case .lessThan:
            observed < threshold
        case .lessThanOrEqual:
            observed <= threshold
        }
    }

    public func simulatedMatch(for rule: AlertRule, now: Date) -> AlertMatch {
        let difference = max(abs(rule.threshold) * 0.1, 1)
        let observed: Double
        switch rule.comparison {
        case .greaterThan, .greaterThanOrEqual:
            observed = rule.threshold + difference
        case .lessThan, .lessThanOrEqual:
            observed = rule.threshold - difference
        }

        return AlertMatch(
            ruleID: rule.id,
            ruleName: rule.name,
            metric: rule.metric,
            observedValue: observed,
            threshold: rule.threshold,
            triggeredAt: now,
            isSimulation: true
        )
    }

    private func isCoolingDown(_ rule: AlertRule, now: Date) -> Bool {
        guard let lastTriggeredAt = rule.lastTriggeredAt else {
            return false
        }
        return now.timeIntervalSince(lastTriggeredAt) < max(rule.cooldownHours, 0) * 3_600
    }
}
