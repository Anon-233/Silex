import Foundation
import SilexCore

final class SMARTService: NSObject, SMARTServiceProtocol {
    private let locator: SmartctlLocator
    private let runner: SmartctlRunner

    init(
        locator: SmartctlLocator = SmartctlLocator(),
        runner: SmartctlRunner = SmartctlRunner()
    ) {
        self.locator = locator
        self.runner = runner
    }

    func collectBuiltInDrive(
        reply: @escaping (NSData?, NSNumber, NSString?) -> Void
    ) {
        guard
            let path = locator.locate(configuredPath: nil),
            PrivilegedSMARTPolicy.isAllowedExecutable(path)
        else {
            reply(nil, -1, "smartctl was not found in an approved location.")
            return
        }

        do {
            let result = try runner.collect(executablePath: path)
            let errorText = String(decoding: result.stderr, as: UTF8.self)
            reply(
                result.stdout as NSData,
                NSNumber(value: result.exitStatus),
                errorText.isEmpty ? nil : errorText as NSString
            )
        } catch {
            reply(nil, -1, error.localizedDescription as NSString)
        }
    }
}

final class SMARTServiceListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        guard SMARTConnectionPolicy.accepts(
            effectiveUserID: connection.effectiveUserIdentifier,
            consoleUserID: ConsoleUser.currentUserID()
        ) else {
            return false
        }

        connection.exportedInterface = NSXPCInterface(with: SMARTServiceProtocol.self)
        connection.exportedObject = SMARTService()
        connection.resume()
        return true
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

