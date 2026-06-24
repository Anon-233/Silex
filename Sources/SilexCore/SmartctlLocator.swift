import Foundation

public struct SmartctlLocator: Sendable {
    public static let commonPaths = [
        "/opt/homebrew/bin/smartctl",
        "/opt/homebrew/sbin/smartctl",
        "/usr/local/bin/smartctl",
        "/usr/local/sbin/smartctl"
    ]

    private let isExecutable: @Sendable (String) -> Bool
    private let which: @Sendable () -> String?

    public init() {
        isExecutable = {
            FileManager.default.isExecutableFile(atPath: $0)
        }
        which = {
            SmartctlLocator.runWhich()
        }
    }

    public init(
        isExecutable: @escaping @Sendable (String) -> Bool,
        which: @escaping @Sendable () -> String?
    ) {
        self.isExecutable = isExecutable
        self.which = which
    }

    public func locate(configuredPath: String?) -> String? {
        let candidates = [configuredPath].compactMap { $0 } + Self.commonPaths
        if let path = candidates.first(where: isExecutable) {
            return path
        }

        guard let output = which() else {
            return nil
        }
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return !path.isEmpty && isExecutable(path) ? path : nil
    }

    private static func runWhich() -> String? {
        let result = try? FoundationProcessExecutor().run(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/which"),
                arguments: ["smartctl"]
            )
        )
        guard let result, result.exitStatus == 0 else {
            return nil
        }
        return String(decoding: result.stdout, as: UTF8.self)
    }
}
