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
    @State private var hoveredPoint: ChartPoint?
    @State private var hoveredPointPosition: CGPoint?
    private let analyzer = HistoryAnalyzer()
    private let seriesBuilder = ChartSeriesBuilder()
    private let domainBuilder = ChartAxisDomainBuilder()
    private let hoverResolver = ChartHoverResolver()

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
                    .foregroundStyle(SilexTheme.muted)
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
                        hoveredPoint = nil
                        hoveredPointPosition = nil
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
            .background(SilexTheme.soft)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SilexTheme.tileLine, lineWidth: 1)
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
        .background(SilexTheme.soft)
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

                    if hoveredPoint == point {
                        PointMark(
                            x: .value("Time", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(metricSeries.metric.chartColor)
                        .symbolSize(64)
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
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                updateHoveredPoint(
                                    location: location,
                                    proxy: proxy,
                                    geometry: geometry
                                )
                            case .ended:
                                hoveredPoint = nil
                                hoveredPointPosition = nil
                            }
                        }

                    if let hoveredPoint, let hoveredPointPosition {
                        pointTooltip(for: hoveredPoint)
                            .position(
                                tooltipPosition(
                                    near: hoveredPointPosition,
                                    in: geometry.size
                                )
                            )
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(minHeight: 230)

        if let chartDomain {
            chart.chartYScale(domain: chartDomain.lower...chartDomain.upper)
        } else {
            chart
        }
    }

    private func updateHoveredPoint(
        location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else {
            hoveredPoint = nil
            hoveredPointPosition = nil
            return
        }
        let frame = geometry[plotFrame]
        guard frame.contains(location) else {
            hoveredPoint = nil
            hoveredPointPosition = nil
            return
        }
        let local = CGPoint(
            x: location.x - frame.minX,
            y: location.y - frame.minY
        )
        var candidates: [ChartHoverCandidate] = []

        for metricSeries in preparedSeries {
            for point in metricSeries.points {
                guard
                    let x = proxy.position(forX: point.date),
                    let y = proxy.position(forY: point.value)
                else {
                    continue
                }
                candidates.append(
                    ChartHoverCandidate(
                        point: point,
                        x: Double(x),
                        y: Double(y)
                    )
                )
            }
        }

        guard let point = hoverResolver.nearestPoint(
            to: ChartHoverLocation(
                x: Double(local.x),
                y: Double(local.y)
            ),
            candidates: candidates,
            maximumDistance: 18
        ) else {
            hoveredPoint = nil
            hoveredPointPosition = nil
            return
        }

        hoveredPoint = point
        if
            let x = proxy.position(forX: point.date),
            let y = proxy.position(forY: point.value)
        {
            hoveredPointPosition = CGPoint(
                x: frame.minX + x,
                y: frame.minY + y
            )
        } else {
            hoveredPointPosition = nil
        }
    }

    private func pointTooltip(for point: ChartPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(point.metric.chartColor)
                    .frame(width: 7, height: 7)
                Text(localized(point.metric.titleKey, locale: model.locale))
                    .font(.caption.bold())
            }
            Text(tooltipValue(for: point))
                .font(.caption)
                .foregroundStyle(SilexTheme.text)
            Text(
                point.date.formatted(
                    .dateTime
                        .year()
                        .month()
                        .day()
                        .hour()
                        .minute()
                        .second()
                        .locale(model.locale)
                )
            )
            .font(.caption2)
            .foregroundStyle(SilexTheme.muted)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.regularMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(SilexTheme.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }

    private func tooltipPosition(near point: CGPoint, in size: CGSize) -> CGPoint {
        let horizontalOffset: CGFloat = point.x > size.width - 180 ? -92 : 92
        let preferred = CGPoint(x: point.x + horizontalOffset, y: point.y - 42)
        return CGPoint(
            x: min(max(preferred.x, 90), max(90, size.width - 90)),
            y: min(max(preferred.y, 34), max(34, size.height - 34))
        )
    }

    private func tooltipValue(for point: ChartPoint) -> String {
        switch point.metric {
        case .dataRead, .dataWritten:
            format(point.value, unit: "TB", digits: 2)
        case .temperature:
            format(point.value, unit: "°C", digits: 0)
        case .availableSpare, .availableSpareThreshold, .percentageUsed:
            format(point.value, unit: "%", digits: 0)
        default:
            format(point.value, unit: "", digits: 0)
        }
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
                    digits: 2,
                    showSign: true
                ),
                secondLabel: "stat.average",
                secondValue: format(
                    statistics.averageRatePerHour,
                    unit: "GB/h",
                    digits: 2,
                    showSign: true
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
                    digits: 1,
                    showSign: true
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
                    digits: 0,
                    showSign: true
                ),
                secondLabel: "stat.total",
                secondValue: format(statistics.latest, unit: "", digits: 0)
            )
        }
    }

    private func format(
        _ value: Double?,
        unit: String,
        digits: Int,
        showSign: Bool = false
    ) -> String {
        guard let value else {
            return "—"
        }
        var number = value.formatted(
            .number.precision(.fractionLength(digits))
        )
        if showSign, value > 0 {
            number = "+" + number
        }
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
