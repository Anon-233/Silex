import SwiftUI
import SilexCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    @FocusState private var intervalIsFocused: Bool
    @State private var confirmsHistoryDeletion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LocalizedLabel("page.settings")
                .font(.title2.bold())
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                SettingRow(labelKey: "settings.language") {
                    Picker("", selection: $model.settings.language) {
                        LocalizedLabel("settings.followSystem")
                            .tag(LanguagePreference.system)
                        LocalizedLabel("settings.english")
                            .tag(LanguagePreference.english)
                        LocalizedLabel("settings.chinese")
                            .tag(LanguagePreference.simplifiedChinese)
                    }
                    .labelsHidden()
                    .onChange(of: model.settings.language) {
                        model.saveSettings()
                    }
                }

                SettingRow(labelKey: "settings.interval") {
                    HStack(spacing: 4) {
                        TextField(
                            "",
                            value: $model.settings.collectionIntervalHours,
                            format: .number
                        )
                        .focused($intervalIsFocused)
                        .frame(width: 56)
                        .onSubmit { model.saveSettings() }
                        LocalizedLabel("settings.intervalUnit")
                            .foregroundStyle(SilexTheme.muted)
                    }
                }

                SettingRow(labelKey: "settings.notifications") {
                    Toggle("", isOn: $model.settings.notificationsEnabled)
                        .labelsHidden()
                        .onChange(of: model.settings.notificationsEnabled) {
                            model.saveSettings()
                        }
                }

                SettingRow(labelKey: "settings.launchAtLogin") {
                    Toggle("", isOn: $model.settings.launchAtLogin)
                        .labelsHidden()
                        .onChange(of: model.settings.launchAtLogin) {
                            model.saveSettings()
                        }
                }

                SettingRow(labelKey: "settings.service") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(
                                model.serviceStatus == .available
                                    ? Color.green
                                    : Color.secondary
                            )
                            .frame(width: 7, height: 7)
                        Text(serviceStatus)
                            .font(.system(size: 13))
                        Button {
                            Task { await model.refreshServiceStatus() }
                        } label: {
                            LocalizedLabel("action.refresh")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                        Button {
                            model.openBackgroundItemsSettings()
                        } label: {
                            LocalizedLabel("action.backgroundItems")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                    }
                }

                SettingRow(labelKey: "settings.storage") {
                    HStack(spacing: 6) {
                        Text("~/Library/Application Support/Silex")
                            .font(.system(size: 12).monospaced())
                            .foregroundStyle(SilexTheme.muted)
                            .lineLimit(1)
                        Button {
                            model.showStorageInFinder()
                        } label: {
                            LocalizedLabel("action.showInFinder")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                    }
                }
            }
            .background(SilexTheme.soft)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SilexTheme.tileLine, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text("Silex \(appVersion) (\(appBuild))")
                    .font(.system(size: 12).monospaced())
                    .foregroundStyle(SilexTheme.muted)
                Text(buildDate)
                    .font(.system(size: 11).monospaced())
                    .foregroundStyle(SilexTheme.muted)
                HStack(spacing: 8) {
                    Button {
                        model.exportJSON()
                    } label: {
                        LocalizedLabel("settings.exportJSON")
                    }
                    .buttonStyle(SilexSecondaryButtonStyle())
                    Button {
                        model.exportCSV()
                    } label: {
                        LocalizedLabel("settings.exportCSV")
                    }
                    .buttonStyle(SilexSecondaryButtonStyle())
                    Button(role: .destructive) {
                        confirmsHistoryDeletion = true
                    } label: {
                        LocalizedLabel("settings.deleteHistory")
                    }
                    .buttonStyle(SilexSecondaryButtonStyle())
                }
            }
        }
        .padding(12)
        .onChange(of: intervalIsFocused) {
            if !intervalIsFocused { model.saveSettings() }
        }
        .confirmationDialog(
            localized("dialog.deleteHistory.title", locale: model.locale),
            isPresented: $confirmsHistoryDeletion,
            titleVisibility: .visible
        ) {
            Button(
                localized("settings.deleteHistory", locale: model.locale),
                role: .destructive
            ) { model.deleteHistory() }
            Button(
                localized("action.cancel", locale: model.locale),
                role: .cancel
            ) {}
        } message: {
            Text(localized("dialog.deleteHistory.message", locale: model.locale))
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    private var buildDate: String {
        // Embedded via SILEX_BUILD_DATE in Info.plist; falls back to module date
        Bundle.main.object(forInfoDictionaryKey: "SilexBuildDate") as? String
            ?? localized("settings.buildDateUnknown", locale: model.locale)
    }

    private var serviceStatus: String {
        switch model.serviceStatus {
        case .available:
            localized("status.service.available", locale: model.locale)
        case .unavailable:
            localized("status.service.unavailable", locale: model.locale)
        }
    }
}

private struct SettingRow<Content: View>: View {
    let labelKey: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            LocalizedLabel(labelKey)
                .font(.system(size: 12))
                .foregroundStyle(SilexTheme.muted)
                .frame(width: 102, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SilexTheme.tileLine)
                .frame(height: 1)
        }
    }
}
