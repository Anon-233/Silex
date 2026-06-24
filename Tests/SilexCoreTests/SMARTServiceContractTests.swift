import Foundation
import Testing
@testable import SilexCore

struct SMARTServiceContractTests {
    @Test
    func privilegedPolicyOnlyAllowsKnownSmartctlExecutables() {
        #expect(PrivilegedSMARTPolicy.isAllowedExecutable("/opt/homebrew/bin/smartctl"))
        #expect(PrivilegedSMARTPolicy.isAllowedExecutable("/opt/homebrew/sbin/smartctl"))
        #expect(PrivilegedSMARTPolicy.isAllowedExecutable("/usr/local/bin/smartctl"))
        #expect(PrivilegedSMARTPolicy.isAllowedExecutable("/usr/local/sbin/smartctl"))
        #expect(!PrivilegedSMARTPolicy.isAllowedExecutable("/tmp/smartctl"))
        #expect(!PrivilegedSMARTPolicy.isAllowedExecutable("/bin/sh"))
    }

    @Test
    func privilegedInvocationHasNoCallerControlledArguments() {
        let invocation = PrivilegedSMARTPolicy.invocation(executablePath: "/opt/homebrew/bin/smartctl")

        #expect(invocation?.arguments == ["-j", "-x", "/dev/disk0"])
        #expect(PrivilegedSMARTPolicy.invocation(executablePath: "/tmp/smartctl") == nil)
        #expect(SMARTServiceConstants.machServiceName == "com.anon233.Silex.SMARTService")
    }
}

