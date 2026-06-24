import Foundation

public extension Metric {
    var unit: String {
        switch self {
        case .temperature:
            "°C"
        case .availableSpare, .availableSpareThreshold, .percentageUsed:
            "%"
        case .dataRead, .dataWritten:
            "GB"
        case .controllerBusyMinutes:
            "min"
        case .powerOnHours:
            "h"
        case .hostReadCommands, .hostWriteCommands, .powerCycles,
             .unsafeShutdowns, .mediaErrors, .errorLogEntries,
             .criticalWarning:
            "count"
        }
    }

    var allowedAggregations: [RuleAggregation] {
        switch self {
        case .availableSpareThreshold, .criticalWarning:
            [.current, .minimum, .maximum]
        case .temperature, .availableSpare, .percentageUsed:
            [.current, .increase, .average, .minimum, .maximum]
        case .dataRead, .dataWritten, .hostReadCommands, .hostWriteCommands,
             .controllerBusyMinutes, .powerCycles, .powerOnHours,
             .unsafeShutdowns, .mediaErrors, .errorLogEntries:
            RuleAggregation.allCases
        }
    }

    func value(in sample: DriveSample) -> Double? {
        switch self {
        case .temperature:
            sample.temperatureCelsius
        case .availableSpare:
            sample.availableSparePercent
        case .availableSpareThreshold:
            sample.availableSpareThresholdPercent
        case .percentageUsed:
            sample.percentageUsed
        case .dataRead:
            sample.dataReadBytes.map { Double($0) / 1_000_000_000 }
        case .dataWritten:
            sample.dataWrittenBytes.map { Double($0) / 1_000_000_000 }
        case .hostReadCommands:
            sample.hostReadCommands.map(Double.init)
        case .hostWriteCommands:
            sample.hostWriteCommands.map(Double.init)
        case .controllerBusyMinutes:
            sample.controllerBusyMinutes.map(Double.init)
        case .powerCycles:
            sample.powerCycles.map(Double.init)
        case .powerOnHours:
            sample.powerOnHours.map(Double.init)
        case .unsafeShutdowns:
            sample.unsafeShutdowns.map(Double.init)
        case .mediaErrors:
            sample.mediaErrors.map(Double.init)
        case .errorLogEntries:
            sample.errorLogEntries.map(Double.init)
        case .criticalWarning:
            Double(sample.criticalWarning)
        }
    }
}

