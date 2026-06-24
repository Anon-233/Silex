import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    LocalizedLabel("app.name")
                        .font(.system(size: 17, weight: .bold))
                    if let sample = model.latestSample {
                        Text(sample.smartPassed
                             ? localizedStatus("status.normal")
                             : localizedStatus("status.failed"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(sample.smartPassed ? .green : .red)
                    } else {
                        LocalizedLabel("status.noData")
                            .font(.system(size: 13))
                            .foregroundStyle(SilexTheme.muted)
                    }
                }

                Spacer()

                if let sample = model.latestSample {
                    VStack(alignment: .trailing, spacing: 4) {
                        dataLine(
                            label: localized("metric.dataRead", locale: model.locale),
                            bytes: sample.dataReadBytes,
                            color: .blue
                        )
                        dataLine(
                            label: localized("metric.dataWritten", locale: model.locale),
                            bytes: sample.dataWrittenBytes,
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
                Button {
                    if let window = NSApp.windows.first(where: {
                        $0.title == "Silex"
                    }) {
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        openWindow(id: "main")
                    }
                } label: {
                    Label {
                        Text(localized("action.open.short", locale: model.locale))
                    } icon: {
                        Image(systemName: "macwindow")
                    }
                }

                Button {
                    model.collectNow()
                } label: {
                    Label {
                        Text(localized("action.collect.short", locale: model.locale))
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(model.isCollecting)

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label {
                        Text(localized("action.quit.short", locale: model.locale))
                    } icon: {
                        Image(systemName: "power")
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private func dataLine(label: String, bytes: Int64?, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(SilexTheme.muted)
            Text(formatTB(bytes))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
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
