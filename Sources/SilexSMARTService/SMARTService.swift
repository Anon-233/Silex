import Foundation
import OSLog
import SilexCore

final class SMARTService: NSObject, SMARTServiceProtocol {
    private let runner: SmartctlRunner
    private let idleTerminator: ServiceIdleTerminator
    private let serviceExecutableURL: URL

    init(
        runner: SmartctlRunner = SmartctlRunner(),
        idleTerminator: ServiceIdleTerminator,
        serviceExecutableURL: URL = URL(
            fileURLWithPath: CommandLine.arguments[0]
        )
    ) {
        self.runner = runner
        self.idleTerminator = idleTerminator
        self.serviceExecutableURL = serviceExecutableURL
    }

    func collectBuiltInDrive(
        reply: @escaping (NSData?, NSNumber, NSString?) -> Void
    ) {
        idleTerminator.beginRequest()
        defer { idleTerminator.endRequest() }

        let invocation = PrivilegedSMARTPolicy.invocation(
            serviceExecutableURL: serviceExecutableURL
        )
        guard FileManager.default.isExecutableFile(
            atPath: invocation.executableURL.path
        ) else {
            SilexLog.service.error("Bundled smartctl is missing")
            reply(nil, -1, "Bundled smartctl is missing.")
            return
        }

        do {
            let result = try runner.collect(
                executablePath: invocation.executableURL.path
            )
            let errorText = String(decoding: result.stderr, as: UTF8.self)
            reply(
                result.stdout as NSData,
                NSNumber(value: result.exitStatus),
                errorText.isEmpty ? nil : errorText as NSString
            )
            SilexLog.service.info("smartctl completed with status \(result.exitStatus)")
        } catch {
            SilexLog.service.error("smartctl execution failed: \(error.localizedDescription, privacy: .public)")
            reply(nil, -1, error.localizedDescription as NSString)
        }
    }
}

final class SMARTServiceListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let idleTerminator: ServiceIdleTerminator

    init(idleTerminator: ServiceIdleTerminator) {
        self.idleTerminator = idleTerminator
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        guard SMARTConnectionPolicy.accepts(
            effectiveUserID: connection.effectiveUserIdentifier,
            consoleUserID: ConsoleUser.currentUserID()
        ) else {
            SilexLog.service.error("Rejected XPC connection for uid \(connection.effectiveUserIdentifier)")
            return false
        }

        connection.exportedInterface = NSXPCInterface(with: SMARTServiceProtocol.self)
        connection.exportedObject = SMARTService(idleTerminator: idleTerminator)
        connection.resume()
        return true
    }
}

final class ServiceIdleTerminator: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.anon233.Silex.SMARTService.idle")
    private var exitWorkItem: DispatchWorkItem?

    init() {
        endRequest()
    }

    func beginRequest() {
        queue.sync {
            exitWorkItem?.cancel()
            exitWorkItem = nil
        }
    }

    func endRequest() {
        queue.sync {
            exitWorkItem?.cancel()
            let item = DispatchWorkItem {
                exit(EXIT_SUCCESS)
            }
            exitWorkItem = item
            queue.asyncAfter(
                deadline: .now() + PrivilegedServiceIdlePolicy.timeout,
                execute: item
            )
        }
    }
}

private enum ConsoleUser {
    static func currentUserID() -> UInt32? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: "/dev/console"),
            let owner = attributes[.ownerAccountID] as? NSNumber
        else {
            return nil
        }
        return owner.uint32Value
    }
}
