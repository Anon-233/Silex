import Foundation
import Testing
@testable import SilexCore

struct ExporterTests {
    @Test
    func exportsCompleteJSONIncludingRawSmartctlData() throws {
        let sample = makeSample(date: Date(timeIntervalSince1970: 1_000))

        let data = try HistoryExporter().json(samples: [sample])
        let decoded = try JSONDecoder().decode([DriveSample].self, from: data)

        #expect(decoded == [sample])
        #expect(decoded[0].rawJSON == sample.rawJSON)
    }

    @Test
    func exportsStableCSVColumnsAndEscapesText() throws {
        var sample = makeSample(date: Date(timeIntervalSince1970: 1_000))
        sample = DriveSample(
            id: sample.id,
            collectedAt: sample.collectedAt,
            source: sample.source,
            modelName: "APPLE, SSD",
            serialNumber: sample.serialNumber,
            firmwareVersion: sample.firmwareVersion,
            nvmeVersion: sample.nvmeVersion,
            smartPassed: sample.smartPassed,
            criticalWarning: sample.criticalWarning,
            temperatureCelsius: sample.temperatureCelsius,
            availableSparePercent: sample.availableSparePercent,
            availableSpareThresholdPercent: sample.availableSpareThresholdPercent,
            percentageUsed: sample.percentageUsed,
            dataReadBytes: sample.dataReadBytes,
            dataWrittenBytes: sample.dataWrittenBytes,
            hostReadCommands: sample.hostReadCommands,
            hostWriteCommands: sample.hostWriteCommands,
            controllerBusyMinutes: sample.controllerBusyMinutes,
            powerCycles: sample.powerCycles,
            powerOnHours: sample.powerOnHours,
            unsafeShutdowns: sample.unsafeShutdowns,
            mediaErrors: sample.mediaErrors,
            errorLogEntries: sample.errorLogEntries,
            smartctlExitStatus: sample.smartctlExitStatus,
            rawJSON: sample.rawJSON
        )

        let csv = String(decoding: HistoryExporter().csv(samples: [sample]), as: UTF8.self)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines[0].hasPrefix("id,collectedAt,source,modelName"))
        #expect(lines[1].contains("\"APPLE, SSD\""))
        #expect(lines[1].contains(",30.0,"))
    }
}

