import Foundation

public enum SMARTServiceConstants {
    public static let machServiceName = "com.anon233.Silex.SMARTService"
    public static let launchDaemonPlistName = "com.anon233.Silex.SMARTService.plist"
}

public enum PrivilegedSMARTPolicy {
    public static let allowedExecutablePaths = Set(SmartctlLocator.commonPaths)

    public static func isAllowedExecutable(_ path: String) -> Bool {
        allowedExecutablePaths.contains(path)
    }

    public static func invocation(executablePath: String) -> ProcessRequest? {
        guard isAllowedExecutable(executablePath) else {
            return nil
        }
        return ProcessRequest(
            executableURL: URL(fileURLWithPath: executablePath),
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

