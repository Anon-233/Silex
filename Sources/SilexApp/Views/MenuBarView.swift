import AppKit
import SilexCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 38, weight: .light))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.44, blue: 0.72),
                                Color(red: 0.31, green: 0.55, blue: 1.00),
                                Color(red: 0.13, green: 0.84, blue: 0.78)
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    LocalizedLabel("app.name")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.green)
                        if let sample = model.latestSample {
                            Text(sample.smartPassed
                                 ? localizedStatus("status.normal")
                                 : localizedStatus("status.failed"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(sample.smartPassed ? .green : .red)
                        } else {
                            LocalizedLabel("status.noData")
                                .font(.system(size: 14))
                                .foregroundStyle(SilexTheme.muted)
                        }
                    }
                }

                Spacer()

                if let sample = model.latestSample {
                    let analyzer = HistoryAnalyzer()
                    VStack(alignment: .trailing, spacing: 6) {
                        dataLine(
                            label: localized("metric.dataRead", locale: model.locale),
                            bytes: sample.dataReadBytes,
                            rate: analyzer.statistics(for: .dataRead, samples: model.samples).recentRatePerHour,
                            color: .blue
                        )
                        dataLine(
                            label: localized("metric.dataWritten", locale: model.locale),
                            bytes: sample.dataWrittenBytes,
                            rate: analyzer.statistics(for: .dataWritten, samples: model.samples).recentRatePerHour,
                            color: .cyan
                        )
                    }
                }
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Divider()

            HStack(spacing: 6) {
                menuButton(
                    label: localized("action.open.short", locale: model.locale),
                    icon: "macwindow"
                ) {
                    if let window = NSApp.windows.first(where: {
                        $0.title == "Silex"
                    }) {
                        NSApp.activate()
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        openWindow(id: "main")
                    }
                }

                menuButton(
                    label: model.isCollecting
                        ? localized("status.collecting", locale: model.locale)
                        : localized("action.collect.short", locale: model.locale),
                    icon: "square.and.arrow.down"
                ) {
                    model.collectNow()
                }
                .disabled(model.isCollecting)

                menuButton(
                    label: localized("action.quit.short", locale: model.locale),
                    icon: "power"
                ) {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 360)
    }

    private func menuButton(
        label: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
        }
        .buttonStyle(.borderless)
        .background(SilexTheme.soft)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func dataLine(label: String, bytes: Int64?, rate: Double?, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(SilexTheme.muted)
            VStack(alignment: .trailing, spacing: 0) {
                Text(formatTB(bytes))
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                if let rate {
                    Text("\(rate >= 0 ? "+" : "")\(rate.formatted(.number.precision(.fractionLength(1)))) GB/h")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(SilexTheme.muted)
                }
            }
        }
    }

    private func formatTB(_ bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        let tb = Double(bytes) / 1_000_000_000_000
        return "\(tb.formatted(.number.precision(.fractionLength(2)))) TB"
    }

    private func localizedStatus(_ key: String) -> String {
        localized(key, locale: model.locale)
    }
}
