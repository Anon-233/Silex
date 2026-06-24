import Foundation

public enum SMARTServiceClientError: Error, LocalizedError {
    case unavailable(String)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case let .unavailable(message):
            "SMART service is unavailable: \(message)"
        case .emptyResponse:
            "SMART service returned no data."
        }
    }
}

private final class XPCReplyGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?

    init(_ continuation: CheckedContinuation<Value, any Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<Value, any Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}

public final class SMARTServiceClient: SMARTCollecting, @unchecked Sendable {
    public init() {}

    public func collect() async throws -> SmartctlCommandResult {
        try await withService { service, finish in
            service.collectBuiltInDrive { data, status, errorText in
                guard let data else {
                    finish(
                        .failure(
                            SMARTServiceClientError.unavailable(
                                errorText.map(String.init) ?? "No response"
                            )
                        )
                    )
                    return
                }
                finish(
                    .success(
                        SmartctlCommandResult(
                            stdout: data as Data,
                            stderr: Data(
                                (errorText.map(String.init) ?? "").utf8
                            ),
                            exitStatus: status.int32Value
                        )
                    )
                )
            }
        }
    }

    public func probe() async -> Bool {
        (try? await withService { service, finish in
            service.probe { finish(.success($0)) }
        }) ?? false
    }

    private func withService<T: Sendable>(
        _ operation: @escaping (
            SMARTServiceProtocol,
            @escaping (Result<T, any Error>) -> Void
        ) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let gate = XPCReplyGate(continuation)
            let connection = NSXPCConnection(
                machServiceName: SMARTServiceConstants.machServiceName,
                options: .privileged
            )
            connection.remoteObjectInterface = NSXPCInterface(
                with: SMARTServiceProtocol.self
            )
            connection.resume()

            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                connection.invalidate()
                gate.resume(
                    with: .failure(
                        SMARTServiceClientError.unavailable(
                            error.localizedDescription
                        )
                    )
                )
            }

            guard let service = proxy as? SMARTServiceProtocol else {
                connection.invalidate()
                gate.resume(
                    with: .failure(SMARTServiceClientError.emptyResponse)
                )
                return
            }

            operation(service) { result in
                connection.invalidate()
                gate.resume(with: result)
            }
        }
    }
}
