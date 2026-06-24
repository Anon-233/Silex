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

public final class SMARTServiceClient: SMARTCollecting, @unchecked Sendable {
    public init() {}

    public func collect() async throws -> SmartctlCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let connection = NSXPCConnection(
                machServiceName: SMARTServiceConstants.machServiceName,
                options: .privileged
            )
            connection.remoteObjectInterface = NSXPCInterface(with: SMARTServiceProtocol.self)
            connection.resume()

            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                connection.invalidate()
                continuation.resume(
                    throwing: SMARTServiceClientError.unavailable(error.localizedDescription)
                )
            }

            guard let service = proxy as? SMARTServiceProtocol else {
                connection.invalidate()
                continuation.resume(throwing: SMARTServiceClientError.emptyResponse)
                return
            }

            service.collectBuiltInDrive { data, status, errorText in
                connection.invalidate()
                guard let data else {
                    continuation.resume(
                        throwing: SMARTServiceClientError.unavailable(
                            errorText.map(String.init) ?? "No response"
                        )
                    )
                    return
                }
                continuation.resume(
                    returning: SmartctlCommandResult(
                        stdout: data as Data,
                        stderr: Data((errorText.map(String.init) ?? "").utf8),
                        exitStatus: status.int32Value
                    )
                )
            }
        }
    }
}

