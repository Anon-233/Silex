import Foundation
import Testing

struct PlistTests {
    @Test
    func launchDaemonPlistIsRestrictedAndOnDemand() throws {
        let url = repositoryRoot()
            .appendingPathComponent("Resources/LaunchDaemons/com.anon233.Silex.SMARTService.plist")
        let data = try Data(contentsOf: url)
        let plist = try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        #expect(plist["Label"] as? String == "com.anon233.Silex.SMARTService")
        #expect(
            plist["BundleProgram"] as? String
                == "Contents/Library/PrivilegedHelperTools/SilexSMARTService"
        )
        #expect(plist["UserName"] as? String == "root")
        #expect(plist["RunAtLoad"] as? Bool == false)
        #expect(plist["KeepAlive"] == nil)

        let machServices = try #require(plist["MachServices"] as? [String: Bool])
        #expect(machServices == ["com.anon233.Silex.SMARTService": true])
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

