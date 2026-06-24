import Foundation
@testable import SilexCore

func makeSample(
    id: UUID = UUID(),
    date: Date,
    source: CollectionSource = .manual,
    temperature: Double = 30,
    readBytes: Int64 = 1_000_000,
    writtenBytes: Int64 = 2_000_000,
    spare: Double = 100,
    used: Double = 0,
    powerCycles: Int64 = 10,
    powerOnHours: Int64 = 20,
    unsafeShutdowns: Int64 = 1,
    mediaErrors: Int64 = 0,
    errorEntries: Int64 = 0
) -> DriveSample {
    DriveSample(
        id: id,
        collectedAt: date,
        source: source,
        modelName: "APPLE SSD",
        serialNumber: "serial",
        firmwareVersion: "firmware",
        nvmeVersion: "1.2",
        smartPassed: true,
        criticalWarning: 0,
        temperatureCelsius: temperature,
        availableSparePercent: spare,
        availableSpareThresholdPercent: 99,
        percentageUsed: used,
        dataReadBytes: readBytes,
        dataWrittenBytes: writtenBytes,
        hostReadCommands: 100,
        hostWriteCommands: 200,
        controllerBusyMinutes: 3,
        powerCycles: powerCycles,
        powerOnHours: powerOnHours,
        unsafeShutdowns: unsafeShutdowns,
        mediaErrors: mediaErrors,
        errorLogEntries: errorEntries,
        smartctlExitStatus: 0,
        rawJSON: Data(#"{"sample":true}"#.utf8)
    )
}

