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
        case .powerOnHours:
            "h"
        case .powerCycles, .unsafeShutdowns, .mediaErrors:
            "count"
        }
    }

    var allowedAggregations: [RuleAggregation] {
        switch self {
        case .availableSpareThreshold:
            [.current, .minimum, .maximum]
        case .temperature, .availableSpare, .percentageUsed:
            [.current, .increase, .average, .minimum, .maximum]
        case .dataRead, .dataWritten, .powerCycles, .powerOnHours,
             .unsafeShutdowns, .mediaErrors:
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
        case .powerCycles:
            sample.powerCycles.map(Double.init)
        case .powerOnHours:
            sample.powerOnHours.map(Double.init)
        case .unsafeShutdowns:
            sample.unsafeShutdowns.map(Double.init)
        case .mediaErrors:
            sample.mediaErrors.map(Double.init)
        }
    }
}
