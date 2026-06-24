import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            statusHeader
            metricGrid
        }
        .padding(12)
    }

    private var statusHeader: some View {
        HStack(spacing: 10) {
            if let sample = model.latestSample {
                Text(sample.smartPassed ? "PASSED" : "FAILED")
                    .font(.title3.bold())
                LocalizedLabel(sample.smartPassed ? "status.normal" : "status.failed")
                    .font(.caption.bold())
                    .foregroundStyle(sample.smartPassed ? .green : .red)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        (sample.smartPassed ? Color.green : Color.red)
                            .opacity(0.12)
                    )
                    .clipShape(Capsule())
            } else {
                Text("—")
                    .font(.title3.bold())
                LocalizedLabel("status.noData")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let firmware = model.latestSample?.firmwareVersion {
                HStack(spacing: 4) {
                    LocalizedLabel("overview.firmware")
                    Text(firmware)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let nextCollectionAt = model.nextCollectionAt {
                HStack(spacing: 4) {
                    LocalizedLabel("status.nextCollection")
                    Text(nextCollectionAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var metricGrid: some View {
        let cards = overviewCards
        return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                ForEach(Array(cards.prefix(5))) { card in
                    OverviewMetricCard(
                        card.titleKey,
                        value: card.value,
                        usesMonospacedDigits: card.usesMonospacedDigits
                    )
                }
            }
            GridRow {
                ForEach(Array(cards.suffix(5))) { card in
                    OverviewMetricCard(
                        card.titleKey,
                        value: card.value,
                        usesMonospacedDigits: card.usesMonospacedDigits
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var overviewCards: [OverviewCardValue] {
        let sample = model.latestSample
        return [
            OverviewCardValue(
                titleKey: "overview.temperature",
                value: format(sample?.temperatureCelsius, unit: "°C")
            ),
            OverviewCardValue(
                titleKey: "overview.spare",
                value: format(sample?.availableSparePercent, unit: "%")
            ),
            OverviewCardValue(
                titleKey: "overview.used",
                value: format(sample?.percentageUsed, unit: "%")
            ),
            OverviewCardValue(
                titleKey: "overview.read",
                value: formatBytes(sample?.dataReadBytes)
            ),
            OverviewCardValue(
                titleKey: "overview.written",
                value: formatBytes(sample?.dataWrittenBytes)
            ),
            OverviewCardValue(
                titleKey: "overview.powerCycles",
                value: formatCount(sample?.powerCycles)
            ),
            OverviewCardValue(
                titleKey: "overview.unsafeShutdowns",
                value: formatCount(sample?.unsafeShutdowns)
            ),
            OverviewCardValue(
                titleKey: "overview.mediaErrors",
                value: formatCount(sample?.mediaErrors)
            ),
            OverviewCardValue(
                titleKey: "overview.alerts",
                value: sample == nil ? "—" : "\(latestAlertCount)"
            ),
            OverviewCardValue(
                titleKey: "overview.device",
                value: sample == nil ? "—" : "disk0",
                usesMonospacedDigits: false
            )
        ]
    }

    private var latestAlertCount: Int {
        guard let collectedAt = model.latestSample?.collectedAt else {
            return 0
        }
        return model.rules.filter { rule in
            guard rule.isEnabled, let lastTriggeredAt = rule.lastTriggeredAt else {
                return false
            }
            return abs(lastTriggeredAt.timeIntervalSince(collectedAt)) <= 1
        }.count
    }

    private func format(_ value: Double?, unit: String) -> String {
        guard let value else {
            return "—"
        }
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }

    private func formatBytes(_ value: Int64?) -> String {
        guard let value else {
            return "—"
        }
        let terabytes = Double(value) / 1_000_000_000_000
        let digits = terabytes < 10 ? 2 : 1
        return "\(terabytes.formatted(.number.precision(.fractionLength(digits)))) TB"
    }

    private func formatCount(_ value: Int64?) -> String {
        value?.formatted() ?? "—"
    }
}

private struct OverviewCardValue: Identifiable {
    let titleKey: String
    let value: String
    var usesMonospacedDigits = true

    var id: String {
        titleKey
    }
}
