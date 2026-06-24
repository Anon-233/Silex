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

                settingRow("settings.smartctlPath") {
                    HStack {
                        TextField("", text: smartctlPath)
                            .textFieldStyle(.plain)
                            .frame(width: 260)
                        Button {
                            model.autoFillSmartctlPath()
                        } label: {
                            LocalizedLabel("action.autoFill")
                        }
                        .buttonStyle(.plain)
                        Button {
                            model.isInstallSheetPresented = true
                        } label: {
                            LocalizedLabel("action.install")
                        }
                        .buttonStyle(.plain)
                    }
                }

                settingRow("settings.service") {
                    HStack {
                        Text(serviceStatus)
                            .foregroundStyle(
                                model.serviceStatus == .enabled ? .green : .secondary
                            )
                        if model.serviceStatus != .enabled {
                            Button {
                                model.enablePrivilegedService()
                            } label: {
                                LocalizedLabel("action.enable")
                            }
                            .buttonStyle(.plain)
                        }
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

            if model.serviceStatus == .requiresApproval {
                LocalizedLabel("error.serviceApproval")
                    .font(.caption)
                    .foregroundStyle(.orange)
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

    private var smartctlPath: Binding<String> {
        Binding(
            get: { model.settings.smartctlPath ?? "" },
            set: { model.settings.smartctlPath = $0.isEmpty ? nil : $0 }
        )
    }

    private var serviceStatus: String {
        switch model.serviceStatus {
        case .enabled:
            localized("status.service.enabled", locale: model.locale)
        case .notRegistered:
            localized("status.service.notRegistered", locale: model.locale)
        case .requiresApproval:
            localized("status.service.requiresApproval", locale: model.locale)
        case .notFound:
            localized("status.service.notFound", locale: model.locale)
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

