import SwiftUI
import SilexCore

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
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(
                        sample.smartPassed
                            ? SilexTheme.green
                            : SilexTheme.red
                    )
                LocalizedLabel(sample.smartPassed ? "status.normal" : "status.failed")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(
                        sample.smartPassed
                            ? SilexTheme.healthyPillText
                            : SilexTheme.failedPillText
                    )
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        sample.smartPassed
                            ? SilexTheme.healthyPill
                            : SilexTheme.failedPill
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

            if let sample = model.latestSample {
                Text(statusDetail(sample: sample))
                    .font(.system(size: 16))
                    .foregroundStyle(SilexTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(SilexTheme.soft)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SilexTheme.tileLine, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var metricGrid: some View {
        let cards = overviewCards
        return Grid(horizontalSpacing: 9, verticalSpacing: 9) {
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

    private func statusDetail(sample: DriveSample) -> String {
        let firmware = sample.firmwareVersion ?? "—"
        guard let nextCollectionAt = model.nextCollectionAt else {
            return "Firmware \(firmware)"
        }
        let remaining = max(nextCollectionAt.timeIntervalSinceNow, 0)
        let hours = Int(remaining / 3_600)
        let minutes = Int(remaining.truncatingRemainder(dividingBy: 3_600) / 60)
        return "Firmware \(firmware) · "
            + localized("status.nextCollection", locale: model.locale)
            + " \(hours)h \(minutes)m"
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
