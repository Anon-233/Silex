import Foundation

public enum HistoryRange: String, CaseIterable, Sendable {
    case hours24
    case days30
    case all

    var duration: TimeInterval? {
        switch self {
        case .hours24:
            24 * 3_600
        case .days30:
            30 * 86_400
        case .all:
            nil
        }
    }
}

public struct MetricStatistics: Equatable, Sendable {
    public let latest: Double?
    public let minimum: Double?
    public let maximum: Double?
    public let average: Double?
    public let recentChange: Double?
    public let recentRatePerHour: Double?
    public let averageRatePerHour: Double?

    public init(
        latest: Double?,
        minimum: Double?,
        maximum: Double?,
        average: Double?,
        recentChange: Double?,
        recentRatePerHour: Double?,
        averageRatePerHour: Double?
    ) {
        self.latest = latest
        self.minimum = minimum
        self.maximum = maximum
        self.average = average
        self.recentChange = recentChange
        self.recentRatePerHour = recentRatePerHour
        self.averageRatePerHour = averageRatePerHour
    }
}

public struct HistoryAnalyzer: Sendable {
    public init() {}

    public func filtered(
        _ samples: [DriveSample],
        range: HistoryRange,
        now: Date
    ) -> [DriveSample] {
        let sorted = samples.sorted { $0.collectedAt < $1.collectedAt }
        guard let duration = range.duration else {
            return sorted
        }
        let start = now.addingTimeInterval(-duration)
        return sorted.filter {
            $0.collectedAt >= start && $0.collectedAt <= now
        }
    }

    public func statistics(
        for metric: Metric,
        samples: [DriveSample]
    ) -> MetricStatistics {
        let points = samples
            .sorted { $0.collectedAt < $1.collectedAt }
            .compactMap { sample -> MetricPoint? in
                guard let value = metric.value(in: sample) else {
                    return nil
                }
                return MetricPoint(date: sample.collectedAt, value: value)
            }

        guard let last = points.last else {
            return MetricStatistics(
                latest: nil,
                minimum: nil,
                maximum: nil,
                average: nil,
                recentChange: nil,
                recentRatePerHour: nil,
                averageRatePerHour: nil
            )
        }

        let values = points.map(\.value)
        let recent = points.count >= 2
            ? change(from: points[points.count - 2], to: last)
            : nil
        let overall = points.count >= 2
            ? change(from: points[0], to: last)
            : nil

        return MetricStatistics(
            latest: last.value,
            minimum: values.min(),
            maximum: values.max(),
            average: values.reduce(0, +) / Double(values.count),
            recentChange: recent?.delta,
            recentRatePerHour: recent?.rate,
            averageRatePerHour: overall?.rate
        )
    }

    private func change(from first: MetricPoint, to last: MetricPoint) -> Change? {
        let elapsedHours = last.date.timeIntervalSince(first.date) / 3_600
        guard elapsedHours > 0 else {
            return nil
        }
        let delta = last.value - first.value
        return Change(delta: delta, rate: delta / elapsedHours)
    }
}

private struct MetricPoint {
    let date: Date
    let value: Double
}

private struct Change {
    let delta: Double
    let rate: Double
}

