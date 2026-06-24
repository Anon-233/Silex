import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                HStack(spacing: 8) {
                    LocalizedLabel("app.name")
                        .font(.system(size: 22, weight: .bold))
                    if let sample = model.latestSample {
                        Text(sample.smartPassed
                             ? localizedStatus("status.normal")
                             : localizedStatus("status.failed"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(sample.smartPassed
                                ? SilexTheme.healthyPillText
                                : SilexTheme.failedPillText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(
                                sample.smartPassed
                                    ? SilexTheme.healthyPill
                                    : SilexTheme.failedPill
                            )
                            .clipShape(Capsule())
                    } else {
                        LocalizedLabel("status.noData")
                            .font(.system(size: 14))
                            .foregroundStyle(SilexTheme.muted)
                    }
                }

                Spacer()

                if let sample = model.latestSample {
                    VStack(alignment: .trailing, spacing: 5) {
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
                    icon: "arrow.clockwise"
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
        .frame(width: 340)
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

    private func dataLine(label: String, bytes: Int64?, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(SilexTheme.muted)
            Text(formatTB(bytes))
                .font(.system(size: 14, weight: .medium).monospacedDigit())
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
