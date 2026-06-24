import Foundation

public enum RuleDraftValidationError: Equatable, Sendable {
    case emptyName
    case invalidAggregation
    case invalidThreshold
    case invalidWindow
    case invalidCooldown
}

public enum RuleDraftError: Error, Equatable, Sendable {
    case validation([RuleDraftValidationError])
}

public struct RuleDraft: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var metric: Metric
    public var aggregation: RuleAggregation
    public var windowHours: Double
    public var comparison: RuleComparison
    public var threshold: Double
    public var cooldownHours: Double
    public var isEnabled: Bool
    public let lastTriggeredAt: Date?

    public init(rule: AlertRule) {
        id = rule.id
        name = rule.name
        metric = rule.metric
        aggregation = rule.aggregation
        windowHours = rule.windowHours
        comparison = rule.comparison
        threshold = rule.threshold
        cooldownHours = rule.cooldownHours
        isEnabled = rule.isEnabled
        lastTriggeredAt = rule.lastTriggeredAt
    }

    public func validationErrors() -> [RuleDraftValidationError] {
        var errors: [RuleDraftValidationError] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        if !metric.allowedAggregations.contains(aggregation) {
            errors.append(.invalidAggregation)
        }
        if !threshold.isFinite {
            errors.append(.invalidThreshold)
        }
        if !windowHours.isFinite || windowHours < 0 {
            errors.append(.invalidWindow)
        }
        if !cooldownHours.isFinite || cooldownHours < 0 {
            errors.append(.invalidCooldown)
        }
        return errors
    }

    public func makeRule() throws -> AlertRule {
        let errors = validationErrors()
        guard errors.isEmpty else {
            throw RuleDraftError.validation(errors)
        }
        return AlertRule(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            metric: metric,
            aggregation: aggregation,
            windowHours: windowHours,
            comparison: comparison,
            threshold: threshold,
            cooldownHours: cooldownHours,
            isEnabled: isEnabled,
            lastTriggeredAt: lastTriggeredAt
        )
    }

    public func isDirty(comparedTo rule: AlertRule) -> Bool {
        (try? makeRule()) != rule
    }
}
