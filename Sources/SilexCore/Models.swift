import Foundation

public enum CollectionSource: String, Codable, CaseIterable, Sendable {
    case manual
    case scheduled
}

public enum Metric: String, Codable, CaseIterable, Sendable {
    case temperature
    case availableSpare
    case availableSpareThreshold
    case percentageUsed
    case dataRead
    case dataWritten
    case hostReadCommands
    case hostWriteCommands
    case controllerBusyMinutes
    case powerCycles
    case powerOnHours
    case unsafeShutdowns
    case mediaErrors
    case errorLogEntries
    case criticalWarning
}

public enum RuleAggregation: String, Codable, CaseIterable, Sendable {
    case current
    case increase
    case ratePerHour
    case average
    case minimum
    case maximum
}

public enum RuleComparison: String, Codable, CaseIterable, Sendable {
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
}

public struct AlertRule: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var metric: Metric
    public var aggregation: RuleAggregation
    public var windowHours: Double
    public var comparison: RuleComparison
    public var threshold: Double
    public var cooldownHours: Double
    public var isEnabled: Bool
    public var lastTriggeredAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        metric: Metric,
        aggregation: RuleAggregation,
        windowHours: Double,
        comparison: RuleComparison,
        threshold: Double,
        cooldownHours: Double,
        isEnabled: Bool,
        lastTriggeredAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.metric = metric
        self.aggregation = aggregation
        self.windowHours = windowHours
        self.comparison = comparison
        self.threshold = threshold
        self.cooldownHours = cooldownHours
        self.isEnabled = isEnabled
        self.lastTriggeredAt = lastTriggeredAt
    }
}

public enum LanguagePreference: String, Codable, CaseIterable, Sendable {
    case system
    case english
    case simplifiedChinese
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var collectionIntervalHours: Double
    public var smartctlPath: String?
    public var language: LanguagePreference
    public var notificationsEnabled: Bool
    public var launchAtLogin: Bool

    public init(
        collectionIntervalHours: Double = 8,
        smartctlPath: String? = nil,
        language: LanguagePreference = .system,
        notificationsEnabled: Bool = true,
        launchAtLogin: Bool = true
    ) {
        self.collectionIntervalHours = collectionIntervalHours
        self.smartctlPath = smartctlPath
        self.language = language
        self.notificationsEnabled = notificationsEnabled
        self.launchAtLogin = launchAtLogin
    }
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
