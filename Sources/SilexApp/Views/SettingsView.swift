import SwiftUI
import SilexCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    @FocusState private var intervalIsFocused: Bool
    @State private var confirmsHistoryDeletion = false

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LocalizedLabel("page.settings")
                .font(.title2.bold())

            LazyVGrid(columns: columns, spacing: 8) {
                SettingsCard(titleKey: "settings.language") {
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

                SettingsCard(titleKey: "settings.interval") {
                    HStack(spacing: 6) {
                        TextField(
                            "",
                            value: $model.settings.collectionIntervalHours,
                            format: .number
                        )
                        .focused($intervalIsFocused)
                        .onSubmit {
                            model.saveSettings()
                        }
                        LocalizedLabel("settings.intervalUnit")
                            .foregroundStyle(SilexTheme.muted)
                    }
                    Text(
                        localized(
                            "settings.minimumInterval",
                            locale: model.locale
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(SilexTheme.muted)
                }

                SettingsCard(titleKey: "settings.notifications") {
                    Toggle(
                        localized("settings.notifications", locale: model.locale),
                        isOn: $model.settings.notificationsEnabled
                    )
                    .labelsHidden()
                    .onChange(of: model.settings.notificationsEnabled) {
                        model.saveSettings()
                    }
                }

                SettingsCard(titleKey: "settings.launchAtLogin") {
                    Toggle(
                        localized("settings.launchAtLogin", locale: model.locale),
                        isOn: $model.settings.launchAtLogin
                    )
                    .labelsHidden()
                    .onChange(of: model.settings.launchAtLogin) {
                        model.saveSettings()
                    }
                }

                SettingsCard(titleKey: "settings.service") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(
                                model.serviceStatus == .available
                                    ? Color.green
                                    : Color.secondary
                            )
                            .frame(width: 8, height: 8)
                        Text(serviceStatus)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            Task {
                                await model.refreshServiceStatus()
                            }
                        } label: {
                            LocalizedLabel("action.refresh")
                        }
                    }
                    Button {
                        model.openBackgroundItemsSettings()
                    } label: {
                        LocalizedLabel("action.backgroundItems")
                    }
                }

                SettingsCard(titleKey: "settings.storage") {
                    Text("~/Library/Application Support/Silex")
                        .font(.caption.monospaced())
                        .foregroundStyle(SilexTheme.muted)
                        .lineLimit(1)
                    Button {
                        model.showStorageInFinder()
                    } label: {
                        LocalizedLabel("action.showInFinder")
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
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
                    confirmsHistoryDeletion = true
                } label: {
                    LocalizedLabel("settings.deleteHistory")
                }
            }
        }
        .padding(12)
        .onChange(of: intervalIsFocused) {
            if !intervalIsFocused {
                model.saveSettings()
            }
        }
        .confirmationDialog(
            localized("dialog.deleteHistory.title", locale: model.locale),
            isPresented: $confirmsHistoryDeletion,
            titleVisibility: .visible
        ) {
            Button(
                localized("settings.deleteHistory", locale: model.locale),
                role: .destructive
            ) {
                model.deleteHistory()
            }
            Button(
                localized("action.cancel", locale: model.locale),
                role: .cancel
            ) {}
        } message: {
            Text(localized("dialog.deleteHistory.message", locale: model.locale))
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
}
