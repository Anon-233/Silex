import Foundation
import SilexCore

struct AppAlert: Identifiable, Equatable {
    enum Kind: Equatable {
        case error
        case success
        case serviceUnavailable
    }

    let id = UUID()
    let kind: Kind
    let titleKey: String
    let message: String
}

struct RuleTestPresentation: Identifiable, Equatable {
    enum NotificationStatus: Equatable {
        case disabled
        case delivered
        case failed(String)
    }

    let id = UUID()
    let ruleName: String
    let metric: Metric
    let observedValue: Double
    let comparison: RuleComparison
    let threshold: Double
    let notificationStatus: NotificationStatus
}
