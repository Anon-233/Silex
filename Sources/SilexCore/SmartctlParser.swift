import Foundation

public enum SmartctlParserError: Error, Equatable, LocalizedError {
    case invalidJSON
    case missingHealthLog
    case counterOverflow

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "smartctl returned malformed JSON."
        case .missingHealthLog:
            "smartctl JSON does not contain an NVMe health log."
        case .counterOverflow:
            "A smartctl data-unit counter is too large to convert to bytes."
        }
    }
}

public struct SmartctlParser: Sendable {
    public init() {}

    public func parse(
        data: Data,
        source: CollectionSource,
        collectedAt: Date
    ) throws -> DriveSample {
        let document: SmartctlDocument
        do {
            document = try JSONDecoder().decode(SmartctlDocument.self, from: data)
        } catch {
            throw SmartctlParserError.invalidJSON
        }

        guard let health = document.health else {
            throw SmartctlParserError.missingHealthLog
        }

        return DriveSample(
            collectedAt: collectedAt,
            source: source,
            modelName: document.modelName ?? "Unknown SSD",
            serialNumber: document.serialNumber,
            firmwareVersion: document.firmwareVersion,
            nvmeVersion: document.nvmeVersion?.string,
            smartPassed: document.smartStatus?.passed ?? false,
            criticalWarning: health.criticalWarning ?? 0,
            temperatureCelsius: health.temperature,
            availableSparePercent: health.availableSpare,
            availableSpareThresholdPercent: health.availableSpareThreshold,
            percentageUsed: health.percentageUsed,
            dataReadBytes: try bytes(explicit: health.dataUnitsReadBytes, units: health.dataUnitsRead),
            dataWrittenBytes: try bytes(explicit: health.dataUnitsWrittenBytes, units: health.dataUnitsWritten),
            hostReadCommands: health.hostReads,
            hostWriteCommands: health.hostWrites,
            controllerBusyMinutes: health.controllerBusyTime,
            powerCycles: health.powerCycles,
            powerOnHours: health.powerOnHours,
            unsafeShutdowns: health.unsafeShutdowns,
            mediaErrors: health.mediaErrors,
            errorLogEntries: health.errorLogEntries,
            smartctlExitStatus: document.smartctl?.exitStatus ?? 0,
            rawJSON: data
        )
    }

    private func bytes(explicit: Int64?, units: Int64?) throws -> Int64? {
        if let explicit {
            return explicit
        }
        guard let units else {
            return nil
        }
        let result = units.multipliedReportingOverflow(by: 512_000)
        guard !result.overflow else {
            throw SmartctlParserError.counterOverflow
        }
        return result.partialValue
    }
}

private struct SmartctlDocument: Decodable {
    let smartctl: SmartctlSection?
    let modelName: String?
    let serialNumber: String?
    let firmwareVersion: String?
    let nvmeVersion: NVMeVersion?
    let smartStatus: SmartStatus?
    let health: NVMeHealth?

    enum CodingKeys: String, CodingKey {
        case smartctl
        case modelName = "model_name"
        case serialNumber = "serial_number"
        case firmwareVersion = "firmware_version"
        case nvmeVersion = "nvme_version"
        case smartStatus = "smart_status"
        case health = "nvme_smart_health_information_log"
    }
}

private struct SmartctlSection: Decodable {
    let exitStatus: Int?

    enum CodingKeys: String, CodingKey {
        case exitStatus = "exit_status"
    }
}

private struct NVMeVersion: Decodable {
    let string: String?
}

private struct SmartStatus: Decodable {
    let passed: Bool?
}

private struct NVMeHealth: Decodable {
    let criticalWarning: Int?
    let temperature: Double?
    let availableSpare: Double?
    let availableSpareThreshold: Double?
    let percentageUsed: Double?
    let dataUnitsRead: Int64?
    let dataUnitsReadBytes: Int64?
    let dataUnitsWritten: Int64?
    let dataUnitsWrittenBytes: Int64?
    let hostReads: Int64?
    let hostWrites: Int64?
    let controllerBusyTime: Int64?
    let powerCycles: Int64?
    let powerOnHours: Int64?
    let unsafeShutdowns: Int64?
    let mediaErrors: Int64?
    let errorLogEntries: Int64?

    enum CodingKeys: String, CodingKey {
        case criticalWarning = "critical_warning"
        case temperature
        case availableSpare = "available_spare"
        case availableSpareThreshold = "available_spare_threshold"
        case percentageUsed = "percentage_used"
        case dataUnitsRead = "data_units_read"
        case dataUnitsReadBytes = "data_units_read_bytes"
        case dataUnitsWritten = "data_units_written"
        case dataUnitsWrittenBytes = "data_units_written_bytes"
        case hostReads = "host_reads"
        case hostWrites = "host_writes"
        case controllerBusyTime = "controller_busy_time"
        case powerCycles = "power_cycles"
        case powerOnHours = "power_on_hours"
        case unsafeShutdowns = "unsafe_shutdowns"
        case mediaErrors = "media_errors"
        case errorLogEntries = "num_err_log_entries"
    }
}

