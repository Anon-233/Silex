import Foundation

public struct ProcessRequest: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]

    public init(executableURL: URL, arguments: [String]) {
        self.executableURL = executableURL
        self.arguments = arguments
    }
}

public struct ProcessResult: Equatable, Sendable {
    public let stdout: Data
    public let stderr: Data
    public let exitStatus: Int32

    public init(stdout: Data, stderr: Data, exitStatus: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitStatus = exitStatus
    }
}

public protocol ProcessExecuting: Sendable {
    func run(_ request: ProcessRequest) throws -> ProcessResult
}

public struct FoundationProcessExecutor: ProcessExecuting {
    public init() {}

    public func run(_ request: ProcessRequest) throws -> ProcessResult {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.standardOutput = output
        process.standardError = errors

        try process.run()
        process.waitUntilExit()

        return ProcessResult(
            stdout: output.fileHandleForReading.readDataToEndOfFile(),
            stderr: errors.fileHandleForReading.readDataToEndOfFile(),
            exitStatus: process.terminationStatus
        )
    }
}

public struct SmartctlCommandResult: Equatable, Sendable {
    public let stdout: Data
    public let stderr: Data
    public let exitStatus: Int32

    public init(stdout: Data, stderr: Data, exitStatus: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitStatus = exitStatus
    }
}

public struct SmartctlRunner: Sendable {
    private let executor: any ProcessExecuting

    public init(executor: any ProcessExecuting = FoundationProcessExecutor()) {
        self.executor = executor
    }

    public func collect(executablePath: String) throws -> SmartctlCommandResult {
        let result = try executor.run(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: executablePath),
                arguments: ["-j", "-x", "/dev/disk0"]
            )
        )
        return SmartctlCommandResult(
            stdout: result.stdout,
            stderr: result.stderr,
            exitStatus: result.exitStatus
        )
    }
}

