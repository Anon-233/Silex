import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    LocalizedLabel("page.overview")
                        .font(.title2.bold())
                    if let date = model.latestSample?.collectedAt {
                        HStack(spacing: 4) {
                            LocalizedLabel("status.lastCollected")
                            Text(date, style: .relative)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let sample = model.latestSample {
                    HStack(spacing: 8) {
                        Text(sample.smartPassed ? "PASSED" : "FAILED")
                            .font(.title2.bold())
                        LocalizedLabel(sample.smartPassed ? "status.normal" : "status.failed")
                            .foregroundStyle(sample.smartPassed ? .green : .red)
                    }
                }
            }

            if let sample = model.latestSample {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                    spacing: 10
                ) {
                    overviewCard("overview.model", sample.modelName, "internaldrive")
                    overviewCard("overview.temperature", format(sample.temperatureCelsius, "°C"), "thermometer.medium")
                    overviewCard("overview.read", formatBytes(sample.dataReadBytes), "arrow.down")
                    overviewCard("overview.written", formatBytes(sample.dataWrittenBytes), "arrow.up")
                    overviewCard("overview.spare", format(sample.availableSparePercent, "%"), "shippingbox")
                    overviewCard("overview.used", format(sample.percentageUsed, "%"), "gauge.with.dots.needle.33percent")
                    overviewCard("overview.powerOn", format(sample.powerOnHours.map(Double.init), "h"), "clock")
                    overviewCard("overview.errors", "\(sample.mediaErrors ?? 0)", "exclamationmark.triangle")
                }
            } else {
                ContentUnavailableView(
                    localized("status.noData", locale: model.locale),
                    systemImage: "internaldrive",
                    description: Text(localized("message.emptyChart", locale: model.locale))
                )
                .frame(maxHeight: .infinity)
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
    }

    private func overviewCard(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            LocalizedLabel(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func format(_ value: Double?, _ unit: String) -> String {
        value.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) \(unit)" } ?? "—"
    }

    private func formatBytes(_ value: Int64?) -> String {
        guard let value else {
            return "—"
        }
        let terabytes = Double(value) / 1_000_000_000_000
        let digits = terabytes < 10 ? 2 : 1
        return "\(terabytes.formatted(.number.precision(.fractionLength(digits)))) TB"
    }
}
