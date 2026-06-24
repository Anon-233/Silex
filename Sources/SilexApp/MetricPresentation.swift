import SwiftUI
import SilexCore

extension Metric {
    var titleKey: String {
        "metric.\(rawValue)"
    }

    var chartColor: Color {
        switch self {
        case .dataRead, .powerCycles:
            .blue
        case .dataWritten:
            .cyan
        case .temperature, .availableSpare:
            .green
        case .percentageUsed:
            .purple
        case .availableSpareThreshold, .unsafeShutdowns:
            .orange
        case .mediaErrors:
            .red
        default:
            .secondary
        }
    }

    var chartValueKind: ChartValueKind {
        switch self {
        case .availableSpare, .availableSpareThreshold, .percentageUsed:
            .percentage
        case .dataRead, .dataWritten, .powerCycles, .powerOnHours,
             .unsafeShutdowns, .mediaErrors:
            .nonnegative
        case .temperature:
            .unconstrained
        }
    }
}
