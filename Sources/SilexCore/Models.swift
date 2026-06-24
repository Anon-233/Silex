import Foundation

public enum CollectionSource: String, Codable, CaseIterable, Sendable {
    case manual
    case scheduled
}

public struct DriveSample: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let collectedAt: Date
    public let source: CollectionSource
    public let modelName: String
    public let serialNumber: String?
    public let firmwareVersion: String?
    public let nvmeVersion: String?
    public let smartPassed: Bool
    public let criticalWarning: Int
    public let temperatureCelsius: Double?
    public let availableSparePercent: Double?
    public let availableSpareThresholdPercent: Double?
    public let percentageUsed: Double?
    public let dataReadBytes: Int64?
    public let dataWrittenBytes: Int64?
    public let hostReadCommands: Int64?
    public let hostWriteCommands: Int64?
    public let controllerBusyMinutes: Int64?
    public let powerCycles: Int64?
    public let powerOnHours: Int64?
    public let unsafeShutdowns: Int64?
    public let mediaErrors: Int64?
    public let errorLogEntries: Int64?
    public let smartctlExitStatus: Int
    public let rawJSON: Data

    public init(
        id: UUID = UUID(),
        collectedAt: Date,
        source: CollectionSource,
        modelName: String,
        serialNumber: String? = nil,
        firmwareVersion: String? = nil,
        nvmeVersion: String? = nil,
        smartPassed: Bool,
        criticalWarning: Int,
        temperatureCelsius: Double? = nil,
        availableSparePercent: Double? = nil,
        availableSpareThresholdPercent: Double? = nil,
        percentageUsed: Double? = nil,
        dataReadBytes: Int64? = nil,
        dataWrittenBytes: Int64? = nil,
        hostReadCommands: Int64? = nil,
        hostWriteCommands: Int64? = nil,
        controllerBusyMinutes: Int64? = nil,
        powerCycles: Int64? = nil,
        powerOnHours: Int64? = nil,
        unsafeShutdowns: Int64? = nil,
        mediaErrors: Int64? = nil,
        errorLogEntries: Int64? = nil,
        smartctlExitStatus: Int,
        rawJSON: Data
    ) {
        self.id = id
        self.collectedAt = collectedAt
        self.source = source
        self.modelName = modelName
        self.serialNumber = serialNumber
        self.firmwareVersion = firmwareVersion
        self.nvmeVersion = nvmeVersion
        self.smartPassed = smartPassed
        self.criticalWarning = criticalWarning
        self.temperatureCelsius = temperatureCelsius
        self.availableSparePercent = availableSparePercent
        self.availableSpareThresholdPercent = availableSpareThresholdPercent
        self.percentageUsed = percentageUsed
        self.dataReadBytes = dataReadBytes
        self.dataWrittenBytes = dataWrittenBytes
        self.hostReadCommands = hostReadCommands
        self.hostWriteCommands = hostWriteCommands
        self.controllerBusyMinutes = controllerBusyMinutes
        self.powerCycles = powerCycles
        self.powerOnHours = powerOnHours
        self.unsafeShutdowns = unsafeShutdowns
        self.mediaErrors = mediaErrors
        self.errorLogEntries = errorLogEntries
        self.smartctlExitStatus = smartctlExitStatus
        self.rawJSON = rawJSON
    }
}

