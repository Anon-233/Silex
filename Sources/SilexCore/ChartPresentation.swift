import Foundation

public struct ChartPoint: Equatable, Identifiable, Sendable {
    public let metric: Metric
    public let date: Date
    public let value: Double

    public init(metric: Metric, date: Date, value: Double) {
        self.metric = metric
        self.date = date
        self.value = value
    }

    public var id: String {
        "\(metric.rawValue)-\(date.timeIntervalSinceReferenceDate)"
    }
}

public struct ChartMetricSeries: Equatable, Identifiable, Sendable {
    public let metric: Metric
    public let points: [ChartPoint]

    public init(metric: Metric, points: [ChartPoint]) {
        self.metric = metric
        self.points = points
    }

    public var id: Metric {
        metric
    }
}

public struct ChartSeriesBuilder: Sendable {
    private let analyzer = HistoryAnalyzer()

    public init() {}

    public func build(
        metrics: [Metric],
        samples: [DriveSample],
        range: HistoryRange,
        now: Date,
        transform: (Metric, Double) -> Double = { _, value in value }
    ) -> [ChartMetricSeries] {
        let filtered = analyzer.filtered(samples, range: range, now: now)

        return metrics.compactMap { metric in
            var valuesByDate: [Date: Double] = [:]
            for sample in filtered {
                guard let value = metric.value(in: sample) else {
                    continue
                }
                valuesByDate[sample.collectedAt] = transform(metric, value)
            }

            let points = valuesByDate
                .map { date, value in
                    ChartPoint(metric: metric, date: date, value: value)
                }
                .sorted { $0.date < $1.date }

            guard !points.isEmpty else {
                return nil
            }
            return ChartMetricSeries(metric: metric, points: points)
        }
    }
}

public enum ChartValueKind: Sendable {
    case percentage
    case nonnegative
    case unconstrained
}

public struct ChartAxisDomain: Equatable, Sendable {
    public let lower: Double
    public let upper: Double

    public init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }
}

public struct ChartAxisDomainBuilder: Sendable {
    public init() {}

    public func domain(
        values: [Double],
        kind: ChartValueKind
    ) -> ChartAxisDomain? {
        let finiteValues = values.filter(\.isFinite)
        guard
            let minimum = finiteValues.min(),
            let maximum = finiteValues.max()
        else {
            return nil
        }

        let padding: Double
        if minimum == maximum {
            padding = max(abs(minimum) * 0.05, 1)
        } else {
            padding = (maximum - minimum) * 0.1
        }

        var lower = minimum - padding
        var upper = maximum + padding

        switch kind {
        case .percentage:
            if minimum == maximum, minimum == 0 {
                return ChartAxisDomain(lower: 0, upper: 1)
            }
            if minimum == maximum, minimum == 100 {
                return ChartAxisDomain(lower: 99, upper: 100)
            }
            lower = max(0, lower)
            upper = min(100, upper)
        case .nonnegative:
            lower = max(0, lower)
            if lower == upper {
                upper = lower + 1
            }
        case .unconstrained:
            break
        }

        return ChartAxisDomain(lower: lower, upper: upper)
    }
}
