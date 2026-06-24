import ServiceManagement
import Testing
@testable import SilexCore

struct ServiceControllerTests {
    @Test
    func mapsEveryServiceManagementStatus() {
        #expect(ServiceController.map(.notRegistered) == .notRegistered)
        #expect(ServiceController.map(.enabled) == .enabled)
        #expect(ServiceController.map(.requiresApproval) == .requiresApproval)
        #expect(ServiceController.map(.notFound) == .notFound)
    }

    @Test
    func delegatesRegistrationAndUnregistration() throws {
        let registration = FakeServiceRegistration()
        let controller = ServiceController(registration: registration)

        try controller.enable()
        #expect(registration.registerCalls == 1)

        try controller.disable()
        #expect(registration.unregisterCalls == 1)
    }

    @Test
    func connectionPolicyOnlyAcceptsTheActiveConsoleUser() {
        #expect(SMARTConnectionPolicy.accepts(effectiveUserID: 501, consoleUserID: 501))
        #expect(!SMARTConnectionPolicy.accepts(effectiveUserID: 502, consoleUserID: 501))
        #expect(!SMARTConnectionPolicy.accepts(effectiveUserID: 0, consoleUserID: 501))
        #expect(!SMARTConnectionPolicy.accepts(effectiveUserID: 501, consoleUserID: nil))
    }
}

private final class FakeServiceRegistration: ServiceRegistering, @unchecked Sendable {
    var status: BackgroundServiceStatus = .notRegistered
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0

    func register() throws {
        registerCalls += 1
        status = .enabled
    }

    func unregister() throws {
        unregisterCalls += 1
        status = .notRegistered
    }
}

