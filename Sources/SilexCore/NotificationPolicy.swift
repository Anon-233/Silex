import Foundation

public struct ConditionalAlertNotifier: AlertNotifying {
    public let isEnabled: Bool
    public let notifier: any AlertNotifying

    public init(
        isEnabled: Bool,
        notifier: any AlertNotifying
    ) {
        self.isEnabled = isEnabled
        self.notifier = notifier
    }

    public func post(_ match: AlertMatch) async throws {
        guard isEnabled else {
            return
        }
        try await notifier.post(match)
    }
}

public struct AlertDeliveryFailure: Equatable, Sendable {
    public let ruleID: UUID
    public let message: String

    public init(ruleID: UUID, message: String) {
        self.ruleID = ruleID
        self.message = message
    }
}
