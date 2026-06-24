import Foundation
import Testing
@testable import SilexCore

struct SmartctlParserTests {
    @Test
    func parsesAppleNVMeSample() throws {
        let url = try #require(
            Bundle.module.url(forResource: "apple-nvme", withExtension: "json", subdirectory: "Fixtures")
        )
        let data = try Data(contentsOf: url)

        let sample = try SmartctlParser().parse(
            data: data,
            source: .manual,
            collectedAt: Date(timeIntervalSince1970: 1_782_230_764)
        )

        #expect(sample.modelName == "APPLE SSD AP1024Z")
        #expect(sample.serialNumber == "07f1f1013ad9a02e")
        #expect(sample.firmwareVersion == "2973.120")
        #expect(sample.nvmeVersion == "<1.2")
        #expect(sample.smartPassed)
        #expect(sample.criticalWarning == 0)
        #expect(sample.temperatureCelsius == 30)
        #expect(sample.availableSparePercent == 100)
        #expect(sample.availableSpareThresholdPercent == 99)
        #expect(sample.percentageUsed == 0)
        #expect(sample.dataReadBytes == 3_006_609 * 512_000)
        #expect(sample.dataWrittenBytes == 2_212_292 * 512_000)
        #expect(sample.hostReadCommands == 73_752_824)
        #expect(sample.hostWriteCommands == 69_880_273)
        #expect(sample.controllerBusyMinutes == 0)
        #expect(sample.powerCycles == 124)
        #expect(sample.powerOnHours == 27)
        #expect(sample.unsafeShutdowns == 8)
        #expect(sample.mediaErrors == 0)
        #expect(sample.errorLogEntries == 0)
        #expect(sample.smartctlExitStatus == 0)
        #expect(sample.source == .manual)
        #expect(sample.rawJSON == data)
    }

    @Test
    func acceptsValidSMARTDataWithNonzeroExitStatus() throws {
        let json = """
        {
          "smartctl": {"exit_status": 4},
          "model_name": "APPLE SSD",
          "smart_status": {"passed": false},
          "nvme_smart_health_information_log": {
            "critical_warning": 1,
            "temperature": 42,
            "available_spare": 95,
            "available_spare_threshold": 10,
            "percentage_used": 5,
            "data_units_read": 10,
            "data_units_written": 20,
            "power_cycles": 2,
            "power_on_hours": 3,
            "unsafe_shutdowns": 1,
            "media_errors": 7,
            "num_err_log_entries": 8
          }
        }
        """

        let sample = try SmartctlParser().parse(
            data: Data(json.utf8),
            source: .scheduled,
            collectedAt: .now
        )

        #expect(sample.smartctlExitStatus == 4)
        #expect(sample.smartPassed == false)
        #expect(sample.criticalWarning == 1)
        #expect(sample.source == .scheduled)
    }

    @Test
    func rejectsJSONWithoutSMARTHealthData() {
        let data = Data(#"{"smartctl":{"exit_status":2}}"#.utf8)

        #expect(throws: SmartctlParserError.missingHealthLog) {
            try SmartctlParser().parse(data: data, source: .manual, collectedAt: .now)
        }
    }
}
