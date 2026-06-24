import SwiftUI
import SilexCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LocalizedLabel("page.settings")
                .font(.title2.bold())

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                settingRow("settings.language") {
                    Picker("", selection: $model.settings.language) {
                        LocalizedLabel("settings.followSystem").tag(LanguagePreference.system)
                        LocalizedLabel("settings.english").tag(LanguagePreference.english)
                        LocalizedLabel("settings.chinese").tag(LanguagePreference.simplifiedChinese)
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }

                settingRow("settings.interval") {
                    HStack(spacing: 5) {
                        TextField(
                            "",
                            value: $model.settings.collectionIntervalHours,
                            format: .number
                        )
                        .frame(width: 180)
                        LocalizedLabel("settings.intervalUnit")
                            .foregroundStyle(.secondary)
                    }
                }

                settingRow("settings.notifications") {
                    Toggle("", isOn: $model.settings.notificationsEnabled)
                        .labelsHidden()
                }

                settingRow("settings.launchAtLogin") {
                    Toggle("", isOn: $model.settings.launchAtLogin)
                        .labelsHidden()
                }

                settingRow("settings.service") {
                    HStack {
                        Text(serviceStatus)
                            .foregroundStyle(
                                model.serviceStatus == .available
                                    ? .green
                                    : .secondary
                            )
                        Button {
                            Task {
                                await model.refreshServiceStatus()
                            }
                        } label: {
                            LocalizedLabel("action.refresh")
                        }
                        .buttonStyle(.plain)
                        Button {
                            model.openBackgroundItemsSettings()
                        } label: {
                            LocalizedLabel("action.backgroundItems")
                        }
                        .buttonStyle(.plain)
                    }
                }

                settingRow("settings.storage") {
                    HStack {
                        Text("~/Library/Application Support/Silex")
                            .foregroundStyle(.secondary)
                        Button {
                            model.showStorageInFinder()
                        } label: {
                            LocalizedLabel("action.open")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .textFieldStyle(.plain)

            Divider()

            HStack {
                Button {
                    model.exportJSON()
                } label: {
                    LocalizedLabel("settings.exportJSON")
                }
                Button {
                    model.exportCSV()
                } label: {
                    LocalizedLabel("settings.exportCSV")
                }
                Spacer()
                Button(role: .destructive) {
                    model.deleteHistory()
                } label: {
                    LocalizedLabel("settings.deleteHistory")
                }
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .padding(16)
        .onChange(of: model.settings) {
            model.saveSettings()
        }
    }

    private var serviceStatus: String {
        switch model.serviceStatus {
        case .available:
            localized("status.service.available", locale: model.locale)
        case .unavailable:
            localized("status.service.unavailable", locale: model.locale)
        }
    }

    private func settingRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GridRow {
            LocalizedLabel(label)
                .foregroundStyle(.secondary)
                .frame(width: 170, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
