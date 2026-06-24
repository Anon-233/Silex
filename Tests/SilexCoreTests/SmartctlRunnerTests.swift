import Foundation
import Testing
@testable import SilexCore

struct SmartctlRunnerTests {
    @Test
    func locatorPrefersValidConfiguredPathThenCommonPathsThenWhich() {
        let existing = Set([
            "/configured/smartctl",
            "/opt/homebrew/bin/smartctl",
            "/which/smartctl"
        ])
        let locator = SmartctlLocator(
            isExecutable: { existing.contains($0) },
            which: { "/which/smartctl\n" }
        )

        #expect(locator.locate(configuredPath: "/configured/smartctl") == "/configured/smartctl")
        #expect(locator.locate(configuredPath: "/missing/smartctl") == "/opt/homebrew/bin/smartctl")
    }

    @Test
    func runnerUsesFixedJSONExtendedArgumentsAndBuiltInDevice() throws {
        let executor = RecordingProcessExecutor(
            result: ProcessResult(
                stdout: Data(#"{"smartctl":{"exit_status":0}}"#.utf8),
                stderr: Data(),
                exitStatus: 0
            )
        )
        let runner = SmartctlRunner(executor: executor)

        let result = try runner.collect(executablePath: "/opt/homebrew/bin/smartctl")

        #expect(executor.lastRequest?.executableURL.path == "/opt/homebrew/bin/smartctl")
        #expect(executor.lastRequest?.arguments == ["-j", "-x", "/dev/disk0"])
        #expect(result.exitStatus == 0)
        #expect(String(decoding: result.stdout, as: UTF8.self).contains("exit_status"))
    }

    @Test
    func foundationExecutorCapturesOutputAndExitStatus() throws {
        let result = try FoundationProcessExecutor().run(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "printf output; printf error >&2; exit 7"]
            )
        )

        #expect(String(decoding: result.stdout, as: UTF8.self) == "output")
        #expect(String(decoding: result.stderr, as: UTF8.self) == "error")
        #expect(result.exitStatus == 7)
    }
}

private final class RecordingProcessExecutor: ProcessExecuting, @unchecked Sendable {
    private let result: ProcessResult
    private(set) var lastRequest: ProcessRequest?

    init(result: ProcessResult) {
        self.result = result
    }

    func run(_ request: ProcessRequest) throws -> ProcessResult {
        lastRequest = request
        return result
    }
}

