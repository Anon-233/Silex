import Foundation
import UserNotifications

public protocol AlertNotifying: Sendable {
    func post(_ match: AlertMatch) async throws
}

public enum NotificationClientError: Error, LocalizedError {
    case permissionDenied

    public var errorDescription: String? {
        "Notification permission was denied."
    }
}

public struct SystemNotificationClient: AlertNotifying {
    public init() {}

    public func post(_ match: AlertMatch) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await requestAuthorization(center)
        guard granted else {
            throw NotificationClientError.permissionDenied
        }

        let content = UNMutableNotificationContent()
        content.title = match.isSimulation ? "Silex Test Alert" : "Silex Alert"
        content.body = String(
            format: "%@: %.2f %@ (threshold %.2f)",
            match.ruleName,
            match.observedValue,
            match.metric.unit,
            match.threshold
        )
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(match.ruleID.uuidString)-\(match.triggeredAt.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try await add(request, to: center)
    }

    private func requestAuthorization(
        _ center: UNUserNotificationCenter
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func add(
        _ request: UNNotificationRequest,
        to center: UNUserNotificationCenter
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
