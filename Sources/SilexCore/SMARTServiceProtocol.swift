import Foundation

public enum SMARTServiceConstants {
    public static let machServiceName = "com.anon233.Silex.Daemon"
    public static let launchDaemonPlistName = "com.anon233.Silex.Daemon.plist"
    public static let installedServicePath =
        "/Library/PrivilegedHelperTools/SilexDaemon.app/Contents/MacOS/SilexDaemon"
    public static let installedSmartctlPath =
        "/Library/PrivilegedHelperTools/com.anon233.Silex.smartctl"
}

public enum PrivilegedSMARTPolicy {
    public static let bundledExecutableName = "com.anon233.Silex.smartctl"

    public static func bundledExecutableURL(
        serviceExecutableURL: URL
    ) -> URL {
        _ = serviceExecutableURL
        return URL(fileURLWithPath: SMARTServiceConstants.installedSmartctlPath)
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

@objc(SilexDaemonProtocol)
public protocol SMARTServiceProtocol {
    func probe(reply: @escaping (Bool) -> Void)

    func collectBuiltInDrive(
        reply: @escaping (NSData?, NSNumber, NSString?) -> Void
    )
}

public protocol SMARTCollecting: Sendable {
    func collect() async throws -> SmartctlCommandResult
}
