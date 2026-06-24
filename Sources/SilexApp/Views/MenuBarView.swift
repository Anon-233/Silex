import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AppMark()
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    LocalizedLabel("app.name")
                        .font(.headline)
                    if let sample = model.latestSample {
                        Text(sample.smartPassed ? localizedStatus("status.normal") : localizedStatus("status.failed"))
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
                HStack {
                    value(sample.temperatureCelsius, unit: "°C")
                    Spacer()
                    value(sample.percentageUsed, unit: "%")
                    Spacer()
                    Text(sample.collectedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(SilexTheme.muted)
                }
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            Divider()

            Button {
                openWindow(id: "main")
                let box = ObserverBox()
                box.observer = NotificationCenter.default.addObserver(
                    forName: NSApplication.didResignActiveNotification,
                    object: nil,
                    queue: .main
                ) { [weak box] _ in
                    guard let box else { return }
                    if let o = box.observer {
                        NotificationCenter.default.removeObserver(o)
                    }
                    box.observer = nil
                    NSApp.activate()
                    NSApp.windows.first { !$0.isKind(of: NSPanel.self) }?
                        .makeKeyAndOrderFront(nil)
                }
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
                    LocalizedLabel(model.isCollecting ? "status.collecting" : "action.collect")
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
        .padding(14)
        .frame(width: 290)
    }

    private func value(_ value: Double?, unit: String) -> some View {
        Text(value.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) \(unit)" } ?? "—")
            .font(.caption.monospacedDigit())
    }

    private func localizedStatus(_ key: String) -> String {
        localized(key, locale: model.locale)
    }
}

private final class ObserverBox {
    var observer: NSObjectProtocol?
}

