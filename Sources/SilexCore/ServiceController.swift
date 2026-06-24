import Foundation
import ServiceManagement

public enum BackgroundServiceStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

public protocol ServiceRegistering: Sendable {
    var status: BackgroundServiceStatus { get }
    func register() throws
    func unregister() throws
}

public struct ServiceController: Sendable {
    private let registration: any ServiceRegistering

    public init() {
        registration = SMAppServiceRegistration()
    }

    public init(registration: any ServiceRegistering) {
        self.registration = registration
    }

    public var status: BackgroundServiceStatus {
        registration.status
    }

    public func enable() throws {
        try registration.register()
    }

    public func disable() throws {
        try registration.unregister()
    }

    public static func map(_ status: SMAppService.Status) -> BackgroundServiceStatus {
        switch status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .notFound
        @unknown default:
            .notFound
        }
    }
}

private final class SMAppServiceRegistration: ServiceRegistering, @unchecked Sendable {
    private var service: SMAppService {
        SMAppService.daemon(plistName: SMARTServiceConstants.launchDaemonPlistName)
    }

    var status: BackgroundServiceStatus {
        ServiceController.map(service.status)
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
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
