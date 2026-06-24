import Foundation

public struct HistoryExporter: Sendable {
    public init() {}

    public func json(samples: [DriveSample]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(samples)
    }

    public func csv(samples: [DriveSample]) -> Data {
        let header = [
            "id",
            "collectedAt",
            "source",
            "modelName",
            "serialNumber",
            "smartPassed",
            "criticalWarning",
            "temperatureCelsius",
            "availableSparePercent",
            "availableSpareThresholdPercent",
            "percentageUsed",
            "dataReadBytes",
            "dataWrittenBytes",
            "powerCycles",
            "powerOnHours",
            "unsafeShutdowns",
            "mediaErrors",
            "errorLogEntries",
            "smartctlExitStatus"
        ]

        let formatter = ISO8601DateFormatter()
        let rows = samples.map { sample in
            [
                sample.id.uuidString,
                formatter.string(from: sample.collectedAt),
                sample.source.rawValue,
                sample.modelName,
                sample.serialNumber ?? "",
                sample.smartPassed ? "true" : "false",
                String(sample.criticalWarning),
                string(sample.temperatureCelsius),
                string(sample.availableSparePercent),
                string(sample.availableSpareThresholdPercent),
                string(sample.percentageUsed),
                string(sample.dataReadBytes),
                string(sample.dataWrittenBytes),
                string(sample.powerCycles),
                string(sample.powerOnHours),
                string(sample.unsafeShutdowns),
                string(sample.mediaErrors),
                string(sample.errorLogEntries),
                String(sample.smartctlExitStatus)
            ].map(escape).joined(separator: ",")
        }

        return Data(([header.joined(separator: ",")] + rows).joined(separator: "\n").utf8)
    }

    private func string<T>(_ value: T?) -> String {
        value.map(String.init(describing:)) ?? ""
    }

    private func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

