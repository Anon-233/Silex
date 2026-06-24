import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AppMark()
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    LocalizedLabel("app.name")
                        .font(.headline)
                    if let sample = model.latestSample {
                        Text(sample.smartPassed
                             ? localizedStatus("status.normal")
                             : localizedStatus("status.failed"))
                            .font(.caption)
                            .foregroundStyle(sample.smartPassed ? .green : .red)
                    } else {
                        LocalizedLabel("status.noData")
                            .font(.caption)
                            .foregroundStyle(SilexTheme.muted)
                    }
                }
                Spacer()
            }

            if let sample = model.latestSample {
                HStack(spacing: 0) {
                    metricRow(
                        label: localized("metric.dataRead", locale: model.locale),
                        bytes: sample.dataReadBytes,
                        color: .blue
                    )
                    Spacer()
                    metricRow(
                        label: localized("metric.dataWritten", locale: model.locale),
                        bytes: sample.dataWrittenBytes,
                        color: .cyan
                    )
                }
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            Divider()

            HStack(spacing: 6) {
                Button {
                    openWindow(id: "main")
                } label: {
                    Label {
                        LocalizedLabel("action.open")
                    } icon: {
                        Image(systemName: "macwindow")
                    }
                }

                Button {
                    model.collectNow()
                } label: {
                    Label {
                        LocalizedLabel(model.isCollecting
                            ? "status.collecting"
                            : "action.collect")
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(model.isCollecting)

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label {
                        LocalizedLabel("action.quit")
                    } icon: {
                        Image(systemName: "power")
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func metricRow(label: String, bytes: Int64?, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(SilexTheme.muted)
            Text(formatTB(bytes))
                .font(.caption.monospacedDigit())
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
