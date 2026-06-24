import Charts
import SwiftUI
import SilexCore

enum TrendGroup {
    case readWrite
    case temperature
    case wear
    case events

    var pageTitleKey: String {
        switch self {
        case .readWrite: "page.readWrite"
        case .temperature: "page.temperature"
        case .wear: "page.wear"
        case .events: "page.events"
        }
    }

    var chartTitleKey: String {
        switch self {
        case .readWrite: "chart.readWrite"
        case .temperature: "chart.temperature"
        case .wear: "chart.wear"
        case .events: "chart.events"
        }
    }

    var metrics: [Metric] {
        switch self {
        case .readWrite:
            [.dataRead, .dataWritten]
        case .temperature:
            [.temperature]
        case .wear:
            [.availableSpare, .percentageUsed, .availableSpareThreshold]
        case .events:
            [.powerCycles, .unsafeShutdowns, .mediaErrors]
        }
    }

    var valueKind: ChartValueKind {
        switch self {
        case .temperature:
            .unconstrained
        case .wear:
            .percentage
        case .readWrite, .events:
            .nonnegative
        }
    }
}

struct TrendPageView: View {
    @ObservedObject var model: AppModel
    let group: TrendGroup

    @State private var focusedMetric: Metric?
    private let analyzer = HistoryAnalyzer()
    private let seriesBuilder = ChartSeriesBuilder()
    private let domainBuilder = ChartAxisDomainBuilder()

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                LocalizedLabel(group.pageTitleKey)
                    .font(.title2.bold())
                if group == .events, let hours = model.latestSample?.powerOnHours {
                    Text(
                        "\(localized("metric.powerOnHours", locale: model.locale)): "
                            + "\(hours.formatted()) h"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                rangePicker
            }

            HStack(spacing: 8) {
                ForEach(group.metrics, id: \.self) { metric in
                    let statistics = analyzer.statistics(
                        for: metric,
                        samples: model.samples
                    )
                    let card = cardValues(
                        metric: metric,
                        statistics: statistics
                    )
                    MetricCard(
                        titleKey: metric.titleKey,
                        value: card.value,
                        firstLabelKey: card.firstLabel,
                        firstValue: card.firstValue,
                        secondLabelKey: card.secondLabel,
                        secondValue: card.secondValue,
                        color: metric.chartColor,
                        isSelected: focusedMetric == metric
                    ) {
                        focusedMetric = focusedMetric == metric ? nil : metric
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                LocalizedLabel(group.chartTitleKey)
                    .font(.headline)

                if preparedSeries.isEmpty {
                    ContentUnavailableView(
                        localized("status.noData", locale: model.locale),
                        systemImage: "chart.xyaxis.line",
                        description: Text(
                            localized("message.emptyChart", locale: model.locale)
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    trendChart
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.42))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.quaternary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(12)
    }

    private var displayedMetrics: [Metric] {
        focusedMetric.map { [$0] } ?? group.metrics
    }

    private var preparedSeries: [ChartMetricSeries] {
        seriesBuilder.build(
            metrics: displayedMetrics,
            samples: model.samples,
            range: model.range,
            now: .now
        ) { metric, value in
            switch metric {
            case .dataRead, .dataWritten:
                value / 1_000
            default:
                value
            }
        }
    }

    private var chartDomain: ChartAxisDomain? {
        domainBuilder.domain(
            values: preparedSeries.flatMap { $0.points.map(\.value) },
            kind: group.valueKind
        )
    }

    private var rangePicker: some View {
        HStack(spacing: 2) {
            rangeButton(.hours24, key: "range.24h")
            rangeButton(.days30, key: "range.30d")
            rangeButton(.all, key: "range.all")
        }
        .padding(3)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
    }

    private func rangeButton(_ range: HistoryRange, key: String) -> some View {
        Button {
            model.range = range
        } label: {
            LocalizedLabel(key)
                .font(.caption)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    model.range == range
                        ? Color.accentColor.opacity(0.18)
                        : .clear
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.range == range ? .isSelected : [])
    }

    @ViewBuilder
    private var trendChart: some View {
        let chart = Chart {
            ForEach(preparedSeries) { metricSeries in
                ForEach(metricSeries.points) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Value", point.value),
                        series: .value(
                            "Metric",
                            metricSeries.metric.rawValue
                        )
                    )
                    .foregroundStyle(metricSeries.metric.chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    if model.range != .all || metricSeries.points.count == 1 {
                        PointMark(
                            x: .value("Time", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(metricSeries.metric.chartColor)
                        .symbolSize(28)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5))
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                focusNearest(
                                    location: value.location,
                                    proxy: proxy,
                                    geometry: geometry
                                )
                            }
                    )
            }
        }
        .frame(minHeight: 230)

        if let chartDomain {
            chart.chartYScale(domain: chartDomain.lower...chartDomain.upper)
        } else {
            chart
        }
    }

    private func focusNearest(
        location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else {
            focusedMetric = nil
            return
        }
        let frame = geometry[plotFrame]
        guard frame.contains(location) else {
            focusedMetric = nil
            return
        }
        let local = CGPoint(
            x: location.x - frame.minX,
            y: location.y - frame.minY
        )
        var nearest: (metric: Metric, distance: CGFloat)?

        for metricSeries in preparedSeries {
            for point in metricSeries.points {
                guard
                    let x = proxy.position(forX: point.date),
                    let y = proxy.position(forY: point.value)
                else {
                    continue
                }
                let distance = hypot(x - local.x, y - local.y)
                if nearest == nil || distance < nearest!.distance {
                    nearest = (metricSeries.metric, distance)
                }
            }
        }

        guard let nearest, nearest.distance < 24 else {
            focusedMetric = nil
            return
        }
        focusedMetric = focusedMetric == nearest.metric ? nil : nearest.metric
    }

    private func cardValues(
        metric: Metric,
        statistics: MetricStatistics
    ) -> MetricCardValues {
        switch metric {
        case .dataRead, .dataWritten:
            return MetricCardValues(
                value: format(
                    statistics.latest.map { $0 / 1_000 },
                    unit: "TB",
                    digits: 2
                ),
                firstLabel: "stat.recent",
                firstValue: format(
                    statistics.recentRatePerHour,
                    unit: "GB/h",
                    digits: 2
                ),
                secondLabel: "stat.average",
                secondValue: format(
                    statistics.averageRatePerHour,
                    unit: "GB/h",
                    digits: 2
                )
            )
        case .temperature:
            return MetricCardValues(
                value: format(statistics.latest, unit: "°C", digits: 0),
                firstLabel: "stat.historicalMaximum",
                firstValue: format(statistics.maximum, unit: "°C", digits: 0),
                secondLabel: "stat.historicalAverage",
                secondValue: format(statistics.average, unit: "°C", digits: 1)
            )
        case .availableSpare:
            let threshold = analyzer.statistics(
                for: .availableSpareThreshold,
                samples: model.samples
            ).latest
            let distance = statistics.latest.flatMap { latest in
                threshold.map { latest - $0 }
            }
            return MetricCardValues(
                value: format(statistics.latest, unit: "%", digits: 0),
                firstLabel: "stat.historicalMinimum",
                firstValue: format(statistics.minimum, unit: "%", digits: 0),
                secondLabel: "stat.distanceToThreshold",
                secondValue: format(distance, unit: "%", digits: 0)
            )
        case .percentageUsed:
            return MetricCardValues(
                value: format(statistics.latest, unit: "%", digits: 0),
                firstLabel: "stat.historicalMaximum",
                firstValue: format(statistics.maximum, unit: "%", digits: 0),
                secondLabel: "stat.latestChange",
                secondValue: format(
                    statistics.recentChange,
                    unit: "%",
                    digits: 1
                )
            )
        case .availableSpareThreshold:
            return MetricCardValues(
                value: format(statistics.latest, unit: "%", digits: 0),
                firstLabel: "stat.role",
                firstValue: localized("stat.alertLine", locale: model.locale),
                secondLabel: "stat.trigger",
                secondValue: localized(
                    "stat.belowThreshold",
                    locale: model.locale
                )
            )
        default:
            return MetricCardValues(
                value: format(statistics.latest, unit: "", digits: 0),
                firstLabel: "stat.latestChange",
                firstValue: format(
                    statistics.recentChange,
                    unit: "",
                    digits: 0
                ),
                secondLabel: "stat.total",
                secondValue: format(statistics.latest, unit: "", digits: 0)
            )
        }
    }

    private func format(
        _ value: Double?,
        unit: String,
        digits: Int
    ) -> String {
        guard let value else {
            return "—"
        }
        let number = value.formatted(
            .number.precision(.fractionLength(digits))
        )
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

private struct MetricCardValues {
    let value: String
    let firstLabel: String
    let firstValue: String
    let secondLabel: String
    let secondValue: String
}
