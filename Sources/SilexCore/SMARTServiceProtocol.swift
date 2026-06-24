import Foundation

public enum SMARTServiceConstants {
    public static let machServiceName = "com.anon233.Silex.SMARTService"
    public static let launchDaemonPlistName = "com.anon233.Silex.SMARTService.plist"
}

public enum PrivilegedSMARTPolicy {
    public static let bundledExecutableName = "smartctl"

    public static func bundledExecutableURL(
        serviceExecutableURL: URL
    ) -> URL {
        serviceExecutableURL
            .deletingLastPathComponent()
            .appendingPathComponent(bundledExecutableName)
    }

    public static func invocation(
        serviceExecutableURL: URL
    ) -> ProcessRequest {
        return ProcessRequest(
            executableURL: bundledExecutableURL(
                serviceExecutableURL: serviceExecutableURL
            ),
            arguments: ["-j", "-x", "/dev/disk0"]
        )
    }
}

@objc(SilexSMARTServiceProtocol)
public protocol SMARTServiceProtocol {
    func collectBuiltInDrive(
        reply: @escaping (NSData?, NSNumber, NSString?) -> Void
    )
}

public protocol SMARTCollecting: Sendable {
    func collect() async throws -> SmartctlCommandResult
}
