import Foundation

public enum BackgroundServiceStatus: Equatable, Sendable {
    case available
    case unavailable
}

public protocol ServiceProbing: Sendable {
    func isAvailable() async -> Bool
}

extension SMARTServiceClient: ServiceProbing {
    public func isAvailable() async -> Bool {
        await probe()
    }
}

public struct ServiceController: Sendable {
    private let probe: any ServiceProbing

    public init() {
        probe = SMARTServiceClient()
    }

    public init(probe: any ServiceProbing) {
        self.probe = probe
    }

    public func status() async -> BackgroundServiceStatus {
        await probe.isAvailable() ? .available : .unavailable
    }
}

public enum SMARTConnectionPolicy {
    public static func accepts(
        effectiveUserID: UInt32,
        consoleUserID: UInt32?
    ) -> Bool {
        guard effectiveUserID != 0, let consoleUserID else {
            return false
        }
        return effectiveUserID == consoleUserID
    }
}

public enum PrivilegedServiceIdlePolicy {
    public static let timeout: TimeInterval = 30
}
